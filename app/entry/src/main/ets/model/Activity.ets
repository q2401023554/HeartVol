import { BASE_URL } from '../common/Constants';
import { User } from './User';

/** 参与者轻引用（详情页叠头像用；avatar 多为空，显示姓名首字） */
export class ParticipantRef {
  name: string = '';
  avatar: string = '';

  static fromJson(json: ParticipantRef): ParticipantRef {
    const item: ParticipantRef = new ParticipantRef();
    item.name = json.name ?? '';
    item.avatar = json.avatar ?? '';
    return item;
  }

  static fromJsonList(list: ParticipantRef[]): ParticipantRef[] {
    const out: ParticipantRef[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(ParticipantRef.fromJson(list[i]));
    }
    return out;
  }
}

/**
 * Activity —— 志愿活动（对应表 volunteer_activity）
 */
export class Activity {
  id: number = 0;
  title: string = '';
  /** ActivityCategory 的码值：env/teach/game/elder/campus */
  category: string = '';
  /** 封面图地址（空则用本地占位图） */
  cover: string = '';
  description: string = '';
  address: string = '';
  lat: number = 0;
  lng: number = 0;
  /** yyyy-MM-dd HH:mm:ss */
  startTime: string = '';
  endTime: string = '';
  needCount: number = 0;
  joinedCount: number = 0;
  /** 服务时长（小时），签到后计入志愿者账本 */
  serviceHours: number = 0;
  /** 6 位签到码（仅发布者/详情可见） */
  signinCode: string = '';
  /** 地理围栏半径（米） */
  signinRadius: number = 0;
  /** ActivityStatus 的码值：signuping/ongoing/finished */
  status: string = '';
  publisherId: number = 0;
  createTime: string = '';

  // ---- 以下为「按需返回」字段 ----

  /** 距我多远（km）。**-1 表示本次响应没有计算距离**（未传坐标） */
  distance: number = -1;
  /** 发布者（详情接口返回） */
  publisher: User | null = null;
  /** 我是否已报名（登录后由详情接口返回） */
  signedUp: boolean = false;
  /** 我的报名状态（SignupStatus 码值；未报名时为空串） */
  mySignupStatus: string = '';
  /** 参与者前 N 名（后端 signedUsers 返回，详情页叠头像显示真实姓名首字） */
  participants: ParticipantRef[] = [];

  static fromJson(json: Activity): Activity {
    const item: Activity = new Activity();
    item.id = json.id ?? 0;
    item.title = json.title ?? '';
    item.category = json.category ?? '';
    item.cover = json.cover ?? '';
    item.description = json.description ?? '';
    item.address = json.address ?? '';
    item.lat = json.lat ?? 0;
    item.lng = json.lng ?? 0;
    item.startTime = json.startTime ?? '';
    item.endTime = json.endTime ?? '';
    item.needCount = json.needCount ?? 0;
    item.joinedCount = json.joinedCount ?? 0;
    item.serviceHours = json.serviceHours ?? 0;
    item.signinCode = json.signinCode ?? '';
    item.signinRadius = json.signinRadius ?? 0;
    item.status = json.status ?? '';
    // publisherId 兜底：列表接口若漏发该字段，从嵌套 publisher.id 取
    item.publisherId = json.publisherId ?? (json.publisher !== null && json.publisher !== undefined ? json.publisher.id : 0);
    item.createTime = json.createTime ?? '';
    item.distance = json.distance ?? -1;
    item.signedUp = json.signedUp ?? false;
    item.mySignupStatus = json.mySignupStatus ?? '';
    item.participants = ParticipantRef.fromJsonList(json.participants ?? []);

    const pub: User | null = json.publisher;
    if (pub) {
      item.publisher = User.fromJson(pub);
    }
    return item;
  }

  /** 封面完整 URL（相对路径拼服务器；空串表示无封面，回退分类色块） */
  coverUrl(): string {
    if (this.cover === '') {
      return '';
    }
    if (this.cover.startsWith('http')) {
      return this.cover;
    }
    return BASE_URL + this.cover;
  }

  static fromJsonList(list: Activity[]): Activity[] {
    const out: Activity[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(Activity.fromJson(list[i]));
    }
    return out;
  }

  /** 剩余名额 */
  remainCount(): number {
    const r: number = this.needCount - this.joinedCount;
    return r > 0 ? r : 0;
  }

  /** 是否已招满 */
  isFull(): boolean {
    return this.joinedCount >= this.needCount;
  }

  /** 报名进度 0~1（进度条用） */
  joinProgress(): number {
    if (this.needCount <= 0) {
      return 0;
    }
    const p: number = this.joinedCount / this.needCount;
    return p > 1 ? 1 : p;
  }

  /** 本次响应是否带距离数据 */
  hasDistance(): boolean {
    return this.distance >= 0;
  }
}
