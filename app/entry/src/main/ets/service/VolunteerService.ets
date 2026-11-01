/**
 * VolunteerService —— 志愿大厅 / 活动详情的数据入口（Mock / Real 双轨，D3）
 *
 * 【契约同 HomeService】
 *   · 页面只认识本层的 `Promise` 签名，不认识 `MockData`
 *   · 逐模块开关：`USE_MOCK` 是总闸，`ApiReady.ACTIVITY` 是分闸
 *
 * 【筛选口径】`activities(filter, keyword)`
 *   filter：'recommend' / 'nearby' → 不按分类过滤；其余（env/teach…）→ 精确匹配分类
 *   'nearby' 走后端 distance 排序，其余走后端默认（开始时间升序）——
 *   排序规则收在 Service 里，页面只传 filter，将来后端换排序不用动 UI。
 */
import { ApiPath, ApiReady, DEFAULT_PAGE_SIZE, USE_MOCK } from '../common/Constants';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HttpUtil } from '../common/HttpUtil';
import { Result } from '../model/Result';
import { Activity } from '../model/Activity';
import { PageResult } from '../model/PageResult';
import { VolunteerStats } from '../model/VolunteerStats';
import { SigninBody, PublishActivityBody, SigninResult, PublishResult } from '../model/ActivityOps';
import { MockData } from '../model/MockData';

export class VolunteerService {

  private static useReal(): boolean {
    return !USE_MOCK || ApiReady.ACTIVITY;
  }

  /** 列表接口的查询串：分类 / 关键词 / 排序 / 分页 */
  private static listQuery(filter: string, keyword: string, size: number): string {
    let q: string = ApiPath.ACTIVITIES + '?size=' + size + '&page=1';
    if (filter === 'nearby') {
      q = q + '&sort=distance';
    }
    if (filter !== '' && filter !== 'recommend' && filter !== 'nearby') {
      q = q + '&category=' + filter;
    }
    if (keyword !== '') {
      // 中文关键词必须编码，否则 URL 里带中文会被服务器拒（400）
      q = q + '&keyword=' + encodeURIComponent(keyword);
    }
    return q;
  }

  /** 大厅顶部数字（后端暂无独立接口 → 复用 home-summary 里的同一批数字） */
  static async stats(): Promise<VolunteerStats> {
    if (!VolunteerService.useReal() || !ApiReady.VOLUNTEER_STATS) {
      return MockData.volunteerStats();
    }
    return MockData.volunteerStats();
  }

  /**
   * 志愿大厅活动列表（分类筛选 + 关键词搜索）。
   * 返回 null = 请求失败（页面显示「加载失败+重试」）；空数组 = 真的没有（显示空态）。
   * 两者混同会让网络故障被误读成「活动都没了」。
   */
  static async activities(filter: string, keyword: string): Promise<Activity[] | null> {
    if (!VolunteerService.useReal()) {
      const base: Activity[] = MockData.searchActivities(keyword, filter);
      if (filter === 'nearby') {
        return MockData.sortByDistance(base);
      }
      return MockData.sortByTime(base);
    }
    try {
      const res: Result<PageResult<Activity>> =
        await HttpUtil.getWithRetry<PageResult<Activity>>(VolunteerService.listQuery(filter, keyword, 50));
      hilog.info(0xFF00, 'MyPub', 'code=%{public}d null=%{public}s listLen=%{public}d',
        res.code, res.data === null ? 'y' : 'n', res.data === null ? -1 : res.data.list.length);
      if (!res.isOk() || res.data === null) {
        return null;
      }
      return Activity.fromJsonList(res.data.list);
    } catch (err) {
      return null;
    }
  }

  /** 活动排行榜：按已报名人数降序取前 count 名（后端无 rank 接口 → 本地按 joinedCount 排） */
  static async rank(count: number): Promise<Activity[]> {
    if (!VolunteerService.useReal()) {
      return MockData.activityRank(count);
    }
    const fetched: Activity[] | null = await VolunteerService.activities('', '');
    const all: Activity[] = fetched === null ? [] : fetched;
    if (all.length === 0) {
      return MockData.activityRank(count);
    }
    const sorted: Activity[] = all.slice();
    sorted.sort((a: Activity, b: Activity) => b.joinedCount - a.joinedCount);
    return sorted.slice(0, count);
  }

  /**
   * 活动详情。找不到返回 null（页面据此显示空状态），而不是抛错 ——
   * 「活动已下架」是正常业务分支，不该走 catch。
   */
  static async detail(id: number): Promise<Activity | null> {
    if (!VolunteerService.useReal()) {
      return MockData.activityDetail(id);
    }
    try {
      const res: Result<Activity> = await HttpUtil.getWithRetry<Activity>(ApiPath.activityDetail(id));
      if (!res.isOk() || res.data === null) {
        // 404「活动不存在」也走这里 → null，页面显示空状态
        return null;
      }
      return Activity.fromJson(res.data);
    } catch (err) {
      return null;
    }
  }

  // ==================== 写操作：报名 / 签到 / 发布（D3 后半） ====================

  /** 报名。成功后页面把 signedUp 置位并提示；失败返回后端文案（如「名额已满」） */
  static async signup(id: number): Promise<Result<boolean>> {
    if (!VolunteerService.useReal()) {
      return Result.ok<boolean>(true);
    }
    try {
      const res: Result<boolean> = await HttpUtil.post<boolean>(ApiPath.activitySignup(id), null);
      return res;
    } catch (err) {
      return Result.fail<boolean>(0, '网络异常，报名失败');
    }
  }

  /** 更新自己发布的活动（发布者管理页；服务端校验发布者身份） */
  static async updateActivity(id: number, body: PublishActivityBody): Promise<Result<boolean>> {
    if (!VolunteerService.useReal()) {
      return Result.ok<boolean>(true);
    }
    try {
      return await HttpUtil.post<boolean>(ApiPath.activityUpdate(id), body);
    } catch (err) {
      return Result.fail<boolean>(0, '网络连接失败，请重试');
    }
  }

  /** 删除自己发布的活动（服务端校验发布者身份；已入账的活动会被拒绝） */
  static async deleteActivity(id: number): Promise<Result<boolean>> {
    if (!VolunteerService.useReal()) {
      return Result.ok<boolean>(true);
    }
    try {
      return await HttpUtil.post<boolean>(ApiPath.activityDelete(id), null);
    } catch (err) {
      return Result.fail<boolean>(0, '网络连接失败，请重试');
    }
  }

  /** 我发布的活动（发布者管理入口：看报名/签到二维码/咨询会话） */
  static async myPublished(): Promise<Activity[]> {
    if (!VolunteerService.useReal()) {
      return [];
    }
    try {
      const res: Result<PageResult<Activity>> =
        await HttpUtil.getWithRetry<PageResult<Activity>>(ApiPath.ACTIVITIES + '/mine');
      if (!res.isOk() || res.data === null) {
        return [];
      }
      return Activity.fromJsonList(res.data.list);
    } catch (err) {
      hilog.error(0xFF00, 'MyPub', 'exception %{public}s', JSON.stringify(err));
      return [];
    }
  }

  /**
   * 签到核销：扫码与手输走同一个接口，区别只是 signType。
   * F2：定位签到走 signType='geo'（免码，围栏校验在服务端），lat/lng 必传。
   */
  static async signin(id: number, code: string, signType: string,
    lat: number = 0, lng: number = 0): Promise<Result<SigninResult>> {
    if (!VolunteerService.useReal()) {
      const mock: SigninResult = new SigninResult();
      mock.hours = 2;
      mock.totalHours = 20.5;
      mock.signinTime = '';
      return Result.ok<SigninResult>(mock);
    }
    try {
      const res: Result<SigninResult> = await HttpUtil.post<SigninResult>(
        ApiPath.activitySignin(id), new SigninBody(code, signType, lat, lng));
      if (!res.isOk() || res.data === null) {
        return res;
      }
      return Result.ok<SigninResult>(SigninResult.fromJson(res.data));
    } catch (err) {
      return Result.fail<SigninResult>(0, '网络异常，签到失败');
    }
  }

  /** 发布活动。成功返回新活动 id 与系统生成的签到码 */
  static async publish(body: PublishActivityBody): Promise<Result<PublishResult>> {
    if (!VolunteerService.useReal()) {
      const mock: PublishResult = new PublishResult();
      mock.id = 0;
      mock.signinCode = '000000';
      return Result.ok<PublishResult>(mock);
    }
    try {
      const res: Result<PublishResult> = await HttpUtil.post<PublishResult>(ApiPath.ACTIVITIES, body);
      if (!res.isOk() || res.data === null) {
        return res;
      }
      return Result.ok<PublishResult>(PublishResult.fromJson(res.data));
    } catch (err) {
      return Result.fail<PublishResult>(0, '网络异常，发布失败');
    }
  }

  /** 默认分页大小（列表接口没传 size 时用） */
  static pageSize(): number {
    return DEFAULT_PAGE_SIZE;
  }
}
