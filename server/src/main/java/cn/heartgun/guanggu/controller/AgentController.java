package cn.heartgun.guanggu.controller;

import cn.heartgun.guanggu.common.Result;
import cn.heartgun.guanggu.service.AgentService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/** 志愿小鸿（G）：/api/agent/chat 对话（60s 级，走服务端代理 DeepSeek）/ history / clear */
@RestController
@RequestMapping("/api/agent")
public class AgentController {
    private final AgentService agentService;

    public AgentController(AgentService agentService) {
        this.agentService = agentService;
    }

    public record ChatBody(String message) {
    }

    /** 对话（多轮上下文在服务端；App 端用 60s 长超时调用） */
    @PostMapping("/chat")
    public Result<Map<String, Object>> chat(HttpServletRequest request, @RequestBody ChatBody body) {
        long uid = (long) request.getAttribute("uid");
        return Result.ok(agentService.chat(uid, body.message()));
    }

    /** 会话历史（时间正序） */
    @GetMapping("/history")
    public Result<List<Map<String, Object>>> history(HttpServletRequest request) {
        long uid = (long) request.getAttribute("uid");
        return Result.ok(agentService.history(uid));
    }

    /** 清空会话（小鸿页「重新开始」） */
    @PostMapping("/clear")
    public Result<Void> clear(HttpServletRequest request) {
        long uid = (long) request.getAttribute("uid");
        agentService.clear(uid);
        return Result.ok();
    }
}
