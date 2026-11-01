package cn.heartgun.guanggu.config;

import com.fasterxml.jackson.datatype.jsr310.deser.LocalDateTimeDeserializer;
import com.fasterxml.jackson.datatype.jsr310.ser.LocalDateTimeSerializer;
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.format.DateTimeFormatter;

/**
 * 全局日期格式：yyyy-MM-dd HH:mm:ss（空格分隔，不带 T）。
 * App 端 DateFmt 是按这个格式做字符串切片解析的 —— ISO 的 "T" 分隔会让切出
 * "09-25T07" 这种坏数据。所有 LocalDateTime 出入口统一走这里。
 */
@Configuration
public class JacksonConfig {

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Bean
    public Jackson2ObjectMapperBuilderCustomizer localDateTimeFormat() {
        return builder -> {
            builder.serializers(new LocalDateTimeSerializer(FMT));
            builder.deserializers(new LocalDateTimeDeserializer(FMT));
        };
    }
}
