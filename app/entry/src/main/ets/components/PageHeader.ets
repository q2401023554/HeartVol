import { AppTheme } from '../common/AppTheme';
import { lineIcon, LinePath } from '../common/AppIcon';

/**
 * PageHeader —— 二级页顶部栏（线性图标语言）
 *
 * 【为什么它不在 U4 那 12 个里】
 *   U4 的 12 个公共件是内容件（卡片、标签、空态…）。二级页顶部栏是**壳件**，
 *   直到 U5 把 12 个页面注册进路由才暴露出来 —— 9 个二级页都要它，所以现在补上。
 *
 * 【形态】照设计稿 `UI\UI界面稿.html` 的二级页头：
 *   高 44vp；左「‹」线性返回（20vp）；中标题 14fp/500；右可选文字动作（11fp）。
 *   左右两侧都是 48vp 定宽占位 —— 这样标题在**任何**页面里都真正居中，
 *   不会因为右侧有「全部已读」而偏左。
 *
 * 【用法】
 *   PageHeader({ title: $r('app.string.msg_title'),
 *                showAction: true, actionText: $r('app.string.msg_read_all'),
 *                actionColor: AppTheme.primary,
 *                onBack: () => { this.getUIContext().getRouter().back() } })
 */
@Component
export struct PageHeader {
  /** 页面标题 */
  title: ResourceStr = '';
  /** 是否显示返回箭头（默认显示） */
  showBack: boolean = true;
  /** 是否显示右侧文字动作 */
  showAction: boolean = false;
  actionText: ResourceStr = '';
  /** 右侧动作色：普通动作用次要灰，强动作用 primary */
  actionColor: ResourceColor = AppTheme.textSecondary;
  /** 是否在底部加一条细分割线（默认不加 —— 设计稿是「底色分层不用描边」） */
  showDivider: boolean = false;
  onBack: () => void = () => {
  };
  onAction: () => void = () => {
  };

  build() {
    Column() {
      Row() {
        // ---- 左：返回 ----
        Row() {
          if (this.showBack) {
            lineIcon(LinePath.CHEVRON_LEFT, 20, AppTheme.textPrimary)
          }
        }
        .width(48)
        .height(44)
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          if (this.showBack) {
            this.onBack();
          }
        })

        // ---- 中：标题 ----
        Text(this.title)
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // ---- 右：文字动作 ----
        Row() {
          if (this.showAction) {
            Text(this.actionText)
              .fontSize(AppTheme.fontCaption)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.actionColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.onAction();
              })
          }
        }
        .width(48)
        .height(44)
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)

      if (this.showDivider) {
        Row()
          .width('100%')
          .height(AppTheme.dividerHeight)
          .backgroundColor(AppTheme.divider)
      }
    }
    .width('100%')
    // 背景留空 —— 让页面自己的底色透上来（有的页面灰底 / 有的白底 / 详情页还要压在大图上）
  }
}
