import { AppTheme } from '../common/AppTheme';
import { appMark, lineIcon, LinePath, personLineIcon } from '../common/AppIcon';
import { AuthService } from '../service/AuthService';
import { Result } from '../model/Result';
import { LoginResult } from '../model/LoginResult';
import { SegmentedSwitch } from '../components/SegmentedSwitch';
import { AgreementRow } from '../components/AgreementRow';

/** 演示用学号：设计稿里就预填了这个值，省得演示时还要手打 */
const DEMO_STUDENT_NO: string = '20230101';

/**
 * LoginPage —— 登录页
 *
 * 版式照 `UI\鸿志愿_启动页_登录页_活动详情_界面稿.png`：
 *   品牌行（34vp 标识 + 「鸿志愿」+ 「登录后开始你的志愿服务」）
 *   → 白卡：登录/注册分段切换 → 学号 → 密码 → 忘记密码？ → 橙色全圆角登录按钮 → 协议勾选
 *   → 卡片外底部「还没有账号？立即注册」
 *
 * 【U6 阶段是纯静态】点「登录」直接进 `pages/Index`，不校验账号密码、不调后端。
 *   输入框是真的 `TextInput`（能打字、密码能切明文/密文），接后端时只要把 `doLogin()` 里的
 *   `router.replaceUrl` 换成 Service 调用即可 —— 页面结构不用动。
 *
 * 【为什么用 `replaceUrl` 进主页】登录页不该留在返回栈，否则在主页按返回会退回登录页。
 *
 * 【布局约定】水平留白只加在**容器**上（Scroll 里那层 Column），子元素只写纵向 margin。
 *   `width('100%')` 和水平 margin 同时用会横向溢出（100% + 左右 margin）。
 */
@Entry
@Component
struct LoginPage {
  @State studentNo: string = DEMO_STUDENT_NO;
  @State password: string = '';
  @State agreed: boolean = true;
  /** 登录中：按钮置灰 + 文案切换，防重复点击 */
  @State loading: boolean = false;

  /** 轻提示。`showToast` 会被 ArkTS 标「可能抛异常」，必须包 try/catch，否则编译留告警 */
  private toast(msg: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (err) {
      // 提示失败不影响主流程
    }
  }

  private goRegister(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/RegisterPage' });
    } catch (err) {
      // 跳转失败保持当前页
    }
  }

  /**
   * D2：真实登录。Mock 轨要求密码为 123456，真实轨由后端校验（错误提示不区分学号/密码）。
   * 成功后 token 与用户信息由 AuthService 落盘（TokenStore），重启 App 仍保持登录。
   */
  private async doLogin(): Promise<void> {
    if (!this.agreed) {
      this.toast($r('app.string.login_need_agreement'));
      return;
    }
    if (this.studentNo === '' || this.password === '') {
      this.toast($r('app.string.login_need_input'));
      return;
    }
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      const res: Result<LoginResult> = await AuthService.login(this.studentNo, this.password);
      this.loading = false;
      if (res.isOk()) {
        this.goHome();
        return;
      }
      // 后端返回的业务文案优先（如「学号或密码不正确」），兜底用通用失败文案
      this.toast(res.message !== '' ? res.message : $r('app.string.login_fail'));
    } catch (err) {
      this.loading = false;
      this.toast($r('app.string.login_fail'));
    }
  }

  private goHome(): void {
    try {
      const router = this.getUIContext().getRouter();
      // 进主页前清掉历史页（启动页 / 登录页），主页按返回即退出应用
      router.replaceUrl({ url: 'pages/Index' });
      router.clear();
    } catch (err) {
      // 跳转失败保持当前页
    }
  }

  /**
   * 输入框行：前缀图标 + `TextInput`，两者共用一个灰底圆角容器。
   *
   * ⚠️ 外边距必须写进 Builder 内部 —— `@Builder` 的调用是**语句**，
   *   后面不能链 `.margin()`（只有自定义组件才支持链式通用属性）。
   *   所以 gapTop 是参数，不是调用处补的。
   */
  @Builder
  inputRow(placeholder: ResourceStr, value: string, isPassword: boolean, gapTop: number) {
    Row() {
      if (isPassword) {
        lineIcon(LinePath.LOCK, 14, AppTheme.textHint)
      } else {
        personLineIcon(14, AppTheme.textHint)
      }

      TextInput({ placeholder: placeholder, text: value })
        .type(isPassword ? InputType.Password : InputType.Normal)
        .placeholderColor(AppTheme.textHint)
        .placeholderFont({ size: AppTheme.fontSecondary })
        .fontSize(AppTheme.fontSecondary)
        .fontColor(AppTheme.textPrimary)
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .padding({ left: 0, right: 0 })
        .height(AppTheme.inputHeight)
        .layoutWeight(1)
        .margin({ left: 8 })
        .onChange((next: string) => {
          if (isPassword) {
            this.password = next;
          } else {
            this.studentNo = next;
          }
        })
    }
    .width('100%')
    .height(AppTheme.inputHeight)
    .padding({ left: 12, right: 12 })
    .backgroundColor(AppTheme.fillGray)
    .borderRadius(AppTheme.cardRadiusSmall)
    .margin({ top: gapTop })
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          // ---------- 品牌行 ----------
          Row() {
            appMark(34, 11, 18)

            Column() {
              Text($r('app.string.app_name'))
                .fontSize(AppTheme.fontTitleCard)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.textPrimary)

              Text($r('app.string.login_subtitle'))
                .fontSize(AppTheme.fontCaption)
                .fontColor(AppTheme.textSecondary)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 9 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ top: 20 })

          // ---------- 登录表单卡 ----------
          Column() {
            SegmentedSwitch({
              leftText: $r('app.string.auth_tab_login'),
              rightText: $r('app.string.auth_tab_register'),
              selectedIndex: 0,
              onSelect: (index: number) => {
                if (index === 1) {
                  this.goRegister();
                }
              }
            })

            this.inputRow($r('app.string.login_student_no_hint'), this.studentNo, false, 14)
            this.inputRow($r('app.string.login_password_hint'), this.password, true, 10)

            // 忘记密码？—— 右对齐的橙色文字按钮
            Row() {
              Text($r('app.string.login_forget'))
                .fontSize(AppTheme.fontCaption)
                .fontColor(AppTheme.primary)
                .onClick(() => {
                  this.toast($r('app.string.login_forget_todo'));
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.End)
            .margin({ top: 10 })

            Row() {
              Text(this.loading ? $r('app.string.login_loading') : $r('app.string.login_btn'))
                .fontSize(AppTheme.fontBody)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.textOnPrimary)
            }
            .width('100%')
            .height(AppTheme.buttonHeight)
            .justifyContent(FlexAlign.Center)
            // 登录中用半透明橙表达「不可再点」，不改版式
            .backgroundColor(AppTheme.primary)
            .opacity(this.loading ? 0.6 : 1)
            .borderRadius(AppTheme.pillRadius)
            .margin({ top: 12 })
            .onClick(() => {
              this.doLogin();
            })

            AgreementRow({
              checked: this.agreed,
              onToggle: () => {
                this.agreed = !this.agreed;
              }
            })
              .margin({ top: 14 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.surface)
          .borderRadius(AppTheme.cardRadius)
          .margin({ top: 22 })

          // ---------- 卡片外底部 ----------
          Row() {
            Text($r('app.string.login_no_account'))
              .fontSize(AppTheme.fontCaption)
              .fontColor(AppTheme.textSecondary)

            Text($r('app.string.login_register_now'))
              .fontSize(AppTheme.fontCaption)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.primary)
              .onClick(() => {
                this.goRegister();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16, bottom: 24 })
        }
        .width('100%')
        .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
