package cn.heartgun.guanggu.service;

import cn.heartgun.guanggu.common.ApiException;
import cn.heartgun.guanggu.common.Times;
import cn.heartgun.guanggu.repo.ActivityRepo;
import cn.heartgun.guanggu.repo.AgentRepo;
import cn.heartgun.guanggu.repo.HelpRepo;
import cn.heartgun.guanggu.repo.MyRecordsRepo;
import cn.heartgun.guanggu.repo.UserRepo;
import cn.heartgun.guanggu.repo.UserRow;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 志愿小鸿（G2）：Function Calling 版。
 * 小鸿可自主调用三个只读工具：查我的报名 / 查活动列表 / 查我的资料，
 * 由服务端执行后把结果喂回大模型，再生成最终回答——「能查、能说、说的是真数据」。
 * 多轮上下文存 chat_message（session_id = uid）；tool 中间轮不落库，只落 user/assistant。
 */
@Service
public class AgentService {
    private static final String DS_URL = "https://api.deepseek.com/chat/completions";
    private static final String DS_MODEL = "deepseek-chat";
    private static final int MAX_TOOL_ROUNDS = 3;

    private final AgentRepo agentRepo;
    private final UserRepo userRepo;
    private final MyRecordsRepo myRecordsRepo;
    private final ActivityService activityService;

    public AgentService(AgentRepo agentRepo, UserRepo userRepo,
                        MyRecordsRepo myRecordsRepo, ActivityService activityService) {
        this.agentRepo = agentRepo;
        this.userRepo = userRepo;
        this.myRecordsRepo = myRecordsRepo;
        this.activityService = activityService;
    }

    public Map<String, Object> chat(long uid, String message) {
        String text = message == null ? "" : message.trim();
        if (text.isEmpty()) {
            throw new ApiException(400, "消息内容不能为空");
        }
        if (text.length() > 500) {
            throw new ApiException(400, "消息过长（最多 500 字）");
        }
        agentRepo.insert(uid, "user", text);

        List<Map<String, String>> messages = buildMessages(uid);
        String reply = "";
        try {
            reply = runConversation(uid, messages);
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            throw new ApiException(502, "小鸿开小差了，请稍后再试");
        }
        agentRepo.insert(uid, "assistant", reply);
        Map<String, Object> out = new HashMap<>();
        out.put("reply", reply);
        return out;
    }

    public List<Map<String, Object>> history(long uid) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : agentRepo.history(uid)) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", ((Number) row.get("id")).longValue());
            item.put("sessionId", String.valueOf(uid));
            item.put("userId", uid);
            item.put("role", str(row.get("role")));
            item.put("content", str(row.get("content")));
            item.put("createTime", Times.normTime(row.get("create_time")));
            out.add(item);
        }
        return out;
    }

    public void clear(long uid) {
        agentRepo.clear(uid);
    }

    // ==================== Function Calling 主循环 ====================

    /** 带工具的对话循环：模型要工具就执行并回喂，最多 3 轮；否则取文本回复 */
    private String runConversation(long uid, List<Map<String, String>> messages) throws Exception {
        ObjectMapper om = new ObjectMapper();
        for (int round = 0; round < MAX_TOOL_ROUNDS; round++) {
            JsonNode choice = callDeepseek(messages, true);
            JsonNode msg = choice.path("message");
            JsonNode toolCalls = msg.path("tool_calls");
            if (toolCalls.isMissingNode() || !toolCalls.isArray() || toolCalls.isEmpty()) {
                return msg.path("content").asText("");
            }
            // 记录 assistant 的 tool_calls 消息（原样回传给下一轮）
            Map<String, String> assistantMsg = new HashMap<>();
            assistantMsg.put("role", "assistant");
            assistantMsg.put("content", msg.path("content").asText(""));
            assistantMsg.put("tool_calls_json", toolCalls.toString());
            messages.add(assistantMsg);

            for (JsonNode tc : toolCalls) {
                String callId = tc.path("id").asText("");
                String fnName = tc.path("function").path("name").asText("");
                String fnArgs = tc.path("function").path("arguments").asText("{}");
                String result;
                try {
                    result = dispatchTool(uid, fnName, fnArgs);
                } catch (Exception e) {
                    result = "工具执行失败：" + (e.getMessage() == null ? "未知错误" : e.getMessage());
                }
                Map<String, String> toolMsg = new HashMap<>();
                toolMsg.put("role", "tool");
                toolMsg.put("tool_call_id", callId);
                toolMsg.put("content", result);
                messages.add(toolMsg);
            }
        }
        return "这个问题有点复杂，小鸿暂时没整理好，换个问法试试？";
    }

    /** 工具分发：全部只读，按 uid 隔离数据 */
    private String dispatchTool(long uid, String name, String argsJson) throws Exception {
        ObjectMapper om = new ObjectMapper();
        JsonNode args = om.readTree(argsJson == null || argsJson.isBlank() ? "{}" : argsJson);
        switch (name) {
            case "get_my_activities":
                return toolMyActivities(uid, args.path("status_filter").asText(""));
            case "list_activities":
                return toolListActivities(uid, args.path("keyword").asText(""));
            case "get_my_profile":
                return toolMyProfile(uid);
            default:
                return "未知工具：" + name;
        }
    }

    /** 我的报名（可按状态过滤） */
    private String toolMyActivities(long uid, String statusFilter) {
        List<Map<String, Object>> rows = myRecordsRepo.mySignups(uid);
        if (rows.isEmpty()) {
            return "该用户当前没有任何报名记录。";
        }
        StringBuilder sb = new StringBuilder();
        int n = 0;
        for (Map<String, Object> row : rows) {
            String status = str(row.get("signup_status"));
            if (statusFilter != null && !statusFilter.isBlank() && !statusFilter.equals(status)) {
                continue;
            }
            n++;
            sb.append(n).append(". ").append(str(row.get("title")))
                    .append("｜状态：").append(status)
                    .append("｜开始：").append(Times.normTime(row.get("start_time")))
                    .append("｜时长：").append(num(row.get("service_hours"))).append(" 小时\n");
            if (n >= 8) {
                sb.append("（仅显示最近 8 条）");
                break;
            }
        }
        return n == 0 ? "没有符合该状态的报名。" : sb.toString().trim();
    }

    /** 活动列表（可按关键词过滤，默认 5 场）；list 需要合法 uid 计算报名态 */
    private String toolListActivities(long uid, String keyword) {
        Map<String, Object> page = activityService.list(uid, "", keyword == null ? "" : keyword, "time", 1, 5);
        Object listObj = page.get("list");
        List<?> list = listObj instanceof List ? (List<?>) listObj : List.of();
        if (list.isEmpty()) {
            return "没有匹配的活动。";
        }
        StringBuilder sb = new StringBuilder();
        int n = 0;
        for (Object o : list) {
            @SuppressWarnings("unchecked")
            Map<String, Object> a = (Map<String, Object>) o;
            n++;
            sb.append(n).append(". ").append(str(a.get("title")))
                    .append("｜开始：").append(str(a.get("startTime")))
                    .append("｜地点：").append(str(a.get("address")))
                    .append("｜时长：").append(num(a.get("serviceHours"))).append(" 小时")
                    .append("｜已报名 ").append(num(a.get("joinedCount"))).append(" 人\n");
        }
        sb.append("以上是活动列表的搜索结果。");
        return sb.toString().trim();
    }

    /** 我的资料摘要 */
    private String toolMyProfile(long uid) {
        UserRow me = userRepo.findById(uid).orElse(null);
        if (me == null) {
            return "用户不存在。";
        }
        return "姓名：" + me.name() + "；累计志愿时长 " + me.totalHours() + " 小时；公益积分 "
                + me.point() + "；志愿信用分 " + me.creditScore() + "；学院 " + me.college() + "。";
    }

    // ==================== DeepSeek 调用 ====================

    private JsonNode callDeepseek(List<Map<String, String>> messages, boolean withTools) throws Exception {
        String key = System.getenv("DEEPSEEK_KEY");
        if (key == null || key.isBlank()) {
            throw new ApiException(500, "小鸿还没有配置好（缺 DEEPSEEK_KEY）");
        }
        ObjectMapper om = new ObjectMapper();
        ObjectNode root = om.createObjectNode();
        root.put("model", DS_MODEL);
        root.put("max_tokens", 600);
        root.put("temperature", 0.8);
        if (withTools) {
            root.set("tools", om.readTree(TOOLS_JSON));
        }
        ArrayNode arr = om.createArrayNode();
        for (Map<String, String> m : messages) {
            ObjectNode n = arr.addObject();
            n.put("role", m.get("role"));
            n.put("content", m.get("content"));
            if (m.containsKey("tool_calls_json")) {
                // assistant 的 tool_calls 需按原结构回传
                JsonNode tcs = om.readTree(m.get("tool_calls_json"));
                n.set("tool_calls", tcs);
                if (n.path("content").asText("").isEmpty()) {
                    n.putNull("content");
                }
            }
            if ("tool".equals(m.get("role"))) {
                n.put("tool_call_id", m.get("tool_call_id"));
            }
        }
        root.set("messages", arr);

        HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
        HttpRequest req = HttpRequest.newBuilder(URI.create(DS_URL))
                .timeout(Duration.ofSeconds(60))
                .header("Authorization", "Bearer " + key)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(om.writeValueAsString(root)))
                .build();
        HttpResponse<String> resp = client.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() != 200) {
            throw new ApiException(502, "小鸿开小差了，请稍后再试");
        }
        JsonNode node = om.readTree(resp.body());
        JsonNode choices = node.path("choices");
        if (!choices.isArray() || choices.isEmpty()) {
            throw new ApiException(502, "小鸿开小差了，请稍后再试");
        }
        return choices.get(0);
    }

    private List<Map<String, String>> buildMessages(long uid) {
        List<Map<String, String>> messages = new ArrayList<>();
        messages.add(Map.of("role", "system", "content", systemPrompt(uid)));
        for (Map<String, Object> row : agentRepo.history(uid)) {
            messages.add(Map.of("role", str(row.get("role")), "content", str(row.get("content"))));
        }
        return messages;
    }

    private String systemPrompt(long uid) {
        UserRow me = userRepo.findById(uid).orElse(null);
        String name = me == null ? "同学" : me.name();
        double totalHours = me == null ? 0 : me.totalHours();
        int point = me == null ? 0 : me.point();
        int credit = me == null ? 90 : me.creditScore();
        return "你是「志愿小鸿」，校园志愿服务平台「鸿志愿」的 AI 助手，名字叫小鸿。"
                + "用简洁友好的中文回答，通常不超过 120 字；话题聚焦志愿服务、活动报名、"
                + "扫码签到、互助求助。平台功能：浏览/报名/发布志愿活动、扫码签到、定位签到、"
                + "互助大厅（发布和接单求助）、消息中心、个人资料。"
                + "当前用户：" + name + "，累计志愿时长 " + totalHours + " 小时，公益积分 "
                + point + "，志愿信用分 " + credit + "。"
                + "你拥有工具可以查询该用户的报名记录、平台活动列表和个人资料——"
                + "凡是涉及「我的报名/今天的安排/有哪些活动/推荐活动」等问题，必须先调用工具查询再回答，"
                + "禁止凭空编造活动信息。";
    }

    /** 工具定义（DeepSeek Function Calling 格式） */
    private static final String TOOLS_JSON = """
            [
              {
                "type": "function",
                "function": {
                  "name": "get_my_activities",
                  "description": "查询当前用户的所有志愿活动报名记录及签到状态（待签到/已签到/已完成）",
                  "parameters": {
                    "type": "object",
                    "properties": {
                      "status_filter": {
                        "type": "string",
                        "description": "可选，按状态过滤：signed_up=待签到, checked_in=已签到, completed=已完成；留空返回全部"
                      }
                    }
                  }
                }
              },
              {
                "type": "function",
                "function": {
                  "name": "list_activities",
                  "description": "查询平台上的志愿活动列表（可按关键词过滤），用于推荐或查找活动",
                  "parameters": {
                    "type": "object",
                    "properties": {
                      "keyword": {
                        "type": "string",
                        "description": "可选，按活动标题关键词过滤，如：义诊、马拉松、周末"
                      }
                    }
                  }
                }
              },
              {
                "type": "function",
                "function": {
                  "name": "get_my_profile",
                  "description": "查询当前用户的资料摘要（姓名、累计志愿时长、公益积分、信用分、学院）",
                  "parameters": {
                    "type": "object",
                    "properties": {}
                  }
                }
              }
            ]""";

    private static double num(Object o) {
        return o == null ? 0 : ((Number) o).doubleValue();
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }
}
