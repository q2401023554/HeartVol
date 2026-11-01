import { AppTheme } from '../common/AppTheme';
import { lineIcon, LinePath } from '../common/AppIcon';
import { AuthService } from '../service/AuthService';
import { Result } from '../model/Result';
import { LoginResult } from '../model/LoginResult';
import { PageHeader } from '../components/PageHeader';
import { SegmentedSwitch } from '../components/SegmentedSwitch';
import { AgreementRow } from '../components/AgreementRow';

/** 演示用学号（与登录页保持一致，设计稿里就预填了） */
const DEMO_STUDENT_NO: string = '2023211001';

/**
 * 注册表单的字段编号。
 * `@Builder` 不能接收回调（参数类型受限），所以用编号在 `onChange` 里分发写哪个状态。
 */
class RegField {
  static readonly STUDENT_NO: number = 0;
  static readonly NAME: number = 1;
  static readonly PASSWORD: number = 2;
  static readonly CONFIRM: number = 3;
}

/**
 * RegisterPage —— 注册页
 *
 * 版式照 `UI\鸿志愿_求助详情_发布求助_注册页_界面稿.png`：
 *   顶栏（返回 + 「注册账号」 + 右侧「1 / 2」步进提示）
 *   → 登录/注册分段切换（这里停在「注册」）
 *   → 白卡：学号 / 姓名 / 学院（下拉）/ 设置密码 / 确认密码
 *   → 协议勾选 → 底部通栏橙色「注册并登录」
 *
 * 【U6 阶段是纯静态】点「注册并登录」直接进 `pages/Index`，不校验、不调后端。
 *
 * 【布局约定】水平留白只加在**容器**上，子元素只写纵向 margin ——
 *   `width('100%')` 和水平 margin 同时用会横向溢出。
 */
@Entry
@Component
struct RegisterPage {
  @State studentNo: string = DEMO_STUDENT_NO;
  @State realName: string = '';
  @State password: string = '';
  @State confirm: string = '';
  @State agreed: boolean = true;
  /** 注册中：防重复点击 */
  @State loading: boolean = false;

  private toast(msg: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (err) {
      // 提示失败不影响主流程
    }
  }

  private backToLogin(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  /**
   * D2：真实注册。校验（学号/姓名/密码必填、两次密码一致、勾选协议）→ 调接口 →
   * 成功后 AuthService 已把 token 与用户信息落盘，直接进主页。
   */
  private async doRegister(): Promise<void> {
    if (!this.agreed) {
      this.toast($r('app.string.register_need_agreement'));
      return;
    }
    if (this.studentNo === '' || this.realName === '' || this.password === '') {
      this.toast($r('app.string.register_need_input'));
      return;
    }
    if (this.password !== this.confirm) {
      this.toast($r('app.string.register_password_mismatch'));
      return;
    }
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      // 学院/专业在本页是占位下拉（未落真实数据）→ 先传空串，后端允许为空
      const res: Result<LoginResult> =
        await AuthService.register(this.studentNo, this.password, this.realName, '', '');
      this.loading = false;
      if (res.isOk()) {
        this.toast($r('app.string.register_welcome'));
        this.goHome();
        return;
      }
      this.toast(res.message !== '' ? res.message : $r('app.string.register_fail'));
    } catch (err) {
      this.loading = false;
      this.toast($r('app.string.register_fail'));
    }
  }

  private goHome(): void {
    try {
      const router = this.getUIContext().getRouter();
      // 注册页是 pushUrl 进来的，栈里还有登录页。replaceUrl 换掉当前页后会变成
      // [登录页, 主页]，在主页按返回就退回登录页 —— 用 clear() 只留主页，返回即退出应用。
      // 两个调用走同一条 UI 任务队列，无论谁先落地，最终栈都是 [主页]。
      router.replaceUrl({ url: 'pages/Index' });
      router.clear();
    } catch (err) {
      // 跳转失败保持当前页
    }
  }

  @Builder
  fieldLabel(label: ResourceStr, gapTop: number) {
    Text(label)
      .fontSize(AppTheme.fontCaption)
      .fontColor(AppTheme.textSecondary)
      // 🔴 不撑满宽度会被表单卡 Column 的默认居中带走（设计稿是左对齐）
      .width('100%')
      .margin({ top: gapTop })
  }

  /** 普通输入框。field 用 `RegField` 的编号决定回写到哪个状态 */
  @Builder
  regInput(placeholder: ResourceStr, value: string, field: number, isPassword: boolean) {
    Row() {
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
        .onChange((next: string) => {
          if (field === RegField.STUDENT_NO) {
            this.studentNo = next;
          } else if (field === RegField.NAME) {
            this.realName = next;
          } else if (field === RegField.PASSWORD) {
            this.password = next;
          } else {
            this.confirm = next;
          }
        })
    }
    .width('100%')
    .height(AppTheme.inputHeight)
    .padding({ left: 11, right: 11 })
    .backgroundColor(AppTheme.fillGray)
    .borderRadius(AppTheme.cardRadiusSmall)
    .margin({ top: 6 })
  }

  /** 学院选择行：外观与输入框一致，尾部带下拉箭头。U6 只弹提示，不接选择器 */
  @Builder
  collegeSelect() {
    Row() {
      Text($r('app.string.register_college_hint'))
        .fontSize(AppTheme.fontSecondary)
        .fontColor(AppTheme.textHint)
        .layoutWeight(1)

      lineIcon(LinePath.CHEVRON_DOWN, 12, AppTheme.textHint)
    }
    .width('100%')
    .height(AppTheme.inputHeight)
    .padding({ left: 11, right: 11 })
    .backgroundColor(AppTheme.fillGray)
    .borderRadius(AppTheme.cardRadiusSmall)
    .alignItems(VerticalAlign.Center)
    .margin({ top: 6 })
    .onClick(() => {
      this.toast($r('app.string.register_college_todo'));
    })
  }

  build() {
    Column() {
      PageHeader({
        title: $r('app.string.register_title'),
        showAction: true,
        actionText: $r('app.string.register_step_1'),
        actionColor: AppTheme.textHint,
        onBack: () => {
          this.backToLogin();
        }
      })

      Scroll() {
        Column() {
          SegmentedSwitch({
            leftText: $r('app.string.auth_tab_login'),
            rightText: $r('app.string.auth_tab_register'),
            selectedIndex: 1,
            onSelect: (index: number) => {
              if (index === 0) {
                this.backToLogin();
              }
            }
          })
            .margin({ top: 14 })

          // ---------- 注册表单卡 ----------
          Column() {
            this.fieldLabel($r('app.string.login_student_no'), 0)
            this.regInput($r('app.string.login_student_no_hint'), this.studentNo,
              RegField.STUDENT_NO, false)

            this.fieldLabel($r('app.string.register_name'), 12)
            this.regInput($r('app.string.register_name_hint'), this.realName,
              RegField.NAME, false)

            this.fieldLabel($r('app.string.register_college'), 12)
            this.collegeSelect()

            this.fieldLabel($r('app.string.register_password'), 12)
            this.regInput($r('app.string.register_password_hint'), this.password,
              RegField.PASSWORD, true)

            this.fieldLabel($r('app.string.register_confirm_password'), 12)
            this.regInput($r('app.string.register_confirm_hint'), this.confirm,
              RegField.CONFIRM, true)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.surface)
          .borderRadius(AppTheme.cardRadius)
          .margin({ top: 12 })

          AgreementRow({
            checked: this.agreed,
            onToggle: () => {
              this.agreed = !this.agreed;
            }
          })
            .margin({ top: 14, bottom: 14 })
        }
        .width('100%')
        .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')

      // ---------- 底部通栏主按钮（设计稿里它固定在底部，不随表单滚动） ----------
      Column() {
        Row() {
          Text($r('app.string.register_btn'))
            .fontSize(AppTheme.fontBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textOnPrimary)
        }
        .width('100%')
        .height(AppTheme.buttonHeight)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.primary)
        .borderRadius(AppTheme.pillRadius)
        .onClick(() => {
          this.doRegister();
        })
      }
      .width('100%')
      .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 10, bottom: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
