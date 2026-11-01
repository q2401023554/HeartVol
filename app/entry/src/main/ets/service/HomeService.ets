/**
 * HomeService —— 首页数据入口（Mock / Real 双轨，D3 已接真实接口）
 *
 * 【为什么三个方法共用一个请求】
 *   首页要「聚合数字 + 本周推荐 + 活动流」三块内容，后端 `/api/user/home-summary`
 *   一次就全给了。三个方法各自发一次请求是三倍流量，也没必要 ——
 *   所以这里做一次请求 + 结果缓存，三个方法都从缓存取。
 *
 * 【失败降级】接口不通时退回 Mock 数据，保证演示不白屏；
 *   D7 收口时会改成「友好提示 + 重试」而不是静默降级。
 */
import { ApiPath, ApiReady, USE_MOCK } from '../common/Constants';
import { HttpUtil } from '../common/HttpUtil';
import { Result } from '../model/Result';
import { HomeSummary } from '../model/HomeSummary';
import { Activity } from '../model/Activity';
import { MockData } from '../model/MockData';
import { FormStore } from '../common/FormStore';

export class HomeService {
  /** 一次请求的结果缓存（页面进来只拉一次） */
  private static cached: HomeSummary | null = null;

  /** 逐模块开关：USE_MOCK 是总闸，ApiReady.HOME_SUMMARY 是分闸 */
  private static useReal(): boolean {
    return !USE_MOCK || ApiReady.HOME_SUMMARY;
  }

  private static async fetch(): Promise<HomeSummary | null> {
    try {
      const res: Result<HomeSummary> = await HttpUtil.getWithRetry<HomeSummary>(ApiPath.USER_HOME_SUMMARY);
      if (!res.isOk() || res.data === null) {
        return null;
      }
      HomeService.cached = HomeSummary.fromJson(res.data);
      // F3：顺手刷新桌面卡片快照（写失败静默，不影响首页）
      FormStore.save(HomeService.cached).catch(() => {
        // 忽略
      });
      return HomeService.cached;
    } catch (err) {
      return null;
    }
  }

  /** 首页聚合数字 */
  static async summary(): Promise<HomeSummary> {
    if (!HomeService.useReal()) {
      return MockData.homeSummary();
    }
    if (HomeService.cached !== null) {
      return HomeService.cached;
    }
    const fetched: HomeSummary | null = await HomeService.fetch();
    return fetched === null ? MockData.homeSummary() : fetched;
  }

  /** 本周推荐那一场（聚合接口里的 featured） */
  static async featured(): Promise<Activity> {
    if (!HomeService.useReal()) {
      return MockData.recommendedActivity();
    }
    if (HomeService.cached === null) {
      await HomeService.fetch();
    }
    const f: Activity | null = HomeService.cached !== null ? HomeService.cached.featured : null;
    return f === null ? MockData.recommendedActivity() : f;
  }

  /** 活动流：跳过 featured 那场，最多 count 条 */
  static async activityFeed(excludeId: number, count: number): Promise<Activity[]> {
    if (!HomeService.useReal()) {
      return HomeService.mockFeed(excludeId, count);
    }
    if (HomeService.cached === null) {
      await HomeService.fetch();
    }
    const cached: HomeSummary | null = HomeService.cached;
    if (cached === null || cached.feed.length === 0) {
      return HomeService.mockFeed(excludeId, count);
    }
    const out: Activity[] = [];
    for (let i = 0; i < cached.feed.length; i++) {
      if (cached.feed[i].id !== excludeId) {
        out.push(cached.feed[i]);
      }
      if (out.length >= count) {
        break;
      }
    }
    return out;
  }

  /** 切账号 / 数据变更后清缓存（比如下次进首页要最新数据） */
  static clearCache(): void {
    HomeService.cached = null;
  }

  /**
   * 设置页改完资料后调用：
   *   · 清缓存 → 下次进首页强制拉最新（数字与新资料同步）
   *   · 立即后台刷一次 home-summary → fetch() 内部会用新用户名重写桌面卡片快照，
   *     卡片上的「Hi, 姓名」不用等 30 分钟定时刷新才变。
   * 失败静默（fetch 返回 null，无副作用）。
   */
  static async refreshAfterProfileChange(): Promise<void> {
    HomeService.cached = null;
    await HomeService.fetch();
  }

  private static mockFeed(excludeId: number, count: number): Activity[] {
    const sorted: Activity[] = MockData.sortByTime(MockData.activities());
    const out: Activity[] = [];
    for (let i = 0; i < sorted.length; i++) {
      if (sorted[i].id !== excludeId) {
        out.push(sorted[i]);
      }
      if (out.length >= count) {
        break;
      }
    }
    return out;
  }
}
