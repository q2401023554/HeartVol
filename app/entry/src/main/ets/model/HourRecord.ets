/**
 * HourRecord —— 志愿时长明细（对应表 volunteer_hour）
 * 志愿时长是"第一种货币"：签到成功后入账，累计到 sys_user.total_hours。
 */
export class HourRecord {
  id: number = 0;
  userId: number = 0;
  activityId: number = 0;
  /** 本次入账时长（小时） */
  hours: number = 0;
  gainTime: string = '';

  /** 时长明细列表展示用（后端联表带出） */
  activityTitle: string = '';
  /** 明细里的活动分类（画图标用） */
  activityCategory: string = '';

  static fromJson(json: HourRecord): HourRecord {
    const item: HourRecord = new HourRecord();
    item.id = json.id ?? 0;
    item.userId = json.userId ?? 0;
    item.activityId = json.activityId ?? 0;
    item.hours = json.hours ?? 0;
    item.gainTime = json.gainTime ?? '';
    item.activityTitle = json.activityTitle ?? '';
    item.activityCategory = json.activityCategory ?? '';
    return item;
  }

  static fromJsonList(list: HourRecord[]): HourRecord[] {
    const out: HourRecord[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(HourRecord.fromJson(list[i]));
    }
    return out;
  }

  /** 时长汇总（明细页顶部大数字用） */
  static sumHours(list: HourRecord[]): number {
    let sum: number = 0;
    for (let i = 0; i < list.length; i++) {
      sum = sum + list[i].hours;
    }
    return sum;
  }
}
