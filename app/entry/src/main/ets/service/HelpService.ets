import { ApiPath, ApiReady, USE_MOCK } from '../common/Constants';
import { HttpUtil } from '../common/HttpUtil';
import { Result } from '../model/Result';
import { HelpRequest, HelpList } from '../model/HelpRequest';
import { ReviewBody, PublishHelpBody, PublishHelpResult } from '../model/HelpOps';
import { MockData } from '../model/MockData';

/**
 * HelpService —— 互助大厅 / 求助详情 / 发布求助的数据入口（Mock / Real 双轨，D5）
 *
 * 【契约同 HomeService / VolunteerService / MineService】
 *   · 页面只认识本层的 `Promise` 签名，不认识 `MockData`
 *   · D 阶段只把每个方法的 `if (USE_MOCK)` 那一支换成 HTTP 调用，页面零改动
 *
 * 【筛序口径】`list(filter, keyword)`
 *   filter 取值与 `HelpView` 的胶囊一一对应：'all' / 'errand' / 'borrow' / 'qa' / 'skill' / 'carry'。
 *   排序统一 distance（大厅「按距离排序」语义 + 卡片展示距离）。
 *
 * 【写操作】accept / finish / review / publish 全部返回 `Result`，页面判 `isOk()` 后刷新。
 */
export class HelpService {

  /** 互助模块是否走真实接口：`USE_MOCK` 总闸 + `ApiReady.HELP` 分闸 */
  private static useReal(): boolean {
    return !USE_MOCK || ApiReady.HELP;
  }

  /** 互助大厅列表：分类筛选 + 关键词搜索，按距离升序 */
  /** 求助大厅列表：null = 请求失败（页面显示加载失败+重试）；[] = 真的没有数据 */
  static async list(filter: string, keyword: string): Promise<HelpRequest[] | null> {
    if (!HelpService.useReal()) {
      const base: HelpRequest[] = MockData.searchHelps(keyword, filter);
      MockData.fillPublishers(base);
      return base.sort((a: HelpRequest, b: HelpRequest) => a.distance - b.distance);
    }
    try {
      let q: string = ApiPath.HELPS + '?size=50&page=1&sort=distance';
      if (filter !== '' && filter !== 'all') {
        q = q + '&category=' + filter;
      }
      if (keyword !== '') {
        // 中文关键词必须编码，否则 URL 里带中文会被服务器拒（400）
        q = q + '&keyword=' + encodeURIComponent(keyword);
      }
      const res: Result<HelpList> = await HttpUtil.getWithRetry<HelpList>(q);
      if (!res.isOk() || res.data === null) {
        return null;
      }
      return HelpRequest.fromJsonList(res.data.list);
    } catch (err) {
      return null;
    }
  }

  /** 我发布的求助 */
  static async myPublished(): Promise<HelpRequest[]> {
    if (!HelpService.useReal()) {
      return MockData.fillPublishers(MockData.myPublishedHelps());
    }
    try {
      const res: Result<HelpList> = await HttpUtil.getWithRetry<HelpList>(ApiPath.HELPS + '/mine');
      if (!res.isOk() || res.data === null) {
        return [];
      }
      const out: HelpRequest[] = [];
      for (let i = 0; i < res.data.list.length; i++) {
        if (res.data.list[i].isPublisher) {
          out.push(res.data.list[i]);
        }
      }
      return out;
    } catch (err) {
      return [];
    }
  }

  /** 我接单的求助 */
  static async myAccepted(): Promise<HelpRequest[]> {
    if (!HelpService.useReal()) {
      return MockData.fillPublishers(MockData.myAcceptedHelps());
    }
    try {
      const res: Result<HelpList> = await HttpUtil.getWithRetry<HelpList>(ApiPath.HELPS + '?size=50&page=1&sort=time');
      if (!res.isOk() || res.data === null) {
        return [];
      }
      const out: HelpRequest[] = [];
      for (let i = 0; i < res.data.list.length; i++) {
        if (res.data.list[i].isHelper) {
          out.push(res.data.list[i]);
        }
      }
      return out;
    } catch (err) {
      return [];
    }
  }

  /** 大厅顶部数字：我发布的条数 / 我接单的单数 */
  static async counts(): Promise<number[]> {
    if (!HelpService.useReal()) {
      const published: number = MockData.myPublishedHelps().length;
      const accepted: number = MockData.myAcceptedHelps().length;
      return [published, accepted];
    }
    try {
      const res: Result<HelpList> = await HttpUtil.getWithRetry<HelpList>(ApiPath.HELPS + '?size=50&page=1&sort=time');
      if (!res.isOk() || res.data === null) {
        return [0, 0];
      }
      let pub: number = 0;
      let acc: number = 0;
      for (let i = 0; i < res.data.list.length; i++) {
        if (res.data.list[i].isPublisher) {
          pub = pub + 1;
        }
        if (res.data.list[i].isHelper) {
          acc = acc + 1;
        }
      }
      return [pub, acc];
    } catch (err) {
      return [0, 0];
    }
  }

  /**
   * 求助详情。找不到返回 null（页面据此显示空状态），
   * 而不是抛错 —— 「求助已下架」是正常业务分支，不该走 catch。
   */
  static async detail(id: number): Promise<HelpRequest | null> {
    if (!HelpService.useReal()) {
      return MockData.helpDetail(id);
    }
    try {
      const res: Result<HelpRequest> = await HttpUtil.getWithRetry<HelpRequest>(ApiPath.helpDetail(id));
      if (!res.isOk() || res.data === null) {
        return null;
      }
      return HelpRequest.fromJson(res.data);
    } catch (err) {
      return null;
    }
  }

  /** 接单：pending → ongoing */
  static async accept(id: number): Promise<Result<boolean>> {
    if (!HelpService.useReal()) {
      return Result.ok<boolean>(true);
    }
    try {
      const res: Result<boolean> = await HttpUtil.post<boolean>(ApiPath.helpAccept(id), null);
      return res;
    } catch (err) {
      return Result.fail<boolean>(0, '接单失败，请重试');
    }
  }

  /** 发布者确认完成：order → finished，悬赏入账接单人 */
  static async finish(id: number): Promise<Result<boolean>> {
    if (!HelpService.useReal()) {
      return Result.ok<boolean>(true);
    }
    try {
      const res: Result<boolean> = await HttpUtil.post<boolean>(ApiPath.helpFinish(id), null);
      return res;
    } catch (err) {
      return Result.fail<boolean>(0, '确认完成失败，请重试');
    }
  }

  /** 互评：orderId 是接单 id；score 1~5 星，content 选填 */
  static async review(orderId: number, score: number, content: string): Promise<Result<boolean>> {
    if (!HelpService.useReal()) {
      return Result.ok<boolean>(true);
    }
    try {
      const res: Result<boolean> = await HttpUtil.post<boolean>(
        ApiPath.helpReview(orderId), new ReviewBody(score, content));
      return res;
    } catch (err) {
      return Result.fail<boolean>(0, '评价失败，请重试');
    }
  }

  /** 发布求助：成功返回新求助 id + 剩余积分 */
  static async publish(body: PublishHelpBody): Promise<Result<PublishHelpResult>> {
    if (!HelpService.useReal()) {
      const mock: PublishHelpResult = new PublishHelpResult();
      mock.id = 0;
      mock.point = 320;
      return Result.ok<PublishHelpResult>(mock);
    }
    try {
      const res: Result<PublishHelpResult> = await HttpUtil.post<PublishHelpResult>(ApiPath.HELPS, body);
      if (!res.isOk() || res.data === null) {
        return res;
      }
      return Result.ok<PublishHelpResult>(PublishHelpResult.fromJson(res.data));
    } catch (err) {
      return Result.fail<PublishHelpResult>(0, '发布失败，请重试');
    }
  }
}
