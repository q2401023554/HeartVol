package cn.heartgun.guanggu.controller;

import cn.heartgun.guanggu.common.Result;
import cn.heartgun.guanggu.service.AuthService;
import cn.heartgun.guanggu.service.UserBizService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/** 「我的」域接口（B5）：我的报名 / 时长明细 */
@RestController
@RequestMapping("/api/user")
public class UserController {
    private final UserBizService userBizService;
    private final AuthService authService;

    public UserController(UserBizService userBizService, AuthService authService) {
        this.userBizService = userBizService;
        this.authService = authService;
    }

    /** 资料修改（设置页）：改完返回最新 me，前端一次拿到新资料 */
    public record ProfileBody(String name, String phone, String college) {
    }

    @PostMapping("/profile")
    public Result<Map<String, Object>> updateProfile(HttpServletRequest request,
                                                     @RequestBody ProfileBody body) {
        long uid = currentUid(request);
        userBizService.updateProfile(uid, body.name(), body.phone(), body.college());
        return Result.ok(authService.me(uid));
    }

    @GetMapping("/signups")
    public Result<List<Map<String, Object>>> mySignups(HttpServletRequest request) {
        long uid = currentUid(request);
        return Result.ok(userBizService.mySignups(uid));
    }

    @GetMapping("/hours")
    public Result<List<Map<String, Object>>> myHours(HttpServletRequest request) {
        long uid = currentUid(request);
        return Result.ok(userBizService.myHours(uid));
    }

    /** 电子证书（云同步）：资料+累计时长+完成场次+证书编号 */
    @GetMapping("/certificate")
    public Result<Map<String, Object>> certificate(HttpServletRequest request) {
        long uid = currentUid(request);
        return Result.ok(userBizService.certificate(uid));
    }

    // ==================== 消息中心（B7） ====================

    /** 消息列表：?type=notice|interact|activity|help（可空=全部）&page&size */
    @GetMapping("/messages")
    public Result<Map<String, Object>> messages(HttpServletRequest request,
                                                @RequestParam(required = false) String type,
                                                @RequestParam(required = false, defaultValue = "1") int page,
                                                @RequestParam(required = false, defaultValue = "20") int size) {
        long uid = currentUid(request);
        return Result.ok(userBizService.messages(uid, type, page, size));
    }

    /** 首页聚合（D3）：一次返回聚合数字 + 本周推荐 + 活动流 */
    @GetMapping("/home-summary")
    public Result<Map<String, Object>> homeSummary(HttpServletRequest request) {
        long uid = currentUid(request);
        return Result.ok(userBizService.homeSummary(uid));
    }

    /** 四 Tab 未读角标 + 总数 */
    @GetMapping("/messages/unread")
    public Result<Map<String, Object>> unread(HttpServletRequest request) {
        long uid = currentUid(request);
        return Result.ok(userBizService.unreadCounts(uid));
    }

    /** 全部已读：?type= 可选（只清某一 Tab） */
    @PostMapping("/messages/read-all")
    public Result<Map<String, Object>> readAll(HttpServletRequest request,
                                               @RequestParam(required = false) String type) {
        long uid = currentUid(request);
        int changed = userBizService.readAll(uid, type);
        return Result.ok(Map.of("marked", changed));
    }

    /** 单条已读 */
    @PostMapping("/messages/{id}/read")
    public Result<Void> readOne(HttpServletRequest request, @PathVariable long id) {
        long uid = currentUid(request);
        userBizService.readOne(uid, id);
        return Result.ok();
    }

    private static long currentUid(HttpServletRequest request) {
        return (long) request.getAttribute("uid");
    }
}
