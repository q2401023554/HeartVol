/**
 * MessageItem —— 消息中心一条消息（对应表 message）
 *
 * 写入时机（后端 B7 负责）：报名成功 / 签到成功 / 有人接单 / 订单完成 / 收到评价 / 活动即将开始
 */
export class MessageItem {
  id: number = 0;
  userId: number = 0;
  /** MessageType 的码值：notice/interact/activity/help（决定消息中心分 Tab） */
  type: string = '';
  /** 关联业务 id：活动 id 或求助 id，点击跳转用 */
  relatedId: number = 0;
  /** 聊天通知的发送者 uid（点通知直达会话；系统通知 0） */
  fromUid: number = 0;
  title: string = '';
  content: string = '';
  isRead: boolean = false;
  createTime: string = '';

  static fromJson(json: MessageItem): MessageItem {
    const item: MessageItem = new MessageItem();
    item.id = json.id ?? 0;
    item.userId = json.userId ?? 0;
    item.type = json.type ?? '';
    item.relatedId = json.relatedId ?? 0;
    item.fromUid = json.fromUid ?? 0;
    item.title = json.title ?? '';
    item.content = json.content ?? '';
    item.isRead = json.isRead ?? false;
    item.createTime = json.createTime ?? '';
    return item;
  }

  static fromJsonList(list: MessageItem[]): MessageItem[] {
    const out: MessageItem[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(MessageItem.fromJson(list[i]));
    }
    return out;
  }

  /** 未读数（上层角标用） */
  static countUnread(list: MessageItem[]): number {
    let n: number = 0;
    for (let i = 0; i < list.length; i++) {
      if (!list[i].isRead) {
        n = n + 1;
      }
    }
    return n;
  }

  /** 按类型筛选（消息中心 Tab 切换用） */
  static filterByType(list: MessageItem[], type: string): MessageItem[] {
    const out: MessageItem[] = [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].type === type) {
        out.push(list[i]);
      }
    }
    return out;
  }
}

/** 消息列表分页响应（/api/user/messages 返回 {list, total, page}） */
export class MessagePage {
  list: MessageItem[] = [];
  total: number = 0;
  page: number = 0;
}

/** 四 Tab 未读角标（/api/user/messages/unread 返回） */
export class UnreadCount {
  notice: number = 0;
  interact: number = 0;
  activity: number = 0;
  help: number = 0;
  total: number = 0;
}
