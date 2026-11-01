import { Activity } from './Activity';

/**
 * Signup —— 活动报名（对应表 activity_signup）
 */
export class Signup {
  id: number = 0;
  activityId: number = 0;
  userId: number = 0;
  /** SignupStatus 的码值：signed_up/checked_in/completed/no_show */
  status: string = '';
  signupTime: string = '';

  /** 「我的报名」列表接口会带上活动详情 */
  activity: Activity | null = null;

  static fromJson(json: Signup): Signup {
    const item: Signup = new Signup();
    item.id = json.id ?? 0;
    item.activityId = json.activityId ?? 0;
    item.userId = json.userId ?? 0;
    item.status = json.status ?? '';
    item.signupTime = json.signupTime ?? '';

    const act: Activity | null = json.activity;
    if (act) {
      item.activity = Activity.fromJson(act);
    }
    return item;
  }

  static fromJsonList(list: Signup[]): Signup[] {
    const out: Signup[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(Signup.fromJson(list[i]));
    }
    return out;
  }

  /** 是否还能签到（已报名或已签到都允许再次进入签到流程由后端判定，这里只供 UI 提示） */
  canSignIn(): boolean {
    return this.status === 'signed_up';
  }
}
