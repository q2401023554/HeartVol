package cn.heartgun.guanggu.controller;

import cn.heartgun.guanggu.common.Result;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {

    /** 健康检查：C2 的公网验收口，也是 App 侧网络连通性探测点 */
    @GetMapping("/api/health")
    public Result<String> health() {
        return Result.ok("guanggu");
    }
}
