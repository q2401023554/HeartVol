import { AppTheme } from '../common/AppTheme';

/**
 * LoadingOverlay —— 整屏加载遮罩
 *
 * 【怎么用】不要用它自己控制显隐，由页面在 Stack 里条件渲染：
 *   Stack() {
 *     ...页面内容...
 *     if (this.loading) {
 *       LoadingOverlay({ text: $r('app.string.common_loading') })
 *     }
 *   }
 * 这样「谁在加载」这件事只有页面知道，组件保持无状态、可在任意页面复用。
 */
@Component
export struct LoadingOverlay {
  text: ResourceStr = $r('app.string.common_loading');

  build() {
    Column() {
      Column() {
        LoadingProgress()
          .width(38)
          .height(38)
          .color(AppTheme.primary)

        Text(this.text)
          .fontSize(AppTheme.fontSecondary)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 10 })
      }
      .width(120)
      .height(120)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.surface)
      .borderRadius(AppTheme.cardRadius)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.maskScrim)
  }
}
