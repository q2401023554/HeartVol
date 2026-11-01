import { User } from './User';

/**
 * HelpOrder —— 互助接单（对应表 help_order）
 * 一个求助最多一个有效订单（一对一），避免多人重复接单的并发问题。
 */
export class HelpOrder {
  id: number = 0;
  requestId: number = 0;
  /** 接单人 */
  helperId: number = 0;
  /** HelpOrderStatus 的码值：ongoing/wait_confirm/finished */
  status: string = '';
  acceptTime: string = '';
  finishTime: string = '';

  // ---- 按需返回 ----
  /** 接单人信息（详情页展示「已接单 · 张三」） */
  helper: User | null = null;
  /** 求助标题（「我的接单」列表展示用） */
  requestTitle: string = '';

  static fromJson(json: HelpOrder): HelpOrder {
    const item: HelpOrder = new HelpOrder();
    item.id = json.id ?? 0;
    item.requestId = json.requestId ?? 0;
    item.helperId = json.helperId ?? 0;
    item.status = json.status ?? '';
    item.acceptTime = json.acceptTime ?? '';
    item.finishTime = json.finishTime ?? '';
    item.requestTitle = json.requestTitle ?? '';

    const h: User | null = json.helper;
    if (h) {
      item.helper = User.fromJson(h);
    }
    return item;
  }

  static fromJsonList(list: HelpOrder[]): HelpOrder[] {
    const out: HelpOrder[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(HelpOrder.fromJson(list[i]));
    }
    return out;
  }
}
