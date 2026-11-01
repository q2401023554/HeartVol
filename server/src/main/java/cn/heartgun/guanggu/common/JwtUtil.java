package cn.heartgun.guanggu.common;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

/**
 * 轻量 token：不引完整 JWT 库，HMAC-SHA256 签名的 "payload.sig"。
 * payload = base64url(json{"uid":..,"exp":..})，sig = base64url(HMAC(payload, secret))
 *
 * 安全约定：secret 只从配置注入（JWT_SECRET 环境变量），严禁写死进代码；
 * exp 7 天，过期即 401。
 */
public class JwtUtil {
    private static String secret = "";

    public static void init(String secretFromConfig) {
        secret = secretFromConfig;
    }

    public static String issue(long userId, long nowEpochSecond, long ttlSeconds) {
        long exp = nowEpochSecond + ttlSeconds;
        String payload = "{\"uid\":" + userId + ",\"exp\":" + exp + "}";
        String p = base64Url(payload.getBytes(StandardCharsets.UTF_8));
        return p + "." + hmac(p);
    }

    /** 校验通过返回 uid；失败抛 ApiException(401) */
    public static long verify(String token, long nowEpochSecond) {
        if (token == null || token.isBlank()) {
            throw new ApiException(401, "未登录或登录已过期");
        }
        int dot = token.lastIndexOf('.');
        if (dot <= 0) {
            throw new ApiException(401, "登录凭证无效");
        }
        String p = token.substring(0, dot);
        String sig = token.substring(dot + 1);
        if (!constantTimeEquals(hmac(p), sig)) {
            throw new ApiException(401, "登录凭证无效");
        }
        String json = new String(Base64.getUrlDecoder().decode(p), StandardCharsets.UTF_8);
        long uid = extractLong(json, "uid");
        long exp = extractLong(json, "exp");
        if (nowEpochSecond >= exp) {
            throw new ApiException(401, "登录已过期，请重新登录");
        }
        return uid;
    }

    private static long extractLong(String json, String key) {
        java.util.regex.Matcher m = java.util.regex.Pattern
                .compile("\"" + key + "\":(\\d+)").matcher(json);
        if (!m.find()) {
            throw new ApiException(401, "登录凭证无效");
        }
        return Long.parseLong(m.group(1));
    }

    private static String hmac(String data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return base64Url(mac.doFinal(data.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("hmac init failed", e);
        }
    }

    private static String base64Url(byte[] bytes) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private static boolean constantTimeEquals(String a, String b) {
        return java.security.MessageDigest.isEqual(a.getBytes(StandardCharsets.UTF_8), b.getBytes(StandardCharsets.UTF_8));
    }
}
