import { promptAction } from '@kit.ArkUI';

/**
 * ToastUtil —— 全局轻提示（支持动态字符串）。
 *
 * 页面自带 `toast(message: Resource)` 只能吃 Resource 字面量；需要展示动态拼接的
 * 真实信息（地址 / 电话 / 发布者 / 证书信息等）时用本工具，底层走全局 promptAction，
 * 不依赖具体组件的 UIContext。
 */
export class ToastUtil {
  static show(message: string): void {
    try {
      promptAction.showToast({ message: message, duration: 2000 });
    } catch (err) {
      // 提示失败不影响主流程
    }
  }
}
