import { ApiPath, ApiReady, USE_MOCK } from '../common/Constants';
import { HttpUtil } from '../common/HttpUtil';
import { http } from '@kit.NetworkKit';
import { ChatMessage } from '../model/ChatMessage';
import { Result } from '../model/Result';
import { MockData } from '../model/MockData';

/** 🔴 ArkTS：请求体必须显式类（置顶声明，避免后置引用的类型解析怪错） */
export class AgentChatBody {
  message: string = '';

  constructor(message: string) {
    this.message = message;
  }
}

/** /api/agent/chat 响应：{ reply } */
export class AgentReplyData {
  reply: string = '';
}

/**
 * AgentService —— 志愿小鸿的数据入口（G 阶段已接真实 LLM）
 *
 * 【真实链路】POST /api/agent/chat：服务端代理调 DeepSeek（key 只在服务器），
 *   多轮上下文存 chat_message 表（session_id = uid，单用户单会话），
 *   system prompt 由服务端注入用户实时资料（时长/积分/信用分），回答个性化。
 * 【超时】LLM 生成 5~30s —— 对话请求用 60s 长超时（HttpUtil.request 第 4 参）。
 * 【结构化卡片】v1 暂不生成（cards 为空数组），页面渲染纯文本气泡。
 */
export class AgentService {

  /**
   * 会话历史（进入小鸿页时拉一次）。
   * 返回 null = 请求失败（页面显示错误态+重试）；空数组 = 会话为空（显示欢迎语）——
   * 两者语义不同，之前混在一起导致「新账号/清空会话」被误报成网络错误。
   */
  static async conversation(): Promise<ChatMessage[] | null> {
    if (USE_MOCK || !ApiReady.AGENT) {
      return MockData.agentConversation();
    }
    try {
      const res = await HttpUtil.getWithRetry<ChatMessage[]>(ApiPath.AGENT_HISTORY);
      if (!res.isOk() || res.data === null) {
        return null;
      }
      return ChatMessage.fromJsonList(res.data);
    } catch (err) {
      return null;
    }
  }

  /** 快捷提问芯片（本地固定引导语，降低后端复杂度） */
  static async prompts(): Promise<string[]> {
    if (USE_MOCK || !ApiReady.AGENT) {
      return MockData.agentPrompts();
    }
    return [
      '我今天有要签到的活动吗？',
      '帮我推荐一个周末的志愿活动',
      '我的志愿时长和信用分怎么样？',
      '怎么发布一条互助求助？'
    ];
  }

  /** 发一句话，拿一条回复（60s 长超时；失败返回本地兜底文案） */
  static async reply(text: string): Promise<ChatMessage> {
    if (USE_MOCK || !ApiReady.AGENT) {
      return MockData.agentReply(text);
    }
    const body: AgentChatBody = new AgentChatBody(text);
    try {
      const res: Result<AgentReplyData> = await HttpUtil.request<AgentReplyData>(
        ApiPath.AGENT_CHAT, http.RequestMethod.POST, body, 60000);
      if (res.isOk() && res.data !== null) {
        const data: AgentReplyData = res.data as AgentReplyData;
        return ChatMessage.localAssistantMessage(
          data.reply !== '' ? data.reply : '（小鸿没说话）', []);
      }
      return ChatMessage.localAssistantMessage(
        res.message !== '' ? '小鸿累了：' + res.message : '小鸿开小差了，请稍后再试', []);
    } catch (err) {
      return ChatMessage.localAssistantMessage('网络不太顺畅，请稍后再试', []);
    }
  }

  /** 清空会话（小鸿页「重新开始」按钮用；失败静默） */
  static async clear(): Promise<void> {
    if (USE_MOCK || !ApiReady.AGENT) {
      return;
    }
    try {
      await HttpUtil.post<object>(ApiPath.AGENT_CLEAR, null);
    } catch (err) {
      // 清历史失败不影响聊天
    }
  }
}
