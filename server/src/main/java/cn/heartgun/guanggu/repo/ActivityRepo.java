package cn.heartgun.guanggu.repo;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/** 志愿活动数据访问（表仅 30 行量级，取回内存加工即可，不写复杂 SQL） */
@Repository
public class ActivityRepo {
    private final NamedParameterJdbcTemplate jdbc;

    /** 列表/详情通用列：signed_up 是当前用户是否已报名（子查询） */
    public static final String LIST_COLUMNS =
            "a.id, a.title, a.category, a.cover, a.description, a.address, a.lat, a.lng, " +
                    "a.start_time, a.end_time, a.need_count, a.joined_count, a.service_hours, " +
                    "a.signin_code, a.status, a.publisher_id, a.create_time, " +
                    "(SELECT COUNT(*) FROM activity_signup s WHERE s.activity_id = a.id AND s.user_id = :uid) AS signed_up";

    public ActivityRepo(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Map<String, Object>> listAll(long uid) {
        return jdbc.queryForList("SELECT " + LIST_COLUMNS + " FROM volunteer_activity a " +
                        "ORDER BY a.start_time",
                new MapSqlParameterSource("uid", uid));
    }

    /**
     * 更新活动信息（发布者管理页用）。全量更新可编辑字段；
     * cover 传 null 时跳过（避免把已上传封面清空）。
     */
    public void update(long activityId, String title, String category, String cover,
                       String description, String address, double lat, double lng,
                       String startTime, String endTime, int needCount, double serviceHours) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("id", activityId)
                .addValue("title", title).addValue("category", category)
                .addValue("description", description).addValue("address", address)
                .addValue("lat", lat).addValue("lng", lng)
                .addValue("startTime", startTime).addValue("endTime", endTime)
                .addValue("needCount", needCount).addValue("serviceHours", serviceHours);
        String sql = "UPDATE volunteer_activity SET title=:title, category=:category, " +
                "description=:description, address=:address, lat=:lat, lng=:lng, " +
                "start_time=:startTime, end_time=:endTime, need_count=:needCount, service_hours=:serviceHours";
        if (cover != null) {
            sql = sql + ", cover=:cover";
            p.addValue("cover", cover);
        }
        jdbc.update(sql + " WHERE id=:id", p);
    }

    /** 该活动是否已有时长入账（有则不允许删除——证书统计依赖） */
    public boolean hasHours(long activityId) {
        Integer n = jdbc.queryForObject(
                "SELECT COUNT(*) FROM volunteer_hour WHERE activity_id = :a",
                new MapSqlParameterSource("a", activityId), Integer.class);
        return n != null && n > 0;
    }

    /** 删除活动及其报名记录（仅在无时长入账时调用；@Transactional 由 service 层控制） */
    public void deleteActivity(long activityId) {
        jdbc.update("DELETE FROM activity_signup WHERE activity_id = :a",
                new MapSqlParameterSource("a", activityId));
        jdbc.update("DELETE FROM volunteer_activity WHERE id = :a",
                new MapSqlParameterSource("a", activityId));
    }

    /** 我发布的活动（发布者管理入口：查看报名/签到二维码/咨询会话） */
    public List<Map<String, Object>> listByPublisher(long publisherId) {
        return jdbc.queryForList("SELECT " + LIST_COLUMNS + " FROM volunteer_activity a " +
                        "WHERE a.publisher_id = :p ORDER BY a.start_time DESC",
                new MapSqlParameterSource().addValue("p", publisherId).addValue("uid", publisherId));
    }

    public Optional<Map<String, Object>> findById(long id, long uid) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT " + LIST_COLUMNS + " FROM volunteer_activity a WHERE a.id = :id",
                new MapSqlParameterSource().addValue("id", id).addValue("uid", uid));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public Optional<Map<String, Object>> findPublisher(long publisherId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT name, college, credit_score, phone FROM sys_user WHERE id = :id",
                new MapSqlParameterSource("id", publisherId));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** 详情页「参与者」叠头像：最近报名的前 5 人 */
    public List<Map<String, Object>> signedUsers(long activityId, int limit) {
        return jdbc.queryForList(
                "SELECT u.name, u.avatar FROM activity_signup s JOIN sys_user u ON u.id = s.user_id " +
                        "WHERE s.activity_id = :id ORDER BY s.signup_time LIMIT " + limit,
                new MapSqlParameterSource("id", activityId));
    }

    /** 签到码查重（发布时生成 6 位码用） */
    public List<Map<String, Object>> findByIdByCode(String signinCode) {
        return jdbc.queryForList("SELECT id FROM volunteer_activity WHERE signin_code = :c LIMIT 1",
                new MapSqlParameterSource("c", signinCode));
    }

    /** 发布：返回新活动 id（signin_code 6 位唯一由 service 保证） */
    public long insert(String title, String category, String cover, String description,
                       String address, double lat, double lng, String startTime, String endTime,
                       int needCount, double serviceHours, String signinCode, long publisherId) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("title", title).addValue("category", category).addValue("cover", cover)
                .addValue("description", description).addValue("address", address)
                .addValue("lat", lat).addValue("lng", lng)
                .addValue("startTime", startTime).addValue("endTime", endTime)
                .addValue("needCount", needCount).addValue("serviceHours", serviceHours)
                .addValue("signinCode", signinCode).addValue("publisherId", publisherId);
        jdbc.update("INSERT INTO volunteer_activity (title, category, cover, description, address, lat, lng, " +
                        "start_time, end_time, need_count, joined_count, service_hours, signin_code, signin_radius, " +
                        "status, publisher_id) VALUES " +
                        "(:title, :category, :cover, :description, :address, :lat, :lng, :startTime, :endTime, " +
                        ":needCount, 0, :serviceHours, :signinCode, 200, 'signuping', :publisherId)", p);
        return jdbc.queryForObject("SELECT LAST_INSERT_ID()", p, Long.class);
    }

    /** 报名：插入 + 人数自增必须在同一事务（service 上加 @Transactional） */
    public void insertSignup(long activityId, long userId) {
        jdbc.update("INSERT INTO activity_signup (activity_id, user_id, status) VALUES " +
                        "(:a, :u, 'signed_up')",
                new MapSqlParameterSource().addValue("a", activityId).addValue("u", userId));
    }

    public int addJoined(long activityId) {
        return jdbc.update("UPDATE volunteer_activity SET joined_count = joined_count + 1 WHERE id = :a",
                new MapSqlParameterSource("a", activityId));
    }

    /** fromUid：消息发送者（聊天通知用来定位会话对端；系统通知传 0） */
    public void insertMessage(long userId, String type, long relatedId, String title, String content, long fromUid) {
        jdbc.update("INSERT INTO message (user_id, type, related_id, title, content, from_uid) VALUES " +
                        "(:u, :t, :r, :title, :content, :f)",
                new MapSqlParameterSource().addValue("u", userId).addValue("t", type)
                        .addValue("r", relatedId).addValue("title", title).addValue("content", content)
                        .addValue("f", fromUid));
    }
}
