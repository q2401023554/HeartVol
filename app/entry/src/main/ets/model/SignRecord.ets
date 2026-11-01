/**
 * SignRecord —— 签到核销记录（对应表 sign_record）
 * 一次签到产生一条；与报名状态、时长入账共同构成"签到闭环"的证据链。
 */
export class SignRecord {
  id: number = 0;
  activityId: number = 0;
  userId: number = 0;
  /** SignType 的码值：scan（扫码）/ geo（地理围栏）/ manual（手输码） */
  signType: string = '';
  /** 签到时的定位（geo 方式必填） */
  lat: number = 0;
  lng: number = 0;
  signTime: string = '';

  static fromJson(json: SignRecord): SignRecord {
    const item: SignRecord = new SignRecord();
    item.id = json.id ?? 0;
    item.activityId = json.activityId ?? 0;
    item.userId = json.userId ?? 0;
    item.signType = json.signType ?? '';
    item.lat = json.lat ?? 0;
    item.lng = json.lng ?? 0;
    item.signTime = json.signTime ?? '';
    return item;
  }

  static fromJsonList(list: SignRecord[]): SignRecord[] {
    const out: SignRecord[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(SignRecord.fromJson(list[i]));
    }
    return out;
  }
}
