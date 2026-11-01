import { User } from './User';
import { HelpOrder } from './HelpOrder';
import { HelpReview } from './HelpReview';

/**
 * HelpRequest —— 互助求助（对应表 help_request）
 * 完整闭环：发布 → 大厅 → 接单(HelpOrder) → 完成确认 → 双向互评(HelpReview) → 积分/信用分
 */
export class HelpRequest {
  id: number = 0;
  publisherId: number = 0;
  title: string = '';
  /** HelpCategory 的码值：errand/borrow/qa/skill/carry */
  category: string = '';
  description: string = '';
  /** 悬赏积分 */
  rewardPoint: number = 0;
  /** 期望完成时间（自由文本，如「今天 18:00 前」） */
  expectTime: string = '';
  address: string = '';
  lat: number = 0;
  lng: number = 0;
  /** HelpStatus 的码值：pending/ongoing/finished/canceled */
  status: string = '';
  createTime: string = '';

  // ---- 按需返回 ----

  /** 距我多远（km）。**-1 表示本次响应没有计算距离** */
  distance: number = -1;
  publisher: User | null = null;
  /** 接单信息（详情/列表返回） */
  order: HelpOrder | null = null;
  /** 评价列表（详情返回） */
  reviews: HelpReview[] = [];
  /** 我是否是发布者 / 接单人（详情返回，决定底部按钮显示什么） */
  isPublisher: boolean = false;
  isHelper: boolean = false;
  /** 我是否已评价 */
  reviewedByMe: boolean = false;

  static fromJson(json: HelpRequest): HelpRequest {
    const item: HelpRequest = new HelpRequest();
    item.id = json.id ?? 0;
    item.publisherId = json.publisherId ?? 0;
    item.title = json.title ?? '';
    item.category = json.category ?? '';
    item.description = json.description ?? '';
    item.rewardPoint = json.rewardPoint ?? 0;
    item.expectTime = json.expectTime ?? '';
    item.address = json.address ?? '';
    item.lat = json.lat ?? 0;
    item.lng = json.lng ?? 0;
    item.status = json.status ?? '';
    item.createTime = json.createTime ?? '';
    item.distance = json.distance ?? -1;
    item.isPublisher = json.isPublisher ?? false;
    item.isHelper = json.isHelper ?? false;
    item.reviewedByMe = json.reviewedByMe ?? false;

    const pub: User | null = json.publisher;
    if (pub) {
      item.publisher = User.fromJson(pub);
    }
    const ord: HelpOrder | null = json.order;
    if (ord) {
      item.order = HelpOrder.fromJson(ord);
    }
    item.reviews = HelpReview.fromJsonList(json.reviews);
    return item;
  }

  static fromJsonList(list: HelpRequest[]): HelpRequest[] {
    const out: HelpRequest[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(HelpRequest.fromJson(list[i]));
    }
    return out;
  }

  /** 是否还能接单 */
  canAccept(): boolean {
    return this.status === 'pending';
  }

  /** 本次响应是否带距离数据 */
  hasDistance(): boolean {
    return this.distance >= 0;
  }
}

/** 互助列表分页响应（/api/helps 返回 {list, total, page}） */
export class HelpList {
  list: HelpRequest[] = [];
  total: number = 0;
  page: number = 0;
}
