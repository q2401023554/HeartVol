package cn.heartgun.guanggu.service;

import cn.heartgun.guanggu.common.ApiException;
import cn.heartgun.guanggu.repo.HelpRepo;
import cn.heartgun.guanggu.repo.UserRepo;
import cn.heartgun.guanggu.repo.UserRow;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 互助闭环（B6）：列表 / 详情 / 发布 / 接单 / 完成确认 / 互评。
 *
 * 积分与信用分规则（与种子流水口径一致）：
 *   发布扣悬赏 → 接单人完成后悬赏入账 → 互评后双方各 +15 积分；
 *   被评人信用分：5/4 星 +2，2/1 星 -3，3 星不变。
 */
@Service
public class HelpService {
    private static final int REVIEW_BONUS = 15;

    private final HelpRepo helpRepo;
    private final UserRepo userRepo;

    public HelpService(HelpRepo helpRepo, UserRepo userRepo) {
        this.helpRepo = helpRepo;
        this.userRepo = userRepo;
    }

    /** 我发布的求助（发布者管理入口） */
    public List<Map<String, Object>> myPublished(long uid) {
        UserRow me = userRepo.findById(uid).orElseThrow();
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : helpRepo.listByPublisher(uid)) {
            out.add(toItem(row, me));
        }
        return out;
    }

    public Map<String, Object> list(long uid, String category, String keyword, String sort, int page, int size) {
        UserRow me = userRepo.findById(uid).orElseThrow();
        List<Map<String, Object>> filtered = new ArrayList<>();
        for (Map<String, Object> row : helpRepo.listAll(uid)) {
            if (category != null && !category.isBlank() && !category.equals(row.get("category"))) {
                continue;
            }
            if (keyword != null && !keyword.isBlank()
                    && !String.valueOf(row.get("title")).contains(keyword.trim())) {
                continue;
            }
            filtered.add(toItem(row, me));
        }
        if ("distance".equalsIgnoreCase(sort)) {
            filtered.sort(Comparator.comparingDouble(m -> (double) m.get("distance")));
        } else {
            filtered.sort(Comparator.comparing(m -> String.valueOf(m.get("createTime")), Comparator.reverseOrder()));
        }
        int p = Math.max(page, 1);
        int s = Math.min(Math.max(size, 1), 50);
        int from = (p - 1) * s;
        List<Map<String, Object>> pageList = from >= filtered.size()
                ? List.of() : filtered.subList(from, Math.min(from + s, filtered.size()));
        Map<String, Object> out = new HashMap<>();
        out.put("list", pageList);
        out.put("total", filtered.size());
        out.put("page", p);
        return out;
    }

    public Map<String, Object> detail(long id, long uid) {
        Map<String, Object> row = helpRepo.findById(id, uid)
                .orElseThrow(() -> new ApiException(404, "求助不存在或已删除"));
        UserRow me = userRepo.findById(uid).orElseThrow();
        Map<String, Object> detail = toItem(row, me);
        helpRepo.findOrder(id).ifPresent(order -> {
            Map<String, Object> orderMap = new HashMap<>();
            orderMap.put("id", num(order.get("id")).longValue());
            orderMap.put("requestId", id);
            orderMap.put("helperId", num(order.get("helper_id")).longValue());
            orderMap.put("status", str(order.get("status")));
            orderMap.put("acceptTime", cn.heartgun.guanggu.common.Times.normTime(order.get("accept_time")));
            orderMap.put("finishTime", cn.heartgun.guanggu.common.Times.normTime(order.get("finish_time")));
            detail.put("order", orderMap);
        });
        // reviews 转 camelCase（与 App HelpReview 模型对齐）
        List<Map<String, Object>> reviewOut = new ArrayList<>();
        for (Map<String, Object> r : helpRepo.reviewsOf(id)) {
            Map<String, Object> m = new HashMap<>();
            m.put("id", num(r.get("id")).longValue());
            m.put("orderId", num(r.get("order_id")).longValue());
            m.put("fromUserId", num(r.get("from_user_id")).longValue());
            m.put("toUserId", num(r.get("to_user_id")).longValue());
            m.put("score", num(r.get("score")).intValue());
            m.put("content", str(r.get("content")));
            m.put("createTime", cn.heartgun.guanggu.common.Times.normTime(r.get("create_time")));
            m.put("fromUserName", str(r.get("from_user_name")));
            reviewOut.add(m);
        }
        detail.put("reviews", reviewOut);
        boolean reviewed = false;
        for (Map<String, Object> r : reviewOut) {
            if (num(r.get("fromUserId")).longValue() == uid) {
                reviewed = true;
                break;
            }
        }
        detail.put("reviewedByMe", reviewed);
        return detail;
    }

    /** 发布：悬赏从发布者积分里扣（余额不足 400） */
    @Transactional
    public Map<String, Object> publish(long uid, Map<String, Object> body) {
        String title = str(body.get("title"));
        String category = str(body.get("category"));
        int reward = (int) toDouble(body.get("rewardPoint"));
        if (isBlank(title) || isBlank(category) || reward <= 0) {
            throw new ApiException(400, "标题、分类与悬赏积分不能为空");
        }
        if (userRepo.findById(uid).orElseThrow().point() < reward) {
            throw new ApiException(400, "公益积分余额不足");
        }
        long id = helpRepo.insert(uid, title, category, strOr(body.get("description")),
                reward, strOr(body.get("expectTime")), strOr(body.get("address")),
                toDouble(body.get("lat")), toDouble(body.get("lng")));
        int balance = helpRepo.adjustPoint(uid, -reward);
        helpRepo.insertPointLog(uid, -reward, balance, "发布求助悬赏「" + title + "」", id);
        Map<String, Object> out = new HashMap<>();
        out.put("id", id);
        out.put("point", balance);
        return out;
    }

    /** 接单：pending → ongoing，双方发消息 */
    @Transactional
    public void accept(long id, long uid) {
        Map<String, Object> row = helpRepo.findById(id, uid)
                .orElseThrow(() -> new ApiException(404, "求助不存在或已删除"));
        long publisherId = num(row.get("publisher_id")).longValue();
        if (publisherId == uid) {
            throw new ApiException(400, "不能接自己发布的求助");
        }
        if (!"pending".equals(row.get("status"))) {
            throw new ApiException(400, "该求助当前不可接单");
        }
        try {
            helpRepo.insertOrder(id, uid);
        } catch (DuplicateKeyException e) {
            throw new ApiException(400, "该求助已被接单");
        }
        helpRepo.updateRequestStatus(id, "ongoing");
        String title = str(row.get("title"));
        helpRepo.insertMessage(uid, "help", id, "接单成功",
                "你已接下「" + title + "」，请在约定时间前联系发布者。", 0);
        helpRepo.insertMessage(publisherId, "help", id, "你的求助有人接单了",
                "「" + title + "」已被接单，可在详情页查看接单人并保持联系。", 0);
    }

    /** 完成（发布者确认）：order → finished，悬赏入账给接单人 */
    @Transactional
    public Map<String, Object> finish(long id, long uid) {
        Map<String, Object> row = helpRepo.findById(id, uid)
                .orElseThrow(() -> new ApiException(404, "求助不存在或已删除"));
        long publisherId = num(row.get("publisher_id")).longValue();
        if (publisherId != uid) {
            throw new ApiException(400, "只有发布者可以确认完成");
        }
        if (!"ongoing".equals(row.get("status"))) {
            throw new ApiException(400, "该求助当前不可确认完成");
        }
        Map<String, Object> order = helpRepo.findOrder(id)
                .orElseThrow(() -> new ApiException(400, "该求助还没有接单人"));
        long helperId = num(order.get("helper_id")).longValue();
        int reward = num(row.get("reward_point")).intValue();
        String title = str(row.get("title"));

        helpRepo.updateOrderFinished(num(order.get("id")).longValue());
        helpRepo.updateRequestStatus(id, "finished");
        int balance = helpRepo.adjustPoint(helperId, reward);
        helpRepo.insertPointLog(helperId, reward, balance, "完成互助任务「" + title + "」", id);
        helpRepo.insertMessage(helperId, "help", id, "订单已完成",
                "「" + title + "」已确认完成，" + reward + " 积分已入账，别忘了互相评价。", 0);
        helpRepo.insertMessage(publisherId, "help", id, "订单已完成",
                "「" + title + "」已确认完成，别忘了给对方评价。", 0);
        Map<String, Object> out = new HashMap<>();
        out.put("helperId", helperId);
        out.put("rewardPoint", reward);
        out.put("helperPoint", balance);
        return out;
    }

    /** 互评：订单双方各评一次；被评人信用分随星级变动，双方各 +15 积分 */
    @Transactional
    public Map<String, Object> review(long orderId, long uid, int score, String content) {
        if (score < 1 || score > 5) {
            throw new ApiException(400, "评分需为 1-5 星");
        }
        Map<String, Object> order = helpRepo.findOrderById(orderId)
                .orElseThrow(() -> new ApiException(404, "订单不存在"));
        long helperId = num(order.get("helper_id")).longValue();
        long requestId = num(order.get("request_id")).longValue();
        Map<String, Object> request = helpRepo.findById(requestId, uid)
                .orElseThrow(() -> new ApiException(404, "求助不存在或已删除"));
        long publisherId = num(request.get("publisher_id")).longValue();
        if (uid != helperId && uid != publisherId) {
            throw new ApiException(400, "只有订单双方可以评价");
        }
        if (!"finished".equals(order.get("status"))) {
            throw new ApiException(400, "订单完成后才能评价");
        }
        long toUser = uid == helperId ? publisherId : helperId;
        try {
            helpRepo.insertReview(orderId, uid, toUser, score, strOr(content));
        } catch (DuplicateKeyException e) {
            throw new ApiException(400, "你已评价过本次订单");
        }
        int creditDelta = score >= 4 ? 2 : (score <= 2 ? -3 : 0);
        if (creditDelta != 0) {
            helpRepo.adjustCredit(toUser, creditDelta);
        }
        // 互评奖励：双方都评完才各发一次（之前每次评价都发导致一方拿 30）
        if (helpRepo.reviewCount(orderId) == 2) {
            int bonusHelper = helpRepo.adjustPoint(helperId, REVIEW_BONUS);
            helpRepo.insertPointLog(helperId, REVIEW_BONUS, bonusHelper, "互助双方互评奖励", requestId);
            int bonusPublisher = helpRepo.adjustPoint(publisherId, REVIEW_BONUS);
            helpRepo.insertPointLog(publisherId, REVIEW_BONUS, bonusPublisher, "互助双方互评奖励", requestId);
        }
        helpRepo.insertMessage(toUser, "interact", requestId, "收到新评价",
                str(userRepo.findById(uid).orElseThrow().name()) + " 给了你 " + score
                        + " 星评价" + (creditDelta != 0 ? "，信用分 " + (creditDelta > 0 ? "+" : "") + creditDelta : "") + "。", 0);
        Map<String, Object> out = new HashMap<>();
        out.put("toUserId", toUser);
        out.put("creditDelta", creditDelta);
        return out;
    }

    // ==================== 内部工具 ====================

    private Map<String, Object> toItem(Map<String, Object> row, UserRow me) {
        Map<String, Object> item = new HashMap<>();
        item.put("id", num(row.get("id")).longValue());
        item.put("publisherId", num(row.get("publisher_id")).longValue());
        item.put("title", str(row.get("title")));
        item.put("category", str(row.get("category")));
        item.put("description", str(row.get("description")));
        item.put("rewardPoint", num(row.get("reward_point")).intValue());
        item.put("expectTime", str(row.get("expect_time")));
        item.put("address", str(row.get("address")));
        item.put("lat", num(row.get("lat")).doubleValue());
        item.put("lng", num(row.get("lng")).doubleValue());
        item.put("status", str(row.get("status")));
        item.put("createTime", cn.heartgun.guanggu.common.Times.normTime(row.get("create_time")));
        item.put("isPublisher", num(row.get("publisher_id")).longValue() == me.id());
        item.put("isHelper", num(row.get("is_helper")).intValue() > 0);
        item.put("reviewedByMe", false);
        double dist = ActivityService.distance(me.lat(), me.lng(),
                num(row.get("lat")).doubleValue(), num(row.get("lng")).doubleValue());
        item.put("distance", dist);
        // 嵌套 publisher（与 App HelpRequest.publisher 模型对齐；列表也带出，卡片可显示发布者）
        Map<String, Object> publisher = new HashMap<>();
        publisher.put("id", num(row.get("publisher_id")).longValue());
        publisher.put("name", str(row.get("publisher_name")));
        publisher.put("college", str(row.get("publisher_college")));
        publisher.put("creditScore", num(row.get("publisher_credit")).intValue());
        item.put("publisher", publisher);
        return item;
    }

    private static Number num(Object o) {
        return (Number) o;
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }

    private static String strOr(Object o) {
        return o == null ? "" : o.toString();
    }

    private static double toDouble(Object o) {
        return o instanceof Number ? ((Number) o).doubleValue() : 0.0;
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
