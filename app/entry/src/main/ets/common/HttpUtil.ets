/**
 * HttpUtil —— 唯一的网络出口（D1）
 *
 * 约定（与后端 common/Result.java 对齐）：
 *   · 统一返回 { code, message, data }，code 200 才算成功
 *   · code 401 → 返回 Result.fail(401, …)，页面层据此跳登录（并已清 token）
 *   · 自动注入 Authorization: Bearer <token>，超时 15s
 *
 * 🔴 ArkTS 两条硬约束，这里都绕开了：
 *   1. **不能 throw 任意类型**（arkts-limited-throw）→ 一律返回 Result，不抛异常
 *   2. **JSON.parse 出来的对象没有类方法** → 这里不直接把 parse 结果往外传，
 *      而是 new 一个 Result 实例再赋值，保证调用方能安全用 isOk() / isUnauthorized()
 */
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';
import { BASE_URL, HTTP_TIMEOUT_MS, ResultCode } from './Constants';
import { TokenStore } from './TokenStore';
import { Result } from '../model/Result';
import { UploadReply } from '../model/ActivityOps';

/** 上传响应外壳：{code,message,data:{url}}（显式类，规避裸 JSON.parse） */
export class UploadShell {
  code: number = 0;
  message: string = '';
  data: UploadReply = new UploadReply();
}

export class HttpUtil {
  /**
   * 上传图片（multipart/form-data）：封面等场景。
   * uri 来自 PhotoViewPicker（file://media/...），读字节后 multipart POST /api/upload。
   * 后端返回 {url:"/uploads/x.jpg"} 相对路径 —— 拼上 BASE_URL 返回完整可展示地址。
   */
  static async uploadImage(uri: string): Promise<Result<string>> {
    if (!TokenStore.isLogin()) {
      return Result.fail<string>(401, '请先登录');
    }
    let fd: number = -1;
    try {
      fd = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY).fd;
      const size: number = fileIo.statSync(fd).size;
      if (size <= 0 || size > 5 * 1024 * 1024) {
        return Result.fail<string>(400, '图片需在 0~5MB 之间');
      }
      const buf: ArrayBuffer = new ArrayBuffer(size);
      fileIo.readSync(fd, buf);
      fileIo.closeSync(fd);
      fd = -1;

      // 文件名带原扩展名（后端按扩展名识别格式；取不到默认 jpg）
      const clean: string = uri.replace(/\\/g, '/');
      const dot: number = clean.lastIndexOf('.');
      const ext: string = dot >= 0 ? clean.substring(dot).toLowerCase() : '.jpg';
      const mime: string = ext === '.png' ? 'image/png' : (ext === '.webp' ? 'image/webp' : 'image/jpeg');
      const fileName: string = 'cover' + (ext === '.jpeg' ? '.jpg' : ext);

      const client: http.HttpRequest = http.createHttp();
      const header: Record<string, string> = {
        'Authorization': 'Bearer ' + TokenStore.token()
        // 🔴 multipart 不能手动设 Content-Type：设了会丢 boundary
      };
      const form: http.MultiFormData[] = [{
        name: 'file',
        data: buf,
        contentType: mime,
        remoteFileName: fileName
      }];
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: header,
        multiFormDataList: form,
        connectTimeout: HTTP_TIMEOUT_MS,
        readTimeout: 30000,
        expectDataType: http.HttpDataType.STRING
      };
      const resp: http.HttpResponse = await client.request(BASE_URL + '/api/upload', options);
      client.destroy();
      const status: number = resp.responseCode;
      const text: string = typeof resp.result === 'string' ? resp.result : JSON.stringify(resp.result);
      if (status < 200 || status >= 300) {
        return Result.fail<string>(status, '上传失败（' + status + '）');
      }
      // 与 request() 同款解析：只取外壳字段，再装进真正的 Result 实例
      const raw = JSON.parse(text) as UploadShell;
      if (raw.code !== 200 || raw.data === null || raw.data.url === '') {
        return Result.fail<string>(raw.code, raw.message !== '' ? raw.message : '上传失败，请重试');
      }
      return Result.ok<string>(BASE_URL + raw.data.url);
    } catch (err) {
      if (fd >= 0) {
        try {
          fileIo.closeSync(fd);
        } catch (e) {
          // 已关闭
        }
      }
      return Result.fail<string>(500, '上传失败，请检查网络');
    }
  }

  /**
   * 发起请求。成功 / 失败一律返回 Result（不抛异常）。
   * @param path 以 /api 开头的接口路径（用 ApiPath 常量，别手写）
   * @param body 请求体**类实例**（ArkTS 不允许裸对象字面量）；GET 传 null
   * @param timeoutMs 超时毫秒数：默认 15s；LLM 等慢接口（小鸿对话）传 60000
   */
  static async request<T>(path: string, method: http.RequestMethod, body: object | null,
    timeoutMs: number = HTTP_TIMEOUT_MS): Promise<Result<T>> {
    const client: http.HttpRequest = http.createHttp();

    const header: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (TokenStore.isLogin()) {
      header['Authorization'] = 'Bearer ' + TokenStore.token();
    }

    const options: http.HttpRequestOptions = {
      method: method,
      header: header,
      connectTimeout: HTTP_TIMEOUT_MS,
      readTimeout: timeoutMs,
      expectDataType: http.HttpDataType.STRING
    };
    if (body !== null) {
      options.extraData = JSON.stringify(body);
    }

    let status: number = 0;
    let text: string = '';
    try {
      const resp: http.HttpResponse = await client.request(BASE_URL + path, options);
      status = resp.responseCode;
      text = typeof resp.result === 'string' ? resp.result : JSON.stringify(resp.result);
    } catch (err) {
      client.destroy();
      hilog.error(0xFF00, 'HTTP', '%{public}s -> EXC', path);
      return Result.fail<T>(0, '网络连接失败，请检查网络后重试');
    }
    client.destroy();
    hilog.info(0xFF00, 'HTTP', '%{public}s -> %{public}d len=%{public}d head=%{public}s',
      path, status, text.length, text.substring(0, 80));

    if (status === 401) {
      // 拦截器返回裸 401（无 Result 外壳）
      await TokenStore.clear();
      return Result.fail<T>(ResultCode.UNAUTHORIZED, '登录已过期，请重新登录');
    }
    if (status < 200 || status >= 300) {
      return Result.fail<T>(status, '服务暂时不可用（' + status + '）');
    }

    // 解析外壳：只取字段，再装进真正的 Result 实例（保住实例方法）
    const out: Result<T> = new Result<T>();
    try {
      const raw: Result<T> = JSON.parse(text) as Result<T>;
      out.code = raw.code ?? ResultCode.BIZ_ERROR;
      out.message = raw.message ?? '';
      out.data = raw.data;
    } catch (err) {
      return Result.fail<T>(-1, '数据格式异常');
    }

    if (out.code === ResultCode.UNAUTHORIZED) {
      await TokenStore.clear();
    }
    return out;
  }

  static async get<T>(path: string): Promise<Result<T>> {
    return HttpUtil.request<T>(path, http.RequestMethod.GET, null);
  }

  /**
   * GET + 自动重试一次（仅对幂等读取用）。
   * 动机：服务器在国内，设备可能在境外/弱网链路，一次超时不该直接判失败——
   * 重试一次能把「跨境偶发丢包」自愈掉。
   */
  static async getWithRetry<T>(path: string): Promise<Result<T>> {
    const first: Result<T> = await HttpUtil.request<T>(path, http.RequestMethod.GET, null);
    if (first.isOk()) {
      return first;
    }
    // 401 不重试（登录态问题，重试也没用）
    if (first.code === ResultCode.UNAUTHORIZED) {
      return first;
    }
    hilog.info(0xFF00, 'HTTP', 'retry once: %{public}s (code=%{public}d)', path, first.code);
    return HttpUtil.request<T>(path, http.RequestMethod.GET, null);
  }

  static async post<T>(path: string, body: object | null): Promise<Result<T>> {
    return HttpUtil.request<T>(path, http.RequestMethod.POST, body);
  }
}
