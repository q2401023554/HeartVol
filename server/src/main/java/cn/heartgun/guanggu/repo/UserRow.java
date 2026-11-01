package cn.heartgun.guanggu.repo;

import java.util.HashMap;
import java.util.Map;

/** sys_user 行映射：password 仅登录校验用，对外序列化时剔除 */
public record UserRow(
        long id,
        String studentNo,
        String name,
        String phone,
        String password,
        String college,
        String major,
        String skillTags,
        String avatar,
        int creditScore,
        int point,
        double totalHours,
        double lat,
        double lng) {

    public static final String COLUMNS =
            "id, student_no, name, phone, password, college, major, skill_tags, avatar, " +
                    "credit_score, point, total_hours, lat, lng";

    public static UserRow from(Map<String, Object> row) {
        return new UserRow(
                ((Number) row.get("id")).longValue(),
                (String) row.get("student_no"),
                (String) row.get("name"),
                str(row.get("phone")),
                (String) row.get("password"),
                str(row.get("college")),
                str(row.get("major")),
                str(row.get("skill_tags")),
                str(row.get("avatar")),
                ((Number) row.get("credit_score")).intValue(),
                ((Number) row.get("point")).intValue(),
                ((Number) row.get("total_hours")).doubleValue(),
                ((Number) row.get("lat")).doubleValue(),
                ((Number) row.get("lng")).doubleValue());
    }

    /** 对外（JSON）形态：不带 password，totalHours 对齐 App 字段名 */
    public Map<String, Object> toPublic() {
        // Map.of 上限 10 对，13 个字段用 HashMap
        Map<String, Object> m = new HashMap<>();
        m.put("id", id);
        m.put("studentNo", studentNo);
        m.put("name", name);
        m.put("phone", phone);
        m.put("college", college);
        m.put("major", major);
        m.put("skillTags", skillTags);
        m.put("avatar", avatar);
        m.put("creditScore", creditScore);
        m.put("point", point);
        m.put("totalHours", totalHours);
        m.put("lat", lat);
        m.put("lng", lng);
        return m;
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }
}
