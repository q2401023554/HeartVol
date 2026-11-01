package cn.heartgun.guanggu.repo;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

/**
 * 智能体会话持久化（G）：表 chat_message（B1 预留）。
 * session_id = uid（单用户单会话），role = user | assistant。
 */
@Repository
public class AgentRepo {
    private final NamedParameterJdbcTemplate jdbc;

    public AgentRepo(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** 该用户的会话历史（时间正序，最近 40 条作为 LLM 上下文窗口） */
    public List<Map<String, Object>> history(long uid) {
        return jdbc.queryForList(
                "SELECT id, role, content, create_time FROM chat_message " +
                        "WHERE user_id = :u AND session_id = :u AND role IN ('user','assistant') " +
                        "ORDER BY id ASC LIMIT 200",
                new MapSqlParameterSource("u", uid));
    }

    public void insert(long uid, String role, String content) {
        jdbc.update("INSERT INTO chat_message (session_id, user_id, role, content) " +
                        "VALUES (:s, :u, :r, :c)",
                new MapSqlParameterSource().addValue("s", uid).addValue("u", uid)
                        .addValue("r", role).addValue("c", content));
    }

    /** 清空会话（小鸿页「重新开始」） */
    public void clear(long uid) {
        jdbc.update("DELETE FROM chat_message WHERE user_id = :u AND session_id = :u",
                new MapSqlParameterSource("u", uid));
    }
}
