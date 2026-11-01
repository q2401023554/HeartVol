/**
 * 活动侧「写操作」的请求体与返回体（D3 后半）
 * 🔴 ArkTS：请求体必须是显式声明的类，不能传裸对象字面量。
 */

// ==================== 请求体 ====================

/** 签到核销（扫码 / 手输 / 地理围栏共用） */
export class SigninBody {
  /** 6 位签到码 */
  code: string = '';
  /** scan / manual / geo */
  signType: string = 'manual';
  lat: number = 0;
  lng: number = 0;

  constructor(code: string, signType: string, lat: number, lng: number) {
    this.code = code;
    this.signType = signType;
    this.lat = lat;
    this.lng = lng;
  }
}

/** 发布活动 */
export class PublishActivityBody {
  title: string = '';
  category: string = '';
  cover: string = '';
  description: string = '';
  address: string = '';
  lat: number = 0;
  lng: number = 0;
  /** yyyy-MM-dd HH:mm:ss */
  startTime: string = '';
  endTime: string = '';
  needCount: number = 0;
  serviceHours: number = 0;

  constructor(title: string, category: string, description: string, address: string,
              lat: number, lng: number, startTime: string, endTime: string,
              needCount: number, serviceHours: number) {
    this.title = title;
    this.category = category;
    this.cover = '';
    this.description = description;
    this.address = address;
    this.lat = lat;
    this.lng = lng;
    this.startTime = startTime;
    this.endTime = endTime;
    this.needCount = needCount;
    this.serviceHours = serviceHours;
  }
}

// ==================== 返回体 ====================

/** 签到成功返回：本次入账时长 / 累计时长 / 签到时间 */
export class SigninResult {
  hours: number = 0;
  totalHours: number = 0;
  signinTime: string = '';

  static fromJson(json: SigninResult): SigninResult {
    const item: SigninResult = new SigninResult();
    item.hours = json.hours ?? 0;
    item.totalHours = json.totalHours ?? 0;
    item.signinTime = json.signinTime ?? '';
    return item;
  }
}

/** 发布成功返回：新活动 id + 系统生成的 6 位签到码 */
export class PublishResult {
  id: number = 0;
  signinCode: string = '';

  static fromJson(json: PublishResult): PublishResult {
    const item: PublishResult = new PublishResult();
    item.id = json.id ?? 0;
    item.signinCode = json.signinCode ?? '';
    return item;
  }
}

/** /api/upload 响应：{ url: "/uploads/xxx.jpg" }（相对路径，展示时拼 BASE_URL） */
export class UploadReply {
  url: string = '';

  static fromJson(json: UploadReply): UploadReply {
    const item: UploadReply = new UploadReply();
    item.url = json.url ?? '';
    return item;
  }
}
