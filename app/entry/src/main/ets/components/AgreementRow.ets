import { AppTheme } from '../common/AppTheme';
import { checkMark } from '../common/AppIcon';

/**
 * AgreementRow —— 协议勾选行（登录页 / 注册页共用）
 *
 * 【为什么不用系统 `Checkbox`】
 *   设计稿是 13vp 的橙色实心圆 + 白色小勾，系统的 `Checkbox` 默认尺寸和样式都压不到这个规格，
 *   改样式比自绘还麻烦。这里就是一个 13vp 的圆角 Row，勾用 `checkMark` 画。
 *
 * 【文案为什么用 Span 拼】
 *   「《用户协议》」「《隐私政策》」在正文里是橙色的，一个 `$r` 字符串做不到局部着色，
 *   拆成四段 `Span` 才能单独给协议名上色。四段文案都在 string.json 里。
 *
 * 【用法】
 *   AgreementRow({ checked: this.agreed, onToggle: () => { this.agreed = !this.agreed } })
 */
@Component
export struct AgreementRow {
  /** 是否已勾选（由页面持有状态） */
  @Prop checked: boolean = true;
  onToggle: () => void = () => {
  };

  build() {
    Row() {
      // 勾选框
      Row() {
        if (this.checked) {
          checkMark(8, AppTheme.textOnPrimary)
        }
      }
      .width(13)
      .height(13)
      .borderRadius(7)
      .backgroundColor(this.checked ? AppTheme.primary : AppTheme.surface)
      .border({ width: 1, color: this.checked ? AppTheme.primary : AppTheme.textHint })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onToggle();
      })

      Text() {
        Span($r('app.string.auth_agreement_prefix'))
        Span($r('app.string.auth_agreement_user')).fontColor(AppTheme.primary)
        Span($r('app.string.auth_agreement_and'))
        Span($r('app.string.auth_agreement_privacy')).fontColor(AppTheme.primary)
      }
      .fontSize(AppTheme.fontCaption)
      .fontColor(AppTheme.textSecondary)
      .lineHeight(18)
      .layoutWeight(1)
      .margin({ left: 6 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
