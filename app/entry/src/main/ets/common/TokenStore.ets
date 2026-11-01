/**
 * TokenStore —— 登录态内存缓存 + 本地持久化（用户首选项）
 *
 * 设计取舍：
 *   · 磁盘读写是异步的，但**每次请求都要带 token** → 内存缓存同步读，磁盘只在
 *     启动（SplashPage 调 load()）和登录/登出时写一次。
 *   · 用户信息缓存成 JSON 字符串（User 带方法，JSON.parse 后方法会丢，
 *     所以读回来必须走 User.fromJson，不能直接用 JSON.parse 的结果）。
 */
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { User } from '../model/User';

const PREF_NAME: string = 'hongzhiyuan';
const KEY_TOKEN: string = 'token';
const KEY_USER: string = 'user_json';

/** context 由 EntryAbility 在 onCreate 里塞进 AppStorage，普通类从这里取 */
export const CTX_KEY: string = 'abilityContext';

export class TokenStore {
  private static cachedToken: string = '';
  private static cachedUser: User | null = null;
  private static loaded: boolean = false;

  /** 启动页调一次：把磁盘登录态读进内存（失败就当未登录，不阻塞启动） */
  static async load(): Promise<void> {
    if (TokenStore.loaded) {
      return;
    }
    TokenStore.loaded = true;
    try {
      const ctx: common.Context | undefined = AppStorage.get<common.Context>(CTX_KEY);
      if (ctx === undefined) {
        return;
      }
      const store: preferences.Preferences = await preferences.getPreferences(ctx, PREF_NAME);
      TokenStore.cachedToken = await store.get(KEY_TOKEN, '') as string;
      const userJson: string = await store.get(KEY_USER, '') as string;
      if (userJson !== '') {
        TokenStore.cachedUser = User.fromJson(JSON.parse(userJson) as User);
      }
    } catch (err) {
      // 读不到就按未登录处理
      TokenStore.cachedToken = '';
      TokenStore.cachedUser = null;
    }
  }

  static token(): string {
    return TokenStore.cachedToken;
  }

  static isLogin(): boolean {
    return TokenStore.cachedToken !== '';
  }

  /** 当前登录用户（可能为空：已登录但用户信息未缓存时由 Service 拉 /api/user/me 补齐） */
  static currentUser(): User | null {
    return TokenStore.cachedUser;
  }

  /** 登录成功后调用 */
  static async save(token: string, user: User): Promise<void> {
    TokenStore.cachedToken = token;
    TokenStore.cachedUser = user;
    try {
      const ctx: common.Context | undefined = AppStorage.get<common.Context>(CTX_KEY);
      if (ctx === undefined) {
        return;
      }
      const store: preferences.Preferences = await preferences.getPreferences(ctx, PREF_NAME);
      await store.put(KEY_TOKEN, token);
      await store.put(KEY_USER, JSON.stringify(user));
      await store.flush();
    } catch (err) {
      // 落盘失败不影响本次会话（内存里已有 token，重启后需重新登录）
    }
  }

  /** 退出登录 / 收到 401 时调用 */
  static async clear(): Promise<void> {
    TokenStore.cachedToken = '';
    TokenStore.cachedUser = null;
    try {
      const ctx: common.Context | undefined = AppStorage.get<common.Context>(CTX_KEY);
      if (ctx === undefined) {
        return;
      }
      const store: preferences.Preferences = await preferences.getPreferences(ctx, PREF_NAME);
      await store.delete(KEY_TOKEN);
      await store.delete(KEY_USER);
      await store.flush();
    } catch (err) {
      // 忽略
    }
  }
}
