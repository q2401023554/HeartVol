import { AppTheme } from '../common/AppTheme';
import { appMark } from '../common/AppIcon';
import { TokenStore } from '../common/TokenStore';
import { AuthService } from '../service/AuthService';

/**
 * SplashPage —— 启动页
 *
 * 版式照 `UI\鸿志愿_启动页_登录页_活动详情_界面稿.png`：
 *   纯白底 · 居中 86vp 橙色圆角方块（内含白心）+ 「鸿志愿」(20fp/500/字距 3)
 *   + 「校园志愿服务与互助平台」(11fp 次要灰) · 底部 22vp 处版权小字 (11fp 提示灰)
 *
 * 【停留多久】1.8 秒。够看清 logo，又不会让人等 —— 点屏幕任意处可立刻跳过。
 *
 * 【为什么用 replaceUrl 而不是 pushUrl】
 *   启动页不该留在返回栈里。用 replace 后，在登录页按返回会直接退出应用，
 *   而不是退回启动页再自动跳一次（那会有明显的"闪一下"）。
 */
@Entry
@Component
struct SplashPage {
  /** setTimeout 的句柄，-1 表示没有在跑的定时器 */
  private timerId: number = -1;

  /**
   * D2：读本地登录态。分流放 setTimeout 到点之后 —— 保证所有用户都能看到
   * 1.8 秒品牌启动页（此前已登录会立刻跳主页，启动页被"闪没"）。
   * TokenStore.load() 是异步的（preferences），先加载完再挂定时器，避免登录态误判。
   */
  aboutToAppear(): void {
    TokenStore.load().then(() => {
      if (this.timerId === -1) {
        this.timerId = setTimeout(() => {
          this.routeNext();
        }, 1800);
      }
    });
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }

  /** 按登录态分流：已登录进主页并清栈（主页按返回即退出应用），未登录去登录页 */
  private routeNext(): void {
    if (AuthService.isLogin()) {
      this.goHome();
    } else {
      this.goLogin();
    }
  }

  private goLogin(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
    } catch (err) {
      // 跳转失败就停在启动页，不白屏
    }
  }

  /** 已登录：直接进主页并清栈（主页按返回即退出应用） */
  private goHome(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    try {
      const router = this.getUIContext().getRouter();
      router.replaceUrl({ url: 'pages/Index' });
      router.clear();
    } catch (err) {
      // 跳转失败就停在启动页，不白屏
    }
  }

  build() {
    Column() {
      Column() {
        appMark(86, 26, 44)

        Text($r('app.string.app_name'))
          .fontSize(AppTheme.fontTitlePage)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .letterSpacing(3)
          .margin({ top: 18 })

        Text($r('app.string.splash_slogan'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 7 })
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text($r('app.string.splash_copyright'))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textHint)
        .margin({ bottom: 22 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.surface)
    .onClick(() => {
      this.routeNext();
    })
  }
}
