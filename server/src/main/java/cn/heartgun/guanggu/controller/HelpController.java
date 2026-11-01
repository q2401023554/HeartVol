package cn.heartgun.guanggu.controller;

import cn.heartgun.guanggu.common.AuthInterceptor;
import cn.heartgun.guanggu.common.Result;
import cn.heartgun.guanggu.service.HelpService;
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

/** 互助（B6）：列表 / 详情 / 发布 / 接单 / 完成确认 / 互评 */
@RestController
@RequestMapping("/api")
public class HelpController {
    private final HelpService helpService;

    public HelpController(HelpService helpService) {
        this.helpService = helpService;
    }

    @GetMapping("/helps")
    public Result<Map<String, Object>> list(HttpServletRequest request,
                                            @RequestParam(required = false) String category,
                                            @RequestParam(required = false) String keyword,
                                            @RequestParam(required = false, defaultValue = "time") String sort,
                                            @RequestParam(required = false, defaultValue = "1") int page,
                                            @RequestParam(required = false, defaultValue = "20") int size) {
        long uid = currentUid(request);
        return Result.ok(helpService.list(uid, category, keyword, sort, page, size));
    }

    /** 我发布的求助（发布者管理入口）；{list:[...]} 包装与列表接口对齐 */
    @GetMapping("/helps/mine")
    public Result<Map<String, Object>> myPublished(HttpServletRequest request) {
        long uid = currentUid(request);
        Map<String, Object> out = new java.util.HashMap<>();
        out.put("list", helpService.myPublished(uid));
        return Result.ok(out);
    }

    @GetMapping("/helps/{id}")
    public Result<Map<String, Object>> detail(HttpServletRequest request, @PathVariable long id) {
        long uid = currentUid(request);
        return Result.ok(helpService.detail(id, uid));
    }

    @PostMapping("/helps")
    public Result<Map<String, Object>> publish(HttpServletRequest request,
                                               @RequestBody Map<String, Object> body) {
        long uid = currentUid(request);
        return Result.ok(helpService.publish(uid, body));
    }

    @PostMapping("/helps/{id}/accept")
    public Result<Void> accept(HttpServletRequest request, @PathVariable long id) {
        long uid = currentUid(request);
        helpService.accept(id, uid);
        return Result.ok();
    }

    @PostMapping("/helps/{id}/finish")
    public Result<Map<String, Object>> finish(HttpServletRequest request, @PathVariable long id) {
        long uid = currentUid(request);
        return Result.ok(helpService.finish(id, uid));
    }

    /** 互评：body {score, content?}；orderId 是接单 id */
    @PostMapping("/helps/orders/{orderId}/review")
    public Result<Map<String, Object>> review(HttpServletRequest request, @PathVariable long orderId,
                                              @RequestBody Map<String, Object> body) {
        long uid = currentUid(request);
        int score = body.get("score") instanceof Number ? ((Number) body.get("score")).intValue() : 0;
        return Result.ok(helpService.review(orderId, uid, score,
                body.get("content") == null ? "" : body.get("content").toString()));
    }

    private static long currentUid(HttpServletRequest request) {
        return (long) request.getAttribute(AuthInterceptor.ATTR_UID);
    }
}
