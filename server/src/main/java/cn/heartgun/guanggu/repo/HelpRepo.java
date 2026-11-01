package cn.heartgun.guanggu.repo;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/** 互助域数据访问（B6） */
@Repository
public class HelpRepo {
    private final NamedParameterJdbcTemplate jdbc;

    public HelpRepo(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Map<String, Object>> listAll(long uid) {
        return jdbc.queryForList(
                "SELECT h.*, " +
                        "p.name AS publisher_name, p.college AS publisher_college, p.credit_score AS publisher_credit, " +
                        "(SELECT COUNT(*) FROM help_order o WHERE o.request_id = h.id AND o.helper_id = :uid) AS is_helper, " +
                        "(SELECT o.status FROM help_order o WHERE o.request_id = h.id AND o.helper_id = :uid LIMIT 1) AS my_order_status " +
                        "FROM help_request h LEFT JOIN sys_user p ON p.id = h.publisher_id ORDER BY h.create_time DESC",
                new MapSqlParameterSource("uid", uid));
    }

    /** 我发布的求助（发布者管理入口） */
    public List<Map<String, Object>> listByPublisher(long publisherId) {
        return jdbc.queryForList(
                "SELECT h.*, " +
                        "p.name AS publisher_name, p.college AS publisher_college, p.credit_score AS publisher_credit, " +
                        "(SELECT COUNT(*) FROM help_order o WHERE o.request_id = h.id AND o.helper_id = :uid) AS is_helper, " +
                        "(SELECT o.status FROM help_order o WHERE o.request_id = h.id AND o.helper_id = :uid LIMIT 1) AS my_order_status " +
                        "FROM help_request h LEFT JOIN sys_user p ON p.id = h.publisher_id " +
                        "WHERE h.publisher_id = :uid ORDER BY h.create_time DESC",
                new MapSqlParameterSource("uid", publisherId));
    }

    public Optional<Map<String, Object>> findById(long id, long uid) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT h.*, " +
                        "p.name AS publisher_name, p.college AS publisher_college, p.credit_score AS publisher_credit, " +
                        "(SELECT COUNT(*) FROM help_order o WHERE o.request_id = h.id AND o.helper_id = :uid) AS is_helper, " +
                        "(SELECT o.status FROM help_order o WHERE o.request_id = h.id AND o.helper_id = :uid LIMIT 1) AS my_order_status " +
                        "FROM help_request h LEFT JOIN sys_user p ON p.id = h.publisher_id WHERE h.id = :id",
                new MapSqlParameterSource().addValue("id", id).addValue("uid", uid));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public Optional<Map<String, Object>> findPublisher(long publisherId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT name, college, credit_score FROM sys_user WHERE id = :id",
                new MapSqlParameterSource("id", publisherId));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public Optional<Map<String, Object>> findOrder(long requestId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT id, helper_id, status, accept_time, finish_time FROM help_order " +
                        "WHERE request_id = :r ORDER BY accept_time DESC LIMIT 1",
                new MapSqlParameterSource("r", requestId));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public Optional<Map<String, Object>> findOrderById(long orderId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT id, request_id, helper_id, status, accept_time, finish_time FROM help_order WHERE id = :o",
                new MapSqlParameterSource("o", orderId));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** 该订单已落库的评价数（=2 表示双方都评完，此时发互评奖励） */
    public int reviewCount(long orderId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM help_review WHERE order_id = :o",
                new MapSqlParameterSource("o", orderId), Integer.class);
    }

    public List<Map<String, Object>> reviewsOf(long requestId) {
        return jdbc.queryForList(
                "SELECT r.id, r.order_id, r.from_user_id, r.to_user_id, r.score, r.content, r.create_time, u.name AS from_user_name " +
                        "FROM help_review r JOIN help_order o ON o.id = r.order_id " +
                        "JOIN sys_user u ON u.id = r.from_user_id " +
                        "WHERE o.request_id = :r ORDER BY r.create_time",
                new MapSqlParameterSource("r", requestId));
    }

    public long insert(long publisherId, String title, String category, String description,
                       int rewardPoint, String expectTime, String address, double lat, double lng) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("publisherId", publisherId).addValue("title", title)
                .addValue("category", category).addValue("description", description)
                .addValue("rewardPoint", rewardPoint).addValue("expectTime", expectTime)
                .addValue("address", address).addValue("lat", lat).addValue("lng", lng);
        jdbc.update("INSERT INTO help_request (publisher_id, title, category, description, reward_point, " +
                        "expect_time, address, lat, lng, status) VALUES " +
                        "(:publisherId, :title, :category, :description, :rewardPoint, :expectTime, " +
                        ":address, :lat, :lng, 'pending')", p);
        return jdbc.queryForObject("SELECT LAST_INSERT_ID()", p, Long.class);
    }

    public void insertOrder(long requestId, long helperId) {
        jdbc.update("INSERT INTO help_order (request_id, helper_id, status) VALUES (:r, :h, 'ongoing')",
                new MapSqlParameterSource().addValue("r", requestId).addValue("h", helperId));
    }

    public void updateRequestStatus(long requestId, String status) {
        jdbc.update("UPDATE help_request SET status = :s WHERE id = :r",
                new MapSqlParameterSource().addValue("r", requestId).addValue("s", status));
    }

    public void updateOrderFinished(long orderId) {
        jdbc.update("UPDATE help_order SET status = 'finished', finish_time = NOW() WHERE id = :o",
                new MapSqlParameterSource("o", orderId));
    }

    /** 互评：order_id + from 唯一，重复评价靠捕获 DuplicateKeyException 拦 */
    public void insertReview(long orderId, long fromUserId, long toUserId, int score, String content) {
        jdbc.update("INSERT INTO help_review (order_id, from_user_id, to_user_id, score, content) VALUES " +
                        "(:o, :f, :t, :s, :c)",
                new MapSqlParameterSource().addValue("o", orderId).addValue("f", fromUserId)
                        .addValue("t", toUserId).addValue("s", score).addValue("c", content));
    }

    public void insertPointLog(long userId, int changeValue, int balance, String reason, long relatedId) {
        jdbc.update("INSERT INTO point_log (user_id, change_value, balance, reason, related_id) VALUES " +
                        "(:u, :c, :b, :r, :rel)",
                new MapSqlParameterSource().addValue("u", userId).addValue("c", changeValue)
                        .addValue("b", balance).addValue("r", reason).addValue("rel", relatedId));
    }

    /** 积分变动：返回变动后余额（调用方先自行校验余额充足） */
    public int adjustPoint(long userId, int delta) {
        jdbc.update("UPDATE sys_user SET point = point + :d WHERE id = :u",
                new MapSqlParameterSource().addValue("u", userId).addValue("d", delta));
        return jdbc.queryForObject("SELECT point FROM sys_user WHERE id = :u",
                new MapSqlParameterSource("u", userId), Integer.class);
    }

    public int pointOf(long userId) {
        return jdbc.queryForObject("SELECT point FROM sys_user WHERE id = :u",
                new MapSqlParameterSource("u", userId), Integer.class);
    }

    public void adjustCredit(long userId, int delta) {
        jdbc.update("UPDATE sys_user SET credit_score = credit_score + :d WHERE id = :u",
                new MapSqlParameterSource().addValue("u", userId).addValue("d", delta));
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
