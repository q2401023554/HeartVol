/**
 * Result —— 后端统一返回体
 * 对应 Java 侧 common/Result.java：{ code, message, data }
 *
 * 【为什么不用 getter 判断成功】JSON.parse 得到的是普通对象，实例 getter 不存在。
 *   所以统一用 isOk() 方法（或直接比较 code），避开这个坑。
 */
export class Result<T> {
  /** 200 = 成功；401 = 未登录/令牌过期；500 = 业务异常 */
  code: number = 200;
  message: string = '';
  data: T | null = null;

  // ---- 构造快捷方法（Mock 层与 Service 层都用得上） ----

  static ok<T>(data: T): Result<T> {
    const r: Result<T> = new Result<T>();
    r.code = 200;
    r.message = 'ok';
    r.data = data;
    return r;
  }

  static fail<T>(code: number, message: string): Result<T> {
    const r: Result<T> = new Result<T>();
    r.code = code;
    r.message = message;
    r.data = null;
    return r;
  }

  isOk(): boolean {
    return this.code === 200;
  }

  isUnauthorized(): boolean {
    return this.code === 401;
  }
}
