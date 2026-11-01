package cn.heartgun.guanggu.common;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/** 时间统一出口：JDBC 的 DATETIME 是 LocalDateTime（toString 带 T 且省零秒），
 *  App 端 DateFmt 按 "yyyy-MM-dd HH:mm:ss" 字符串切片 —— 所有时间出接口前必须过 normTime。 */
public class Times {
    public static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private Times() {
    }

    public static String normTime(Object o) {
        if (o instanceof LocalDateTime) {
            return ((LocalDateTime) o).format(FMT);
        }
        if (o instanceof java.sql.Timestamp) {
            return ((java.sql.Timestamp) o).toLocalDateTime().format(FMT);
        }
        return o == null ? "" : o.toString();
    }

    public static String now() {
        return LocalDateTime.now().format(FMT);
    }
}
