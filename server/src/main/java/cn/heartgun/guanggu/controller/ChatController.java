package cn.heartgun.guanggu.controller;

import cn.heartgun.guanggu.common.Result;
import cn.heartgun.guanggu.service.ChatService;
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

/**
 * 互助/活动沟通（简化版 IM）：会话列表 / 增量拉取 / 发送，前端 2 秒轮询。
 * 路径泛化：{bizType} = help（发布者↔接单者）| activity（用户↔活动发布者）。
 */
@RestController
@RequestMapping("/api/chat")
public class ChatController {
    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    public record SendBody(String content, Long peerUid) {
    }

    /** 我的会话列表（消息中心入口，含求助与活动两类会话） */
    @GetMapping("/list")
    public Result<List<Map<String, Object>>> list(HttpServletRequest request) {
        long uid = (long) request.getAttribute("uid");
        return Result.ok(chatService.myConversations(uid));
    }

    /** 增量拉取：?afterId=0 全量；?peerUid= 对端（发布者回复活动咨询时必传，其余场景忽略） */
    @GetMapping("/{bizType}/{bizId}/messages")
    public Result<Map<String, Object>> messages(HttpServletRequest request,
                                                @PathVariable String bizType,
                                                @PathVariable long bizId,
                                                @RequestParam(required = false, defaultValue = "0") long afterId,
                                                @RequestParam(required = false, defaultValue = "0") long peerUid) {
        long uid = (long) request.getAttribute("uid");
        return Result.ok(chatService.messages(uid, bizType, bizId, peerUid, afterId));
    }

    /** 发送：body.peerUid 同上（发布者回复咨询必传） */
    @PostMapping("/{bizType}/{bizId}/send")
    public Result<Map<String, Object>> send(HttpServletRequest request,
                                            @PathVariable String bizType,
                                            @PathVariable long bizId,
                                            @RequestBody SendBody body) {
        long uid = (long) request.getAttribute("uid");
        long peerUid = body.peerUid() == null ? 0 : body.peerUid();
        return Result.ok(chatService.send(uid, bizType, bizId, body.content(), peerUid));
    }
}
