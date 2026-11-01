/**
 * ChatService —— 互助沟通（简化版 IM）唯一前端出口
 *
 * 【双轨】USE_MOCK 总闸已关，ApiReady.CHAT=true → 全真实（Mock 轨保留开关习惯，
 *   万一回退演示环境时聊天页提示即可，不真正造数据 —— 聊天造 Mock 意义不大）。
 * 【已读约定】拉取即已读（后端 markIncomingRead），无需单独的已读接口。
 */
import { ApiPath, ApiReady, USE_MOCK } from '../common/Constants';
import { HttpUtil } from '../common/HttpUtil';
import { Result } from '../model/Result';
import { ChatMsg, ChatConversation, ChatMsgPage, ChatSendReply } from '../model/ChatModels';

export class ChatService {
  private static useReal(): boolean {
    return !USE_MOCK || ApiReady.CHAT;
  }

  /** 我的会话列表（消息中心「互助沟通」入口用） */
  static async conversations(): Promise<ChatConversation[]> {
    if (!ChatService.useReal()) {
      return [];
    }
    try {
      const res: Result<ChatConversation[]> =
        await HttpUtil.getWithRetry<ChatConversation[]>(ApiPath.CHAT_CONVERSATIONS);
      if (!res.isOk() || res.data === null) {
        return [];
      }
      return ChatConversation.fromJsonList(res.data);
    } catch (err) {
      return [];
    }
  }

  /** 增量拉取消息（拉取即已读）；afterId=0 全量；返回带对方姓名 */
  static async messagesPage(bizType: string, bizId: number, peerUid: number, afterId: number): Promise<ChatMsgPage> {
    if (!ChatService.useReal()) {
      return new ChatMsgPage();
    }
    try {
      const res: Result<ChatMsgPage> =
        await HttpUtil.getWithRetry<ChatMsgPage>(ApiPath.chatMessages(bizType, bizId, peerUid, afterId));
      if (!res.isOk() || res.data === null) {
        return new ChatMsgPage();
      }
      return ChatMsgPage.fromJson(res.data as ChatMsgPage);
    } catch (err) {
      return new ChatMsgPage();
    }
  }

  /** 发送；成功返回该条消息的真实服务端 id（供本地追加，避免轮询重复） */
  static async send(bizType: string, bizId: number, content: string, peerUid: number): Promise<Result<ChatSendReply>> {
    if (!ChatService.useReal()) {
      return Result.fail<ChatSendReply>(400, '演示版暂不支持聊天');
    }
    const body: SendBody = new SendBody(content, peerUid);
    return HttpUtil.post<ChatSendReply>(ApiPath.chatSend(bizType, bizId), body);
  }
}

/** 🔴 ArkTS：请求体必须显式类 */
export class SendBody {
  content: string = '';
  /** 发布者回复活动咨询时指定对端；其余场景 0 */
  peerUid: number = 0;

  constructor(content: string, peerUid: number) {
    this.content = content;
    this.peerUid = peerUid;
  }
}
