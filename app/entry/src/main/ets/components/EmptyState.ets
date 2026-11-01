import { AppTheme } from '../common/AppTheme';
import { appIcon, IconPath } from '../common/AppIcon';

/**
 * EmptyState —— 空状态
 *
 * 灰底圆 + 线性图标 + 标题 + 说明 + 可选行动按钮。
 * 列表为空、搜索无结果、消息为空的四个页面共用一个。
 *
 * 【用法】
 *   EmptyState({ title: $r('app.string.common_empty'), subtitle: $r('app.string.common_net_error') })
 *   EmptyState({ iconPath: IconPath.SEARCH, title: ..., showAction: true,
 *                actionText: $r('app.string.common_retry'), onAction: () => { this.reload() } })
 */
@Component
export struct EmptyState {
  /** 圆里的图标，默认「收纳箱」 */
  iconPath: string = IconPath.INBOX;
  title: ResourceStr = '';
  subtitle: ResourceStr = '';
  /** 是否显示副文案 */
  showSubtitle: boolean = true;
  /** 是否显示行动按钮 */
  showAction: boolean = false;
  actionText: ResourceStr = '';
  onAction: () => void = () => {
  };

  build() {
    Column() {
      Stack() {
        appIcon(this.iconPath, 34, AppTheme.textHint)
      }
      .width(76)
      .height(76)
      .borderRadius(38)
      .backgroundColor(AppTheme.fillGray)

      Text(this.title)
        .fontSize(AppTheme.fontTitleCard)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
        .margin({ top: 14 })

      if (this.showSubtitle) {
        Text(this.subtitle)
          .fontSize(AppTheme.fontSecondary)
          .fontColor(AppTheme.textHint)
          .textAlign(TextAlign.Center)
          .margin({ top: 6 })
      }

      if (this.showAction) {
        Text(this.actionText)
          .fontSize(AppTheme.fontBody)
          .fontColor(AppTheme.primary)
          .padding({ left: 20, right: 20, top: 7, bottom: 7 })
          .backgroundColor(AppTheme.primaryLight)
          .borderRadius(AppTheme.buttonHeight)
          .margin({ top: 18 })
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .padding({ top: 56, bottom: 56, left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }
}
