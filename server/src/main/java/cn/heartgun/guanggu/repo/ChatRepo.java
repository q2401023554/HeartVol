package cn.heartgun.guanggu.repo;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 互助/活动沟通聊天表（简化版 IM）：会话键 = (biz_type, biz_id)，
 * biz_type=help → 双方=发布者↔接单者；biz_type=activity → 任意用户↔活动发布者（咨询）。
 * 前端 2 秒轮询 afterId 增量拉取，单实例部署无需 WebSocket/中间件。
 * ⚠️ 表名 help_chat（chat_message 已被 G 阶段智能体会话表占用）。
 */
@Repository
public class ChatRepo {
    private final NamedParameterJdbcTemplate jdbc;

    public ChatRepo(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** 求助会话双方：发布者 + 接单者（未接单时 helper 为 null） */
    public Optional<Map<String, Object>> helpPeerInfo(long requestId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT r.publisher_id AS pub, o.helper_id AS helper " +
                        "FROM help_request r LEFT JOIN help_order o ON o.request_id = r.id " +
                        "WHERE r.id = :rid",
                new MapSqlParameterSource("rid", requestId));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** 活动会话对端：发布者（任意登录用户都可咨询） */
    public Optional<Map<String, Object>> activityPeerInfo(long activityId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT publisher_id AS pub FROM volunteer_activity WHERE id = :aid",
                new MapSqlParameterSource("aid", activityId));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public long insert(String bizType, long bizId, long fromUid, long toUid, String content) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("bizType", bizType).addValue("bizId", bizId)
                .addValue("from", fromUid).addValue("to", toUid).addValue("content", content);
        jdbc.update("INSERT INTO help_chat (biz_type, biz_id, from_uid, to_uid, content) " +
                        "VALUES (:bizType, :bizId, :from, :to, :content)", p);
        return jdbc.queryForObject("SELECT LAST_INSERT_ID()", p, Long.class);
    }

    /** afterId 增量拉取（id 升序）：限定 (me, peer) 二人对话——同一活动多咨询者互不串台 */
    public List<Map<String, Object>> listAfter(String bizType, long bizId, long me, long peer, long afterId) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("bizType", bizType).addValue("bizId", bizId)
                .addValue("me", me).addValue("peer", peer).addValue("after", afterId);
        return jdbc.queryForList("SELECT id, from_uid, to_uid, content, is_read, create_time " +
                        "FROM help_chat WHERE biz_type = :bizType AND biz_id = :bizId AND id > :after " +
                        "AND ((from_uid = :me AND to_uid = :peer) OR (from_uid = :peer AND to_uid = :me)) " +
                        "ORDER BY id ASC LIMIT 200", p);
    }

    /** 拉取即已读：把对端发给我的标为已读 */
    public void markIncomingRead(String bizType, long bizId, long me, long peer) {
        jdbc.update("UPDATE help_chat SET is_read = 1 " +
                        "WHERE biz_type = :bizType AND biz_id = :bizId " +
                        "AND from_uid = :peer AND to_uid = :me AND is_read = 0",
                new MapSqlParameterSource().addValue("bizType", bizType)
                        .addValue("bizId", bizId).addValue("me", me).addValue("peer", peer));
    }

    /** 用户名（聊天页标题栏显示对方） */
    public String userName(long uid) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT name FROM sys_user WHERE id = :u",
                new MapSqlParameterSource("u", uid));
        if (rows.isEmpty()) {
            return "";
        }
        Object name = rows.get(0).get("name");
        return name == null ? "" : name.toString();
    }

    /**
     * 我的会话列表：按 (业务类型, 业务 id, 对端) 聚合 —— 同一活动下不同报名者
     * 与发布者的会话互不混淆。标题 COALESCE 求助/活动两张业务表。
     */
    public List<Map<String, Object>> myConversations(long uid) {
        MapSqlParameterSource p = new MapSqlParameterSource("u", uid);
        return jdbc.queryForList(
                "SELECT t.biz_type, t.biz_id, t.peer_id, u.name AS peer_name, " +
                        "  COALESCE(h.title, a.title, '') AS biz_title, " +
                        "  t.unread, c.content AS last_content, c.create_time AS last_time " +
                        "FROM ( " +
                        "  SELECT biz_type, biz_id, " +
                        "    MAX(CASE WHEN from_uid = :u THEN to_uid ELSE from_uid END) AS peer_id, " +
                        "    SUM(CASE WHEN to_uid = :u AND is_read = 0 THEN 1 ELSE 0 END) AS unread, " +
                        "    MAX(id) AS last_id " +
                        "  FROM help_chat " +
                        "  WHERE from_uid = :u OR to_uid = :u " +
                        "  GROUP BY biz_type, biz_id, " +
                        "    CASE WHEN from_uid = :u THEN to_uid ELSE from_uid END " +
                        ") t " +
                        "JOIN help_chat c ON c.id = t.last_id " +
                        "JOIN sys_user u ON u.id = t.peer_id " +
                        "LEFT JOIN help_request h ON t.biz_type = 'help' AND h.id = t.biz_id " +
                        "LEFT JOIN volunteer_activity a ON t.biz_type = 'activity' AND a.id = t.biz_id " +
                        "ORDER BY t.last_id DESC", p);
    }
}
