import { Activity } from './Activity';

/**
 * HomeSummary —— 首页/桌面卡片的一次性聚合数据
 * 对应接口 GET /api/user/home-summary
 *
 * 桌面卡片（Form Kit）只能做一次轻量请求，所以后端把首页要展示的数字
 * 一次性聚合好返回，避免卡片里发多次请求。
 * D3 后端实现：数字 + featured（本周推荐）+ feed（活动流）一次返回。
 */
export class HomeSummary {
  /** 今日已获志愿时长（小时） */
  todayHours: number = 0;
  /** 今日目标时长（小时），用于「今日志愿 1.5/4 小时」 */
  todayTargetHours: number = 4;
  /** 参与中活动数 */
  ongoingCount: number = 0;
  /** 待签到活动数 */
  pendingSigninCount: number = 0;
  /** 累计志愿时长 */
  totalHours: number = 0;
  /** 公益积分 */
  point: number = 0;
  /** 志愿信用分 */
  creditScore: number = 0;
  /** 未读消息数 */
  unreadCount: number = 0;

  // ---- 下一场活动（桌面卡片倒计时用） ----
  nextActivityId: number = 0;
  nextActivityTitle: string = '';
  /** yyyy-MM-dd HH:mm:ss */
  nextActivityStartTime: string = '';

  /**
   * D3：首页聚合接口顺带返回「本周推荐」与「活动流」，
   * 省掉首页为这两块再发两次列表请求。
   */
  featured: Activity | null = null;
  feed: Activity[] = [];

  static fromJson(json: HomeSummary): HomeSummary {
    const item: HomeSummary = new HomeSummary();
    item.todayHours = json.todayHours ?? 0;
    item.todayTargetHours = json.todayTargetHours ?? 4;
    item.ongoingCount = json.ongoingCount ?? 0;
    item.pendingSigninCount = json.pendingSigninCount ?? 0;
    item.totalHours = json.totalHours ?? 0;
    item.point = json.point ?? 0;
    item.creditScore = json.creditScore ?? 0;
    item.unreadCount = json.unreadCount ?? 0;
    item.nextActivityId = json.nextActivityId ?? 0;
    item.nextActivityTitle = json.nextActivityTitle ?? '';
    item.nextActivityStartTime = json.nextActivityStartTime ?? '';
    item.featured = json.featured ? Activity.fromJson(json.featured) : null;
    item.feed = json.feed ? Activity.fromJsonList(json.feed) : [];
    return item;
  }

  /** 今日进度 0~1 */
  todayProgress(): number {
    if (this.todayTargetHours <= 0) {
      return 0;
    }
    const p: number = this.todayHours / this.todayTargetHours;
    return p > 1 ? 1 : p;
  }

  /** 今天是否有下一场活动 */
  hasNextActivity(): boolean {
    return this.nextActivityTitle !== '';
  }
}
