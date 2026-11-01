package cn.heartgun.guanggu.service;

import cn.heartgun.guanggu.common.ApiException;
import cn.heartgun.guanggu.common.Times;
import cn.heartgun.guanggu.repo.ActivityRepo;
import cn.heartgun.guanggu.repo.MyRecordsRepo;
import cn.heartgun.guanggu.repo.UserRepo;
import cn.heartgun.guanggu.repo.UserRow;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/** 志愿活动：列表（分类/关键词/距离排序+分页）/ 详情 / 发布 / 报名 / 签到核销（B4+B5） */
@Service
public class ActivityService {
    private static final DateTimeFormatter OUT_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final DateTimeFormatter IN_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final Random CODE_RANDOM = new SecureRandom();

    private final ActivityRepo activityRepo;
    private final UserRepo userRepo;
    private final MyRecordsRepo myRecordsRepo;

    public ActivityService(ActivityRepo activityRepo, UserRepo userRepo, MyRecordsRepo myRecordsRepo) {
        this.activityRepo = activityRepo;
        this.userRepo = userRepo;
        this.myRecordsRepo = myRecordsRepo;
    }

    /**
     * 更新活动信息：仅发布者本人；标题必填、时间格式校验。
     * cover 传空串表示不改封面（保持原值）。
     */
    @Transactional
    public void update(long activityId, long uid, Map<String, Object> body) {
        Map<String, Object> row = activityRepo.findById(activityId, uid)
                .orElseThrow(() -> new ApiException(404, "活动不存在或已删除"));
        if (((Number) row.get("publisher_id")).longValue() != uid) {
            throw new ApiException(403, "仅发布者本人可以修改活动");
        }
        String title = str(body.get("title")).trim();
        if (title.isEmpty()) {
            throw new ApiException(400, "活动标题不能为空");
        }
        String startTime = str(body.get("startTime"));
        String endTime = str(body.get("endTime"));
        try {
            LocalDateTime.parse(startTime, IN_FMT);
            LocalDateTime.parse(endTime, IN_FMT);
        } catch (Exception e) {
            throw new ApiException(400, "时间格式应为 yyyy-MM-dd HH:mm:ss");
        }
        String cover = str(body.get("cover"));
        activityRepo.update(activityId, title,
                strOr(body.get("category"), str(row.get("category"))),
                cover.isEmpty() ? null : cover,
                strOr(body.get("description"), ""),
                strOr(body.get("address"), ""),
                numOr(body.get("lat")), numOr(body.get("lng")),
                startTime, endTime,
                (int) numOr(body.get("needCount")),
                numOr(body.get("serviceHours")));
    }

    /**
     * 删除活动：仅发布者本人；已有时长入账的活动禁止删除（证书统计依赖）。
     * 未开始/招募中的活动连同报名记录一起删。
     */
    @Transactional
    public void delete(long activityId, long uid) {
        Map<String, Object> row = activityRepo.findById(activityId, uid)
                .orElseThrow(() -> new ApiException(404, "活动不存在或已删除"));
        if (((Number) row.get("publisher_id")).longValue() != uid) {
            throw new ApiException(403, "仅发布者本人可以删除活动");
        }
        if (activityRepo.hasHours(activityId)) {
            throw new ApiException(400, "该活动已有签到入账记录，不能删除");
        }
        activityRepo.deleteActivity(activityId);
    }

    /** 我发布的活动（发布者管理入口：看报名/签到二维码/咨询会话） */
    public List<Map<String, Object>> myPublished(long uid) {
        UserRow me = userRepo.findById(uid).orElseThrow();
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : activityRepo.listByPublisher(uid)) {
            out.add(toListItem(row, me));
        }
        return out;
    }

    /**
     * 列表：category 过滤、keyword 标题模糊、sort=distance(默认 time)、page/size 分页。
     * 表只有 30 行量级 → 全量取回内存过滤排序，距离在 Java 里算 Haversine。
     */
    public Map<String, Object> list(long uid, String category, String keyword,
                                    String sort, int page, int size) {
        UserRow me = userRepo.findById(uid).orElseThrow();
        List<Map<String, Object>> all = activityRepo.listAll(uid);

        List<Map<String, Object>> filtered = new ArrayList<>();
        for (Map<String, Object> row : all) {
            if (category != null && !category.isBlank()
                    && !category.equals(row.get("category"))) {
                continue;
            }
            if (keyword != null && !keyword.isBlank()
                    && !String.valueOf(row.get("title")).contains(keyword.trim())) {
                continue;
            }
            Map<String, Object> item = toListItem(row, me);
            filtered.add(item);
        }

        if ("distance".equalsIgnoreCase(sort)) {
            filtered.sort(Comparator.comparingDouble(m -> (double) m.get("distance")));
        } else {
            filtered.sort(Comparator.comparing(m -> String.valueOf(m.get("startTime"))));
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

    public Map<String, Object> detail(long activityId, long uid) {
        Map<String, Object> row = activityRepo.findById(activityId, uid)
                .orElseThrow(() -> new ApiException(404, "活动不存在或已删除"));
        UserRow me = userRepo.findById(uid).orElseThrow();
        Map<String, Object> detail = toListItem(row, me);
        detail.put("publisherName", "");
        detail.put("publisherCollege", "");
        detail.put("publisherCredit", 0);
        if (row.get("publisher_id") != null) {
            long pid = ((Number) row.get("publisher_id")).longValue();
            activityRepo.findPublisher(pid).ifPresent(pub -> {
                detail.put("publisherName", str(pub.get("name")));
                detail.put("publisherCollege", str(pub.get("college")));
                detail.put("publisherCredit", num(pub.get("credit_score")).intValue());
                // 嵌套 publisher 对象：前端 Activity.fromJson 读的是嵌套结构（对齐互助详情的先例），
                // 只给扁平字段会导致详情页发布者卡恒空
                Map<String, Object> pubMap = new HashMap<>();
                pubMap.put("id", pid);
                pubMap.put("name", str(pub.get("name")));
                pubMap.put("college", str(pub.get("college")));
                pubMap.put("creditScore", num(pub.get("credit_score")).intValue());
                pubMap.put("phone", str(pub.get("phone")));
                detail.put("publisher", pubMap);
            });
        }
        detail.put("participants", activityRepo.signedUsers(activityId, 5));
        // 签到码只对发布者本人下发（签到二维码用）；其他人不下发，防提前泄露
        if (row.get("publisher_id") != null
                && ((Number) row.get("publisher_id")).longValue() == uid) {
            detail.put("signinCode", str(row.get("signin_code")));
        }
        return detail;
    }

    /** 发布：校验必填 → 生成唯一 6 位签到码 → 入库（发布者不自动报名） */
    public Map<String, Object> publish(long uid, Map<String, Object> body) {
        String title = str(body.get("title"));
        String category = str(body.get("category"));
        String address = str(body.get("address"));
        String startTime = str(body.get("startTime"));
        String endTime = str(body.get("endTime"));
        if (isBlank(title) || isBlank(category) || isBlank(address) || isBlank(startTime) || isBlank(endTime)) {
            throw new ApiException(400, "标题、分类、地点与时间不能为空");
        }
        int needCount = num(body.get("needCount")).intValue();
        double serviceHours = num(body.get("serviceHours")).doubleValue();
        if (needCount <= 0 || serviceHours <= 0) {
            throw new ApiException(400, "招募人数与志愿时长必须大于 0");
        }
        try {
            LocalDateTime.parse(startTime, IN_FMT);
            LocalDateTime.parse(endTime, IN_FMT);
        } catch (Exception e) {
            throw new ApiException(400, "时间格式应为 yyyy-MM-dd HH:mm:ss");
        }
        String code = newSigninCode();
        long id = activityRepo.insert(title, category, strOr(body.get("cover"), ""),
                strOr(body.get("description"), ""), address,
                numOr(body.get("lat")), numOr(body.get("lng")),
                startTime, endTime, needCount, serviceHours, code, uid);
        Map<String, Object> out = new HashMap<>();
        out.put("id", id);
        out.put("signinCode", code);
        return out;
    }

    /** 报名：活动存在 + 招募中 + 未满员 + 未重复；事务内 插入+自增+发消息 */
    @Transactional
    public void signup(long activityId, long uid) {
        Map<String, Object> row = activityRepo.findById(activityId, uid)
                .orElseThrow(() -> new ApiException(404, "活动不存在或已删除"));
        if (!"signuping".equals(row.get("status"))) {
            throw new ApiException(400, "该活动当前不在报名期");
        }
        if (num(row.get("signed_up")).intValue() > 0) {
            throw new ApiException(400, "你已报名过该活动");
        }
        if (num(row.get("joined_count")).intValue() >= num(row.get("need_count")).intValue()) {
            throw new ApiException(400, "名额已满");
        }
        try {
            activityRepo.insertSignup(activityId, uid);
        } catch (DuplicateKeyException e) {
            throw new ApiException(400, "你已报名过该活动");
        }
        activityRepo.addJoined(activityId);

        // 报名成功消息（B7 的写入时机之一，先在这里挂上）
        String start = str(row.get("start_time"));
        String title = str(row.get("title"));
        activityRepo.insertMessage(uid, "activity", activityId, "报名成功",
                "你已成功报名「" + title + "」，请于 " + start.substring(5, 16).replace('-', '-')
                        .replace('T', ' ') + " 前到场并扫码签到。", 0);
    }

    /**
     * 签到核销（B5）：验签到码 → 已报名且未重复 → 一个事务里完成
     * 写 sign_record / 报名转 checked_in / volunteer_hour 入账 / total_hours 累加 / 到账消息。
     * signType：scan（扫码）/ manual（手输）/ geo（定位签到，F2）。
     * 【F2 围栏】geo 类型免码（围栏即凭证），但必须带坐标且落在活动签到半径内；
     *   scan/manual 不做围栏校验 —— 模拟器/无定位场景的演示兜底不被拦。
     */
    @Transactional
    public Map<String, Object> signin(long uid, long activityId, String code, String signType,
                                      double lat, double lng) {
        Map<String, Object> row = activityRepo.findById(activityId, uid)
                .orElseThrow(() -> new ApiException(404, "活动不存在或已删除"));
        boolean isGeo = "geo".equals(signType);
        if (isGeo) {
            if (lat == 0 || lng == 0) {
                throw new ApiException(400, "定位失败，请改用扫码或手输签到");
            }
            double actLat = row.get("lat") == null ? 0 : num(row.get("lat")).doubleValue();
            double actLng = row.get("lng") == null ? 0 : num(row.get("lng")).doubleValue();
            double radius = row.get("signin_radius") == null
                    ? 200 : num(row.get("signin_radius")).doubleValue();
            if (actLat == 0 && actLng == 0) {
                throw new ApiException(400, "该活动未配置签到点，请改用扫码或手输签到");
            }
            double dist = distanceMeters(lat, lng, actLat, actLng);
            if (dist > radius) {
                throw new ApiException(400,
                        "不在签到范围内（距签到点约 " + Math.round(dist) + " 米），请到场后签到");
            }
        } else if (isBlank(code) || !code.equals(str(row.get("signin_code")))) {
            throw new ApiException(400, "签到码不正确，请核对后重试");
        }
        Map<String, Object> signup = myRecordsRepo.findSignup(activityId, uid)
                .orElseThrow(() -> new ApiException(400, "请先报名该活动"));
        String status = str(signup.get("status"));
        if (!"signed_up".equals(status)) {
            throw new ApiException(400, "该活动已签到，请勿重复操作");
        }
        double hours = num(row.get("service_hours")).doubleValue();
        String now = Times.now();

        myRecordsRepo.insertSignRecord(activityId, uid,
                isBlank(signType) ? "manual" : signType, lat, lng);
        myRecordsRepo.updateSignupCheckedIn(activityId, uid);
        myRecordsRepo.insertHour(uid, activityId, hours);
        myRecordsRepo.addTotalHours(uid, hours);
        double total = myRecordsRepo.totalHours(uid);
        activityRepo.insertMessage(uid, "notice", activityId, "志愿时长已到账",
                "「" + str(row.get("title")) + "」" + hours + " 小时已计入你的累计志愿时长。", 0);

        Map<String, Object> out = new HashMap<>();
        out.put("hours", hours);
        out.put("totalHours", total);
        out.put("signinTime", now);
        return out;
    }

    // ==================== 内部工具 ====================

    /** JDBC 的 DATETIME 在 Map 里是 LocalDateTime（toString 带 T 且省零秒），App 端要 "yyyy-MM-dd HH:mm:ss" —— 显式转，不赌 Jackson 配置 */
    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private static String normTime(Object o) {
        if (o instanceof LocalDateTime) {
            return ((LocalDateTime) o).format(FMT);
        }
        if (o instanceof java.sql.Timestamp) {
            return ((java.sql.Timestamp) o).toLocalDateTime().format(FMT);
        }
        return o == null ? "" : o.toString();
    }

    private Map<String, Object> toListItem(Map<String, Object> row, UserRow me) {
        Map<String, Object> item = new HashMap<>();
        item.put("id", num(row.get("id")).longValue());
        // 发布者 id：App 端 isPublisher 判断（签到二维码入口）靠它
        item.put("publisherId", row.get("publisher_id") == null ? 0L : num(row.get("publisher_id")).longValue());
        item.put("title", str(row.get("title")));
        item.put("category", str(row.get("category")));
        item.put("cover", str(row.get("cover")));
        item.put("description", str(row.get("description")));
        item.put("address", str(row.get("address")));
        item.put("lat", num(row.get("lat")).doubleValue());
        item.put("lng", num(row.get("lng")).doubleValue());
        item.put("startTime", normTime(row.get("start_time")));
        item.put("endTime", normTime(row.get("end_time")));
        item.put("needCount", num(row.get("need_count")).intValue());
        item.put("joinedCount", num(row.get("joined_count")).intValue());
        item.put("serviceHours", num(row.get("service_hours")).doubleValue());
        item.put("status", str(row.get("status")));
        item.put("signedUp", num(row.get("signed_up")).intValue() > 0);
        double dist = distance(me.lat(), me.lng(),
                num(row.get("lat")).doubleValue(), num(row.get("lng")).doubleValue());
        item.put("distance", dist);
        return item;
    }

    /** Haversine 距离，保留 1 位小数（km） */
    static double distance(double lat1, double lng1, double lat2, double lng2) {
        final double r = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double raw = r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return Math.round(raw * 10) / 10.0;
    }

    private String newSigninCode() {
        // 6 位数字签到码；碰撞则重试（30 行规模碰撞概率可忽略，防御性写法）
        for (int i = 0; i < 20; i++) {
            String code = String.format("%06d", CODE_RANDOM.nextInt(1000000));
            if (activityRepo.findByIdByCode(code).isEmpty()) {
                return code;
            }
        }
        throw new ApiException(500, "签到码生成失败，请重试");
    }

    private static Number num(Object o) {
        return (Number) o;
    }

    /** 球面近似距离（米）：equirectangular 简化式，百米级围栏场景足够 */
    private static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
        double rad = Math.PI / 180;
        double x = (lng2 - lng1) * rad * Math.cos((lat1 + lat2) / 2 * rad);
        double y = (lat2 - lat1) * rad;
        return Math.sqrt(x * x + y * y) * 6371000;
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }

    private static String strOr(Object o, String def) {
        return o == null || o.toString().isBlank() ? def : o.toString();
    }

    private static double numOr(Object o) {
        return o instanceof Number ? ((Number) o).doubleValue() : 0.0;
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
