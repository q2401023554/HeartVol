package cn.heartgun.guanggu.service;

import cn.heartgun.guanggu.common.ApiException;
import cn.heartgun.guanggu.common.Times;
import cn.heartgun.guanggu.repo.MessageRepo;
import cn.heartgun.guanggu.repo.MyRecordsRepo;
import cn.heartgun.guanggu.repo.UserRepo;
import cn.heartgun.guanggu.repo.UserRow;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** 「我的」域业务（B5 + B7）：报名列表 / 时长明细 / 消息中心 */
@Service
public class UserBizService {
    private final MyRecordsRepo myRecordsRepo;
    private final MessageRepo messageRepo;
    private final UserRepo userRepo;
    private final ActivityService activityService;

    public UserBizService(MyRecordsRepo myRecordsRepo, MessageRepo messageRepo,
                          UserRepo userRepo, ActivityService activityService) {
        this.myRecordsRepo = myRecordsRepo;
        this.messageRepo = messageRepo;
        this.userRepo = userRepo;
        this.activityService = activityService;
    }

    /** 我的报名：App Signup 模型 = {id, activityId, userId, status, signupTime, activity{...}} */
    public List<Map<String, Object>> mySignups(long uid) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : myRecordsRepo.mySignups(uid)) {
            Map<String, Object> activity = new HashMap<>();
            activity.put("id", num(row.get("a_id")).longValue());
            activity.put("title", str(row.get("title")));
            activity.put("category", str(row.get("category")));
            activity.put("cover", str(row.get("cover")));
            activity.put("address", str(row.get("address")));
            activity.put("startTime", Times.normTime(row.get("start_time")));
            activity.put("endTime", Times.normTime(row.get("end_time")));
            activity.put("serviceHours", num(row.get("service_hours")).doubleValue());
            activity.put("status", str(row.get("a_status")));

            Map<String, Object> item = new HashMap<>();
            item.put("id", num(row.get("signup_id")).longValue());
            item.put("activityId", num(row.get("a_id")).longValue());
            item.put("userId", uid);
            item.put("status", str(row.get("signup_status")));
            item.put("signupTime", Times.normTime(row.get("signup_time")));
            item.put("activity", activity);
            out.add(item);
        }
        return out;
    }

    /** 时长明细：App HourRecord 模型 = {id, userId, activityId, hours, gainTime, activityTitle, activityCategory} */
    public List<Map<String, Object>> myHours(long uid) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : myRecordsRepo.myHours(uid)) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", num(row.get("id")).longValue());
            item.put("userId", num(row.get("user_id")).longValue());
            item.put("activityId", num(row.get("activity_id")).longValue());
            item.put("hours", num(row.get("hours")).doubleValue());
            item.put("gainTime", Times.normTime(row.get("gain_time")));
            item.put("activityTitle", str(row.get("title")));
            item.put("activityCategory", str(row.get("category")));
            out.add(item);
        }
        return out;
    }

    /** 电子证书（云同步）：真实资料 + 累计时长 + 完成场次；编号按 uid 稳定生成，同一人永远同一个号 */
    public Map<String, Object> certificate(long uid) {
        UserRow me = userRepo.findById(uid)
                .orElseThrow(() -> new ApiException(404, "用户不存在"));
        Map<String, Object> out = new HashMap<>();
        out.put("userName", me.name() == null ? "" : me.name());
        out.put("studentNo", me.studentNo() == null ? "" : me.studentNo());
        out.put("college", me.college() == null ? "" : me.college());
        out.put("major", me.major() == null ? "" : me.major());
        out.put("totalHours", me.totalHours());
        out.put("activityCount", myRecordsRepo.countCreditedActivities(uid));
        out.put("serialNo", String.format("HZY-2026-%04d", uid));
        out.put("issueOrg", "鸿志愿校园志愿服务平台");
        out.put("issueDate", java.time.LocalDate.now().toString());
        return out;
    }

    // ==================== 消息中心（B7） ====================

    /** 消息列表（type 可空=全部）：{id,type,relatedId,title,content,isRead,createTime} */
    public Map<String, Object> messages(long uid, String type, int page, int size) {
        int p = Math.max(page, 1);
        int s = Math.min(Math.max(size, 1), 50);
        List<Map<String, Object>> list = new ArrayList<>();
        for (Map<String, Object> row : messageRepo.list(uid, type, (p - 1) * s, s)) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", num(row.get("id")).longValue());
            item.put("type", str(row.get("type")));
            item.put("relatedId", num(row.get("related_id")).longValue());
            item.put("title", str(row.get("title")));
            item.put("content", str(row.get("content")));
            item.put("isRead", num(row.get("is_read")).intValue() > 0);
            item.put("createTime", Times.normTime(row.get("create_time")));
            // 聊天通知的发送者（点通知直达会话用；系统通知为 0）
            Object fu = row.get("from_uid");
            item.put("fromUid", fu == null ? 0L : ((Number) fu).longValue());
            list.add(item);
        }
        Map<String, Object> out = new HashMap<>();
        out.put("list", list);
        out.put("total", messageRepo.count(uid, type));
        out.put("page", p);
        return out;
    }

    /** 四 Tab 未读数 + 总数（App 角标数据源） */
    public Map<String, Object> unreadCounts(long uid) {
        Map<String, Object> raw = messageRepo.unreadByType(uid);
        Map<String, Object> out = new HashMap<>();
        // SUM 在无行时返回 NULL（该用户没有任何消息），归一为 0
        out.put("notice", raw.get("notice") == null ? 0 : num(raw.get("notice")).intValue());
        out.put("interact", raw.get("interact") == null ? 0 : num(raw.get("interact")).intValue());
        out.put("activity", raw.get("activity") == null ? 0 : num(raw.get("activity")).intValue());
        out.put("help", raw.get("help") == null ? 0 : num(raw.get("help")).intValue());
        out.put("total", raw.get("total") == null ? 0 : num(raw.get("total")).intValue());
        return out;
    }

    // ==================== 首页聚合（D3：/api/user/home-summary） ====================

    /**
     * 首页一次拿全：聚合数字 + 本周推荐 + 活动流。
     * 活动项复用 ActivityService.list 的组装结果（距离/已报名/时间格式都已处理），
     * 避免首页为了三块内容发三次请求，也避免转换逻辑写两遍。
     */
    public Map<String, Object> homeSummary(long uid) {
        Map<String, Object> out = new HashMap<>();

        Map<String, Object> list = activityService.list(uid, null, null, "distance", 1, 10);
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> items = (List<Map<String, Object>>) list.get("list");
        out.put("featured", items.isEmpty() ? null : items.get(0));
        out.put("feed", items.size() > 1 ? items.subList(1, Math.min(7, items.size())) : List.of());

        out.put("todayHours", myRecordsRepo.todayHours(uid));
        Map<String, Object> counts = myRecordsRepo.signupCounts(uid);
        out.put("ongoingCount", counts.get("ongoing") == null ? 0 : ((Number) counts.get("ongoing")).intValue());
        out.put("pendingSigninCount", counts.get("pending") == null ? 0 : ((Number) counts.get("pending")).intValue());

        UserRow me = userRepo.findById(uid).orElseThrow();
        out.put("totalHours", me.totalHours());
        out.put("point", me.point());
        out.put("creditScore", me.creditScore());
        // 今日目标 4 小时（与 App mock 口径一致）
        out.put("todayTargetHours", 4);

        Map<String, Object> unread = messageRepo.unreadByType(uid);
        out.put("unreadCount", unread.get("total") == null ? 0 : ((Number) unread.get("total")).intValue());

        myRecordsRepo.nextPendingActivity(uid).ifPresent(a -> {
            out.put("nextActivityId", ((Number) a.get("id")).longValue());
            out.put("nextActivityTitle", str(a.get("title")));
            out.put("nextActivityStartTime", Times.normTime(a.get("start_time")));
        });
        if (!out.containsKey("nextActivityId")) {
            out.put("nextActivityId", 0);
            out.put("nextActivityTitle", "");
            out.put("nextActivityStartTime", "");
        }
        return out;
    }

    /** 全部已读（type 可空=全部），返回置位的条数 */
    public int readAll(long uid, String type) {
        return messageRepo.markAllRead(uid, type);
    }

    /** 单条已读；消息不存在或不属于当前用户 → 404 */
    public void readOne(long uid, long messageId) {
        int n = messageRepo.markRead(uid, messageId);
        if (n == 0) {
            throw new ApiException(404, "消息不存在");
        }
    }

    /**
     * 资料修改（设置页）：姓名必填非空，电话/学院可空串。
     * 学号不可改（注册即定，是校园身份锚点）。
     */
    public void updateProfile(long uid, String name, String phone, String college) {
        if (name == null || name.isBlank()) {
            throw new ApiException(400, "姓名不能为空");
        }
        if (name.length() > 20) {
            throw new ApiException(400, "姓名过长");
        }
        if (phone != null && !phone.isBlank() && !phone.matches("^1\\d{10}$")) {
            throw new ApiException(400, "手机号格式不正确");
        }
        String c = college == null ? "" : college.trim();
        if (c.length() > 40) {
            throw new ApiException(400, "学院名称过长");
        }
        userRepo.updateProfile(uid, name.trim(), phone == null ? "" : phone.trim(), c);
    }

    private static Number num(Object o) {
        return (Number) o;
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }
}
