package cn.heartgun.guanggu.repo;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@Repository
public class UserRepo {
    private final NamedParameterJdbcTemplate jdbc;

    public UserRepo(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<UserRow> findById(long id) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT " + UserRow.COLUMNS + " FROM sys_user WHERE id = :id",
                new MapSqlParameterSource("id", id));
        return rows.isEmpty() ? Optional.empty() : Optional.of(UserRow.from(rows.get(0)));
    }

    public Optional<UserRow> findByStudentNo(String studentNo) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT " + UserRow.COLUMNS + " FROM sys_user WHERE student_no = :s",
                new MapSqlParameterSource("s", studentNo));
        return rows.isEmpty() ? Optional.empty() : Optional.of(UserRow.from(rows.get(0)));
    }

    public long insert(String studentNo, String name, String phone, String passwordHash,
                       String college, String major) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("studentNo", studentNo)
                .addValue("name", name)
                .addValue("phone", phone)
                .addValue("password", passwordHash)
                .addValue("college", college)
                .addValue("major", major)
                .addValue("lat", 30.5123)
                .addValue("lng", 114.4315);
        jdbc.update("INSERT INTO sys_user (student_no, name, phone, password, college, major, skill_tags, avatar, " +
                        "credit_score, point, total_hours, lat, lng) VALUES " +
                        "(:studentNo, :name, :phone, :password, :college, :major, '', '', 90, 100, 0.0, :lat, :lng)",
                p);
        return jdbc.queryForObject("SELECT LAST_INSERT_ID()", p, Long.class);
    }

    /** 资料修改（设置页）：姓名 / 电话 / 学院（学号不可改） */
    public void updateProfile(long id, String name, String phone, String college) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("name", name)
                .addValue("phone", phone)
                .addValue("college", college);
        jdbc.update("UPDATE sys_user SET name = :name, phone = :phone, college = :college WHERE id = :id", p);
    }
}
