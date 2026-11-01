package cn.heartgun.guanggu.common;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * 登录拦截器：除放行名单外，所有 /api/** 必须带有效 token。
 * 校验通过后把 uid 放进 request attribute，控制器用 request.getAttribute("uid") 取。
 */
public class AuthInterceptor implements HandlerInterceptor {

    public static final String ATTR_UID = "uid";

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception {
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }
        String auth = request.getHeader("Authorization");
        String token = (auth != null && auth.startsWith("Bearer ")) ? auth.substring(7) : auth;
        try {
            long uid = JwtUtil.verify(token, System.currentTimeMillis() / 1000L);
            request.setAttribute(ATTR_UID, uid);
            return true;
        } catch (ApiException e) {
            response.setStatus(401);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write(
                    "{\"code\":401,\"message\":\"" + e.getMessage() + "\",\"data\":null}");
            return false;
        }
    }
}
