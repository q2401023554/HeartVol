package cn.heartgun.guanggu.controller;

import cn.heartgun.guanggu.common.AuthInterceptor;
import cn.heartgun.guanggu.common.Result;
import cn.heartgun.guanggu.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class AuthController {
    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    public record RegisterBody(String studentNo, String password, String name,
                               String college, String major) {
    }

    public record LoginBody(String studentNo, String password) {
    }

    @PostMapping("/auth/register")
    public Result<Map<String, Object>> register(@RequestBody RegisterBody body) {
        return Result.ok(authService.register(body.studentNo(), body.password(),
                body.name(), body.college(), body.major()));
    }

    @PostMapping("/auth/login")
    public Result<Map<String, Object>> login(@RequestBody LoginBody body) {
        return Result.ok(authService.login(body.studentNo(), body.password()));
    }

    @GetMapping("/user/me")
    public Result<Map<String, Object>> me(HttpServletRequest request) {
        long uid = (long) request.getAttribute(AuthInterceptor.ATTR_UID);
        return Result.ok(authService.me(uid));
    }
}
