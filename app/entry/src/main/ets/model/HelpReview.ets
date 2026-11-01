/**
 * HelpReview —— 双向互评（对应表 help_review）
 * 一次订单产生两条记录（A→B、B→A），共同影响双方 credit_score。
 */
export class HelpReview {
  id: number = 0;
  orderId: number = 0;
  fromUserId: number = 0;
  toUserId: number = 0;
  /** 1~5 星 */
  score: number = 5;
  content: string = '';
  createTime: string = '';

  /** 评价人昵称（详情页展示用） */
  fromUserName: string = '';

  static fromJson(json: HelpReview): HelpReview {
    const item: HelpReview = new HelpReview();
    item.id = json.id ?? 0;
    item.orderId = json.orderId ?? 0;
    item.fromUserId = json.fromUserId ?? 0;
    item.toUserId = json.toUserId ?? 0;
    item.score = json.score ?? 5;
    item.content = json.content ?? '';
    item.createTime = json.createTime ?? '';
    item.fromUserName = json.fromUserName ?? '';
    return item;
  }

  static fromJsonList(list: HelpReview[]): HelpReview[] {
    const out: HelpReview[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(HelpReview.fromJson(list[i]));
    }
    return out;
  }

  /** 我是否已对这条订单评过（UI 决定按钮显示「评价对方」还是「已评价」） */
  static hasReviewed(list: HelpReview[], fromUserId: number): boolean {
    for (let i = 0; i < list.length; i++) {
      if (list[i].fromUserId === fromUserId) {
        return true;
      }
    }
    return false;
  }
}
