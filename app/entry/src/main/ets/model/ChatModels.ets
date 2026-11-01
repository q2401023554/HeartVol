/**
 * 互助沟通（简化版 IM）模型
 *
 * 🔴 ArkTS 约束：JSON.parse 的结果没有类方法 → 全部走 fromJson 逐字段赋值。
 * fromMine 由后端按当前 token 算好下发，前端无需再比对 uid。
 */
import { DateFmt } from '../common/DateFmt';

/** 一条聊天消息（气泡） */
export class ChatMsg {
  id: number = 0;
  /** 是否我发的（服务端算好） */
  fromMine: boolean = false;
  content: string = '';
  /** 已读回执：我发的消息对方是否已看过（服务端算好；非我发恒 false） */
  read: boolean = false;
  /** yyyy-MM-dd HH:mm:ss */
  createTime: string = '';

  static fromJson(json: ChatMsg): ChatMsg {
    const item: ChatMsg = new ChatMsg();
    item.id = json.id ?? 0;
    item.fromMine = json.fromMine ?? false;
    item.content = json.content ?? '';
    item.read = json.read ?? false;
    item.createTime = json.createTime ?? '';
    return item;
  }

  static fromJsonList(arr: ChatMsg[]): ChatMsg[] {
    const out: ChatMsg[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(ChatMsg.fromJson(arr[i]));
    }
    return out;
  }

  /** 气泡上方的时刻文案：'14:05'（同屏连续消息不重复展示的逻辑交给页面） */
  timeText(): string {
    return DateFmt.hm(this.createTime);
  }
}

/** 增量拉取的响应包装：后端返回 { list: [...] }（显式类，规避 Record） */
export class ChatMsgPage {
  list: ChatMsg[] = [];
  peerName: string = '';

  static fromJson(json: ChatMsgPage): ChatMsgPage {
    const item: ChatMsgPage = new ChatMsgPage();
    item.list = json.list === undefined ? [] : ChatMsg.fromJsonList(json.list);
    item.peerName = json.peerName ?? '';
    return item;
  }
}

/** 发送消息的响应包装：后端返回 { id }（该条消息的真实服务端 id） */
export class ChatSendReply {
  id: number = 0;

  static fromJson(json: ChatSendReply): ChatSendReply {
    const item: ChatSendReply = new ChatSendReply();
    item.id = json.id ?? 0;
    return item;
  }
}

/** 会话列表一行（消息中心「互助沟通」入口进来的列表；bizType = help | activity） */
export class ChatConversation {
  bizType: string = 'help';
  bizId: number = 0;
  /** 对端 uid（发布者回复活动咨询时要定位到人） */
  peerId: number = 0;
  peerName: string = '';
  bizTitle: string = '';
  unread: number = 0;
  lastContent: string = '';
  /** yyyy-MM-dd HH:mm:ss */
  lastTime: string = '';

  static fromJson(json: ChatConversation): ChatConversation {
    const item: ChatConversation = new ChatConversation();
    item.bizType = json.bizType ?? 'help';
    item.bizId = json.bizId ?? 0;
    item.peerId = json.peerId ?? 0;
    item.peerName = json.peerName ?? '';
    item.bizTitle = json.bizTitle ?? '';
    item.unread = json.unread ?? 0;
    item.lastContent = json.lastContent ?? '';
    item.lastTime = json.lastTime ?? '';
    return item;
  }

  static fromJsonList(arr: ChatConversation[]): ChatConversation[] {
    const out: ChatConversation[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(ChatConversation.fromJson(arr[i]));
    }
    return out;
  }
}
