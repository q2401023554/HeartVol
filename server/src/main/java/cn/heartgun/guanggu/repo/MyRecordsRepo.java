package cn.heartgun.guanggu.repo;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/** 「我的」域数据访问：我的报名 / 时长明细 / 签到写入 / 时长入账（B5） */
@Repository
public class MyRecordsRepo {
    private final NamedParameterJdbcTemplate jdbc;

    public MyRecordsRepo(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** 我的报名：联活动表，字段对齐 App Signup 模型（activity 内嵌对象由 service 组装） */
    public List<Map<String, Object>> mySignups(long uid) {
        return jdbc.queryForList(
                "SELECT s.id AS signup_id, s.status AS signup_status, s.signup_time, " +
                        "a.id AS a_id, a.title, a.category, a.cover, a.description, a.address, a.lat, a.lng, " +
                        "a.start_time, a.end_time, a.need_count, a.joined_count, a.service_hours, a.status AS a_status " +
                        "FROM activity_signup s JOIN volunteer_activity a ON a.id = s.activity_id " +
                        "WHERE s.user_id = :u ORDER BY a.start_time DESC",
                new MapSqlParameterSource("u", uid));
    }

    /** 时长明细：联活动表取标题/分类（App HourRecord 的 activityTitle/activityCategory） */
    public List<Map<String, Object>> myHours(long uid) {
        return jdbc.queryForList(
                "SELECT h.id, h.user_id, h.activity_id, h.hours, h.gain_time, " +
                        "a.title, a.category " +
                        "FROM volunteer_hour h LEFT JOIN volunteer_activity a ON a.id = h.activity_id " +
                        "WHERE h.user_id = :u ORDER BY h.gain_time DESC",
                new MapSqlParameterSource("u", uid));
    }

    /** 查报名记录（签到校验用） */
    public Optional<Map<String, Object>> findSignup(long activityId, long uid) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT id, status FROM activity_signup WHERE activity_id = :a AND user_id = :u",
                new MapSqlParameterSource().addValue("a", activityId).addValue("u", uid));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public void insertSignRecord(long activityId, long uid, String signType, double lat, double lng) {
        jdbc.update("INSERT INTO sign_record (activity_id, user_id, sign_type, lat, lng) VALUES " +
                        "(:a, :u, :t, :lat, :lng)",
                new MapSqlParameterSource().addValue("a", activityId).addValue("u", uid)
                        .addValue("t", signType).addValue("lat", lat).addValue("lng", lng));
    }

    public void updateSignupCheckedIn(long activityId, long uid) {
        jdbc.update("UPDATE activity_signup SET status = 'checked_in' WHERE activity_id = :a AND user_id = :u",
                new MapSqlParameterSource().addValue("a", activityId).addValue("u", uid));
    }

    public void insertHour(long uid, long activityId, double hours) {
        jdbc.update("INSERT INTO volunteer_hour (user_id, activity_id, hours) VALUES (:u, :a, :h)",
                new MapSqlParameterSource().addValue("u", uid).addValue("a", activityId).addValue("h", hours));
    }

    public void addTotalHours(long uid, double hours) {
        jdbc.update("UPDATE sys_user SET total_hours = total_hours + :h WHERE id = :u",
                new MapSqlParameterSource().addValue("u", uid).addValue("h", hours));
    }

    // ==================== 首页聚合（D3：/api/user/home-summary） ====================

    /** 今日已入账时长（小时） */
    public double todayHours(long uid) {
        Double v = jdbc.queryForObject(
                "SELECT IFNULL(SUM(hours), 0) FROM volunteer_hour WHERE user_id = :u AND DATE(gain_time) = CURDATE()",
                new MapSqlParameterSource("u", uid), Double.class);
        return v == null ? 0.0 : v;
    }

    /** 报名状态计数：checked_in（参与中）/ signed_up（待签到） */
    public Map<String, Object> signupCounts(long uid) {
        return jdbc.queryForMap(
                "SELECT " +
                        "SUM(CASE WHEN status = 'checked_in' THEN 1 ELSE 0 END) AS ongoing, " +
                        "SUM(CASE WHEN status = 'signed_up' THEN 1 ELSE 0 END) AS pending " +
                        "FROM activity_signup WHERE user_id = :u",
                new MapSqlParameterSource("u", uid));
    }

    /** 最近一场「已报名但未签到」的活动（首页提醒条的数据源） */
    public Optional<Map<String, Object>> nextPendingActivity(long uid) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT a.id, a.title, a.start_time FROM activity_signup s " +
                        "JOIN volunteer_activity a ON a.id = s.activity_id " +
                        "WHERE s.user_id = :u AND s.status = 'signed_up' " +
                        "ORDER BY a.start_time LIMIT 1",
                new MapSqlParameterSource("u", uid));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** 当前累计时长（B5 签到入账后回食用） */
    public double totalHours(long uid) {
        return jdbc.queryForObject("SELECT total_hours FROM sys_user WHERE id = :u",
                new MapSqlParameterSource("u", uid), Double.class);
    }

    /** 已入账时长明细条数 = 参与并完成核销的活动场次（证书用） */
    public int countCreditedActivities(long uid) {
        Integer n = jdbc.queryForObject(
                "SELECT COUNT(*) FROM volunteer_hour WHERE user_id = :u",
                new MapSqlParameterSource("u", uid), Integer.class);
        return n == null ? 0 : n;
    }
}
