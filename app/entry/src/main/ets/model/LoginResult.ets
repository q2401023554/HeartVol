/**
 * 登录结果：token + 已脱敏的用户信息
 * 🔴 user 必须由 User.fromJson 还原（JSON.parse 出来的对象没有类方法）。
 */
import { User } from '../model/User';

export class LoginResult {
  token: string = '';
  user: User = new User();

  static fromJson(json: LoginResult): LoginResult {
    const item: LoginResult = new LoginResult();
    item.token = json.token ?? '';
    item.user = json.user ? User.fromJson(json.user) : new User();
    return item;
  }
}
