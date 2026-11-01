/**
 * AuthService —— 注册 / 登录 / 当前用户（D2）
 *
 * 【双轨】USE_MOCK=true 走本地假数据（演示密码 123456），false 走真实接口；
 *        页面只认识 Promise 签名，切轨零改动。
 *
 * 【错误约定】不抛异常（ArkTS 不允许 throw 任意类型），统一返回 Result：
 *   · 200 成功；401 未登录/过期（页面跳登录）；其余为业务错误，message 直接可展示
 * 【职责边界】token 与用户信息的落盘由本层负责（TokenStore.save），页面只管跳转与提示。
 */
import { ApiPath, ApiReady, USE_MOCK } from '../common/Constants';
import { HttpUtil } from '../common/HttpUtil';
import { TokenStore } from '../common/TokenStore';
import { FormStore } from '../common/FormStore';
import { HomeService } from './HomeService';
import { Result } from '../model/Result';
import { LoginResult } from '../model/LoginResult';
import { LoginBody, RegisterBody, ProfileBody } from '../model/AuthBody';
import { User } from '../model/User';
import { MockData } from '../model/MockData';

/** Mock 轨的演示密码（与种子数据一致） */
const MOCK_PASSWORD: string = '123456';

export class AuthService {

  /**
   * 本模块是否走真实接口。
   * 规则：**USE_MOCK 是总闸（关掉=全模块真实），ApiReady.X 是分闸**
   *   —— 总闸还开着时，只有已就绪的模块单独走真实接口，其余继续 Mock。
   * 这样 D 阶段能**逐模块切换**，不会因为某一个接口没好就把整个 App 打崩。
   */
  private static useReal(): boolean {
    return !USE_MOCK || ApiReady.AUTH;
  }

  /** 登录：成功返回 token + 用户，并落盘 */
  static async login(studentNo: string, password: string): Promise<Result<LoginResult>> {
    if (!AuthService.useReal()) {
      if (studentNo === '' || password === '') {
        return Result.fail<LoginResult>(400, '请输入学号与密码');
      }
      if (password !== MOCK_PASSWORD) {
        return Result.fail<LoginResult>(400, '学号或密码不正确');
      }
      const out: LoginResult = new LoginResult();
      out.token = 'mock-token-' + Date.now().toString();
      out.user = MockData.currentUser();
      await TokenStore.save(out.token, out.user);
      return Result.ok<LoginResult>(out);
    }

    const res: Result<LoginResult> =
      await HttpUtil.post<LoginResult>(ApiPath.AUTH_LOGIN, new LoginBody(studentNo, password));
    if (!res.isOk()) {
      return res;
    }
    const data: LoginResult = LoginResult.fromJson(res.data as LoginResult);
    await TokenStore.save(data.token, data.user);
    return Result.ok<LoginResult>(data);
  }

  /** 注册：成功即视为已登录（后端注册直接返回 token） */
  static async register(studentNo: string, password: string, name: string,
                        college: string, major: string): Promise<Result<LoginResult>> {
    if (!AuthService.useReal()) {
      const out: LoginResult = new LoginResult();
      out.token = 'mock-token-' + Date.now().toString();
      out.user = MockData.currentUser();
      out.user.studentNo = studentNo;
      out.user.name = name;
      await TokenStore.save(out.token, out.user);
      return Result.ok<LoginResult>(out);
    }

    const res: Result<LoginResult> = await HttpUtil.post<LoginResult>(ApiPath.AUTH_REGISTER,
      new RegisterBody(studentNo, password, name, college, major));
    if (!res.isOk()) {
      return res;
    }
    const data: LoginResult = LoginResult.fromJson(res.data as LoginResult);
    await TokenStore.save(data.token, data.user);
    return Result.ok<LoginResult>(data);
  }

  /** 当前用户（每次进「我的」都拉一次，保证时长/积分/信用分最新） */
  static async me(): Promise<Result<User>> {
    if (!AuthService.useReal()) {
      return Result.ok<User>(MockData.currentUser());
    }
    const res: Result<User> = await HttpUtil.getWithRetry<User>(ApiPath.USER_ME);
    if (!res.isOk()) {
      return res;
    }
    const user: User = User.fromJson(res.data as User);
    // 只更新缓存的用户信息，token 不动
    if (TokenStore.isLogin()) {
      await TokenStore.save(TokenStore.token(), user);
    }
    return Result.ok<User>(user);
  }

  /** 资料修改（设置页）：姓名必填；成功后用返回的最新 me 刷新缓存 */
  static async updateProfile(name: string, phone: string, college: string): Promise<Result<User>> {
    if (name.trim() === '') {
      return Result.fail<User>(400, '姓名不能为空');
    }
    if (!AuthService.useReal()) {
      const u: User = TokenStore.currentUser() === null ? new User() : (TokenStore.currentUser() as User);
      u.name = name.trim();
      u.phone = phone.trim();
      u.college = college.trim();
      await TokenStore.save(TokenStore.token(), u);
      // 同步刷新桌面卡片快照 + 清首页缓存（Mock 轨同样生效）
      await HomeService.refreshAfterProfileChange();
      return Result.ok<User>(u);
    }
    const res: Result<User> =
      await HttpUtil.post<User>(ApiPath.USER_PROFILE, new ProfileBody(name.trim(), phone.trim(), college.trim()));
    if (!res.isOk()) {
      return res;
    }
    const user: User = User.fromJson(res.data as User);
    if (TokenStore.isLogin()) {
      await TokenStore.save(TokenStore.token(), user);
    }
    // 同步刷新桌面卡片快照（快照里带「Hi, 姓名」）+ 清首页缓存
    await HomeService.refreshAfterProfileChange();
    return Result.ok<User>(user);
  }

  /** 退出登录 */
  static async logout(): Promise<void> {
    await TokenStore.clear();
    // F3：登出同步清桌面卡片快照，卡片回落默认文案
    await FormStore.clear();
  }

  /** 是否已登录（启动页分流用） */
  static isLogin(): boolean {
    return TokenStore.isLogin();
  }
}
