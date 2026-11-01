package cn.heartgun.guanggu.repo;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

/** 消息中心读侧（B7）：写入已在 B4/B5/B6 的业务事务里完成 */
@Repository
public class MessageRepo {
    private final NamedParameterJdbcTemplate jdbc;

    public MessageRepo(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Map<String, Object>> list(long uid, String type, int offset, int size) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("u", uid).addValue("offset", offset).addValue("size", size);
        String where = type == null || type.isBlank() ? "" : " AND type = :type";
        if (type != null && !type.isBlank()) {
            p.addValue("type", type);
        }
        return jdbc.queryForList("SELECT id, type, related_id, title, content, is_read, create_time " +
                        "FROM message WHERE user_id = :u" + where +
                        " ORDER BY create_time DESC LIMIT :size OFFSET :offset", p);
    }

    public int count(long uid, String type) {
        MapSqlParameterSource p = new MapSqlParameterSource("u", uid);
        String where = "";
        if (type != null && !type.isBlank()) {
            where = " AND type = :type";
            p.addValue("type", type);
        }
        return jdbc.queryForObject("SELECT COUNT(*) FROM message WHERE user_id = :u" + where,
                p, Integer.class);
    }

    /** 各类型未读数：App 消息中心四 Tab 角标的数据源 */
    public Map<String, Object> unreadByType(long uid) {
        return jdbc.queryForMap(
                "SELECT " +
                        "SUM(CASE WHEN type='notice'   AND is_read=0 THEN 1 ELSE 0 END) AS notice, " +
                        "SUM(CASE WHEN type='interact' AND is_read=0 THEN 1 ELSE 0 END) AS interact, " +
                        "SUM(CASE WHEN type='activity' AND is_read=0 THEN 1 ELSE 0 END) AS activity, " +
                        "SUM(CASE WHEN type='help'     AND is_read=0 THEN 1 ELSE 0 END) AS help, " +
                        "SUM(CASE WHEN is_read=0 THEN 1 ELSE 0 END) AS total " +
                        "FROM message WHERE user_id = :u",
                new MapSqlParameterSource("u", uid));
    }

    /** 全部已读（可按类型）：返回影响行数 */
    public int markAllRead(long uid, String type) {
        MapSqlParameterSource p = new MapSqlParameterSource("u", uid);
        String where = "";
        if (type != null && !type.isBlank()) {
            where = " AND type = :type";
            p.addValue("type", type);
        }
        return jdbc.update("UPDATE message SET is_read = 1 WHERE user_id = :u AND is_read = 0" + where, p);
    }

    public int markRead(long uid, long messageId) {
        return jdbc.update("UPDATE message SET is_read = 1 WHERE user_id = :u AND id = :m",
                new MapSqlParameterSource().addValue("u", uid).addValue("m", messageId));
    }
}
