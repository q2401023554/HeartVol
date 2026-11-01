/**
 * HelpOps —— 互助写操作请求体 / 响应体（D5）
 *
 * 🔴 ArkTS 约束：请求体必须是**显式声明的类**，不能裸对象字面量（arkts-no-untyped-obj-literals）。
 */

/** 互评请求体 */
export class ReviewBody {
  /** 1~5 星 */
  score: number = 5;
  content: string = '';

  constructor(score: number, content: string) {
    this.score = score;
    this.content = content;
  }
}

/** 发布求助请求体（字段名对齐后端 HelpController.publish 的 @RequestBody 解析） */
export class PublishHelpBody {
  title: string = '';
  /** HelpCategory 码值：errand/borrow/qa/skill/carry */
  category: string = '';
  description: string = '';
  rewardPoint: number = 0;
  expectTime: string = '';
  address: string = '';
  lat: number = 0;
  lng: number = 0;

  constructor(title: string, category: string, description: string, rewardPoint: number,
              expectTime: string, address: string, lat: number, lng: number) {
    this.title = title;
    this.category = category;
    this.description = description;
    this.rewardPoint = rewardPoint;
    this.expectTime = expectTime;
    this.address = address;
    this.lat = lat;
    this.lng = lng;
  }
}

/** 发布求助响应（后端返回 {id, point}） */
export class PublishHelpResult {
  id: number = 0;
  /** 发布后剩余积分余额 */
  point: number = 0;

  static fromJson(json: PublishHelpResult): PublishHelpResult {
    const item: PublishHelpResult = new PublishHelpResult();
    item.id = json.id ?? 0;
    item.point = json.point ?? 0;
    return item;
  }
}
