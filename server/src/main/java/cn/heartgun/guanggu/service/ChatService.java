package cn.heartgun.guanggu.service;

import cn.heartgun.guanggu.common.ApiException;
import cn.heartgun.guanggu.common.Times;
import cn.heartgun.guanggu.repo.ChatRepo;
import cn.heartgun.guanggu.repo.HelpRepo;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 互助/活动沟通（简化版 IM）：会话键 = (biz_type, biz_id)。
 *   help     → 双方 = 发布者↔接单者（未接单时发布者无对话对象）
 *   activity → 任意登录用户 ↔ 活动发布者（咨询场景）
 * 每发一条消息给对方写一条对应类型的通知，消息中心有角标可感知。
 */
@Service
public class ChatService {
    private final ChatRepo chatRepo;
    private final HelpRepo helpRepo;

    public ChatService(ChatRepo chatRepo, HelpRepo helpRepo) {
        this.chatRepo = chatRepo;
        this.helpRepo = helpRepo;
    }

    /** 发消息：按业务类型校验资格 + 对方存在。peerUid：发布者回复咨询时指定的对端（从会话列表带入） */
    public Map<String, Object> send(long uid, String bizType, long bizId, String content, long peerUid) {
        String text = content == null ? "" : content.trim();
        if (text.isEmpty()) {
            throw new ApiException(400, "消息内容不能为空");
        }
        if (text.length() > 500) {
            throw new ApiException(400, "消息过长（最多 500 字）");
        }
        long peer = peerOf(bizType, uid, bizId, peerUid);
        long id = chatRepo.insert(bizType, bizId, uid, peer, text);
        // 通知标题带发送者名 + from_uid 存发送者 —— 接收者点通知可直达会话
        helpRepo.insertMessage(peer, "help".equals(bizType) ? "help" : "activity",
                bizId, chatRepo.userName(uid) + " 发来消息", preview(text), uid);
        Map<String, Object> out = new HashMap<>();
        out.put("id", id);
        return out;
    }

    /** 增量拉取（拉取即已读）；fromMine/read 由服务端按当前用户算好，前端直接用 */
    public Map<String, Object> messages(long uid, String bizType, long bizId, long peerUid, long afterId) {
        long peer = peerOf(bizType, uid, bizId, peerUid); // 无资格直接抛错
        List<Map<String, Object>> rows = chatRepo.listAfter(bizType, bizId, uid, peer, afterId);
        chatRepo.markIncomingRead(bizType, bizId, uid, peer);
        List<Map<String, Object>> items = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            Map<String, Object> item = new HashMap<>();
            boolean fromMine = ((Number) row.get("from_uid")).longValue() == uid;
            item.put("id", ((Number) row.get("id")).longValue());
            item.put("fromMine", fromMine);
            item.put("content", str(row.get("content")));
            // 已读回执：我发的消息，对方（收件人）是否已看过
            item.put("read", fromMine && ((Number) row.get("is_read")).intValue() == 1);
            item.put("createTime", Times.normTime(row.get("create_time")));
            items.add(item);
        }
        Map<String, Object> out = new HashMap<>();
        out.put("list", items);
        out.put("peerName", chatRepo.userName(peer));
        return out;
    }

    /** 我的会话列表（消息中心「互助沟通」入口；含求助与活动两类会话） */
    public List<Map<String, Object>> myConversations(long uid) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : chatRepo.myConversations(uid)) {
            Map<String, Object> item = new HashMap<>();
            item.put("bizType", str(row.get("biz_type")));
            item.put("bizId", ((Number) row.get("biz_id")).longValue());
            // peerId：发布者回复咨询时要指定对端（同一活动可能有多个咨询者）
            item.put("peerId", ((Number) row.get("peer_id")).longValue());
            item.put("peerName", str(row.get("peer_name")));
            item.put("bizTitle", str(row.get("biz_title")));
            item.put("unread", ((Number) row.get("unread")).intValue());
            item.put("lastContent", str(row.get("last_content")));
            item.put("lastTime", Times.normTime(row.get("last_time")));
            out.add(item);
        }
        return out;
    }

    /**
     * 对方是谁 + 资格校验。
     * activity 域是「多咨询者 ↔ 发布者」的一对多：发布者进入时必须由调用方
     * 指定 peerUid（会话列表/通知里带过来），否则无法定位是和谁聊。
     */
    private long peerOf(String bizType, long uid, long bizId, long peerUid) {
        if ("activity".equals(bizType)) {
            Map<String, Object> info = chatRepo.activityPeerInfo(bizId)
                    .orElseThrow(() -> new ApiException(404, "活动不存在"));
            long pub = ((Number) info.get("pub")).longValue();
            if (uid == pub) {
                // 发布者：与该活动下指定咨询者的会话（不再一刀切 400）
                if (peerUid <= 0) {
                    throw new ApiException(400, "请从会话列表选择要回复的咨询");
                }
                return peerUid;
            }
            return pub;
        }
        if ("help".equals(bizType)) {
            Map<String, Object> info = chatRepo.helpPeerInfo(bizId)
                    .orElseThrow(() -> new ApiException(404, "求助不存在"));
            long pub = ((Number) info.get("pub")).longValue();
            Object helperObj = info.get("helper");
            long helper = helperObj == null ? 0 : ((Number) helperObj).longValue();
            if (uid == pub) {
                if (helper == 0) {
                    throw new ApiException(400, "对方接单后方可沟通");
                }
                return helper;
            }
            if (helper != 0 && uid == helper) {
                return pub;
            }
            throw new ApiException(403, "仅求助双方可以沟通");
        }
        throw new ApiException(400, "未知的会话类型");
    }

    private static String preview(String text) {
        return text.length() > 40 ? text.substring(0, 40) + "…" : text;
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }
}
