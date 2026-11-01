package cn.heartgun.guanggu.service;

import cn.heartgun.guanggu.common.ApiException;
import cn.heartgun.guanggu.common.JwtUtil;
import cn.heartgun.guanggu.repo.UserRepo;
import cn.heartgun.guanggu.repo.UserRow;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

/** 认证：注册 / 登录 / me（B3） */
@Service
public class AuthService {
    private static final long TTL_SECONDS = 7L * 24 * 3600;

    private final UserRepo userRepo;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    public AuthService(UserRepo userRepo) {
        this.userRepo = userRepo;
    }

    /** 注册：学号唯一；新用户默认 100 积分 / 90 信用分（与 schema 默认一致） */
    public Map<String, Object> register(String studentNo, String password, String name,
                                        String college, String major) {
        if (blank(studentNo) || blank(password) || blank(name)) {
            throw new ApiException(400, "学号、姓名与密码不能为空");
        }
        if (password.length() < 6 || password.length() > 20) {
            throw new ApiException(400, "密码长度需为 6-20 位");
        }
        if (userRepo.findByStudentNo(studentNo).isPresent()) {
            throw new ApiException(400, "该学号已注册，请直接登录");
        }
        long id = userRepo.insert(studentNo, name, "", encoder.encode(password),
                college == null ? "" : college, major == null ? "" : major);
        UserRow user = userRepo.findById(id).orElseThrow();
        return tokenWithUser(user);
    }

    /** 登录：学号 + 密码（错误提示不区分「无此号/密码错」，防枚举） */
    public Map<String, Object> login(String studentNo, String password) {
        if (blank(studentNo) || blank(password)) {
            throw new ApiException(400, "请输入学号与密码");
        }
        UserRow user = userRepo.findByStudentNo(studentNo)
                .orElseThrow(() -> new ApiException(400, "学号或密码不正确"));
        if (!encoder.matches(password, user.password())) {
            throw new ApiException(400, "学号或密码不正确");
        }
        return tokenWithUser(user);
    }

    public Map<String, Object> me(long uid) {
        UserRow user = userRepo.findById(uid)
                .orElseThrow(() -> new ApiException(401, "用户不存在"));
        return user.toPublic();
    }

    private Map<String, Object> tokenWithUser(UserRow user) {
        String token = JwtUtil.issue(user.id(), System.currentTimeMillis() / 1000L, TTL_SECONDS);
        Map<String, Object> out = new HashMap<>();
        out.put("token", token);
        out.put("user", user.toPublic());
        return out;
    }

    private static boolean blank(String s) {
        return s == null || s.isBlank();
    }
}
