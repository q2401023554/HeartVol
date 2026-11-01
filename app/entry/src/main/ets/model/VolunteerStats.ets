/**
 * VolunteerStats —— 志愿大厅顶部的个人志愿数字
 *
 * 与 `HomeSummary` 分开的理由：
 *   HomeSummary 是首页/桌面卡片用的「聚合大礼包」（含今日目标、下一场活动…），
 *   这里只要「累计时长 + 参与次数 + 积分 + 信用分」四个稳定值。
 *   两者字段重叠但语义不同，硬塞进一个类会让首页改字段时误伤大厅。
 */
export class VolunteerStats {
  /** 累计志愿时长（小时） */
  totalHours: number = 0;
  /** 参与过（完成过）的活动次数 */
  joinCount: number = 0;
  /** 公益积分 */
  point: number = 0;
  /** 志愿信用分 */
  creditScore: number = 0;

  static fromJson(json: VolunteerStats): VolunteerStats {
    const item: VolunteerStats = new VolunteerStats();
    item.totalHours = json.totalHours ?? 0;
    item.joinCount = json.joinCount ?? 0;
    item.point = json.point ?? 0;
    item.creditScore = json.creditScore ?? 0;
    return item;
  }
}
