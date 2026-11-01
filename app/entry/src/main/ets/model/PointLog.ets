/**
 * PointLog —— 公益积分流水（对应表 point_log）
 * 积分是"第二种货币"（与志愿时长分开记账），每笔变动都留痕，balance 为变动后余额。
 */
export class PointLog {
  id: number = 0;
  userId: number = 0;
  /** 变动值：正数入账、负数支出 */
  changeValue: number = 0;
  /** 变动后余额 */
  balance: number = 0;
  /** 原因，如「完成互助任务」「发布求助悬赏」 */
  reason: string = '';
  /** 关联业务 id（求助 id / 订单 id），用于点击跳转 */
  relatedId: number = 0;
  createTime: string = '';

  static fromJson(json: PointLog): PointLog {
    const item: PointLog = new PointLog();
    item.id = json.id ?? 0;
    item.userId = json.userId ?? 0;
    item.changeValue = json.changeValue ?? 0;
    item.balance = json.balance ?? 0;
    item.reason = json.reason ?? '';
    item.relatedId = json.relatedId ?? 0;
    item.createTime = json.createTime ?? '';
    return item;
  }

  static fromJsonList(list: PointLog[]): PointLog[] {
    const out: PointLog[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(PointLog.fromJson(list[i]));
    }
    return out;
  }

  /** 是否为入账（UI 决定显示 +N 还是 -N） */
  isIncome(): boolean {
    return this.changeValue > 0;
  }

  /** 带符号的展示文本，如 "+20" / "-5" */
  changeText(): string {
    if (this.changeValue > 0) {
      return '+' + this.changeValue;
    }
    return '' + this.changeValue;
  }
}
