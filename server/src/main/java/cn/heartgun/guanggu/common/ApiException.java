package cn.heartgun.guanggu.common;

/** 业务异常：message 直接透出给前端展示 */
public class ApiException extends RuntimeException {
    private final int code;

    public ApiException(int code, String message) {
        super(message);
        this.code = code;
    }

    public ApiException(String message) {
        this(500, message);
    }

    public int getCode() {
        return code;
    }
}
