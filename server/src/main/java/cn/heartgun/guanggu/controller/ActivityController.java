package cn.heartgun.guanggu.controller;

import cn.heartgun.guanggu.common.AuthInterceptor;
import cn.heartgun.guanggu.common.Result;
import cn.heartgun.guanggu.service.ActivityService;
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

/** 志愿活动（B4）：列表 / 详情 / 发布 / 报名 */
@RestController
@RequestMapping("/api")
public class ActivityController {
    private final ActivityService activityService;

    public ActivityController(ActivityService activityService) {
        this.activityService = activityService;
    }

    /** 列表：?category=env&keyword=东湖&sort=distance|time&page=1&size=20 */
    @GetMapping("/activities")
    public Result<Map<String, Object>> list(HttpServletRequest request,
                                            @RequestParam(required = false) String category,
                                            @RequestParam(required = false) String keyword,
                                            @RequestParam(required = false, defaultValue = "time") String sort,
                                            @RequestParam(required = false, defaultValue = "1") int page,
                                            @RequestParam(required = false, defaultValue = "20") int size) {
        long uid = currentUid(request);
        return Result.ok(activityService.list(uid, category, keyword, sort, page, size));
    }

    /** 更新活动信息（仅发布者本人） */
    @PostMapping("/activities/{id}/update")
    public Result<Void> updateActivity(HttpServletRequest request, @PathVariable long id,
                                       @RequestBody Map<String, Object> body) {
        long uid = currentUid(request);
        activityService.update(id, uid, body);
        return Result.ok();
    }

    /** 删除活动（仅发布者本人；已入账的活动拒绝） */
    @PostMapping("/activities/{id}/delete")
    public Result<Void> deleteActivity(HttpServletRequest request, @PathVariable long id) {
        long uid = currentUid(request);
        activityService.delete(id, uid);
        return Result.ok();
    }

    /** 我发布的活动（字面量路由优先于 {id}，Spring 自动匹配）；{list:[...]} 包装与分页接口对齐 */
    @GetMapping("/activities/mine")
    public Result<Map<String, Object>> myPublished(HttpServletRequest request) {
        long uid = currentUid(request);
        Map<String, Object> out = new java.util.HashMap<>();
        out.put("list", activityService.myPublished(uid));
        return Result.ok(out);
    }

    @GetMapping("/activities/{id}")
    public Result<Map<String, Object>> detail(HttpServletRequest request, @PathVariable long id) {
        long uid = currentUid(request);
        return Result.ok(activityService.detail(id, uid));
    }

    @PostMapping("/activities")
    public Result<Map<String, Object>> publish(HttpServletRequest request,
                                               @RequestBody Map<String, Object> body) {
        long uid = currentUid(request);
        return Result.ok(activityService.publish(uid, body));
    }

    @PostMapping("/activities/{id}/signup")
    public Result<Void> signup(HttpServletRequest request, @PathVariable long id) {
        long uid = currentUid(request);
        activityService.signup(id, uid);
        return Result.ok();
    }

    /** 签到核销（B5）：body {code, signType?, lat?, lng?} */
    @PostMapping("/activities/{id}/signin")
    public Result<Map<String, Object>> signin(HttpServletRequest request, @PathVariable long id,
                                              @RequestBody Map<String, Object> body) {
        long uid = currentUid(request);
        String signType = body.get("signType") == null ? "manual" : body.get("signType").toString();
        double lat = body.get("lat") instanceof Number ? ((Number) body.get("lat")).doubleValue() : 0;
        double lng = body.get("lng") instanceof Number ? ((Number) body.get("lng")).doubleValue() : 0;
        return Result.ok(activityService.signin(uid, id,
                body.get("code") == null ? "" : body.get("code").toString(), signType, lat, lng));
    }

    private static long currentUid(HttpServletRequest request) {
        return (long) request.getAttribute(AuthInterceptor.ATTR_UID);
    }
}
