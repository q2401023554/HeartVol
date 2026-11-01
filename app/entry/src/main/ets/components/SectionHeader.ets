import { AppTheme } from '../common/AppTheme';
import { appIcon, IconPath } from '../common/AppIcon';

/**
 * SectionHeader —— 区块标题
 *
 * 设计稿里每个区块标题左边都有一根短竖色条（「本周推荐志愿服务」「志愿活动」…），
 * 右侧是「查看更多 ›」。色条颜色可换（互助区块用绿色）。
 *
 * 【用法】
 *   SectionHeader({ title: $r('app.string.home_week_recommend') })
 *   SectionHeader({ title: $r('app.string.home_section_activity'), barColor: AppTheme.accent,
 *                   showAction: true, actionText: $r('app.string.common_see_more'),
 *                   onAction: () => { this.tabIndex = 1 } })
 */
@Component
export struct SectionHeader {
  title: ResourceStr = '';
  /** 左侧色条颜色：默认橙，互助区块传 AppTheme.accent */
  barColor: Resource = AppTheme.primary;
  showAction: boolean = false;
  actionText: ResourceStr = '';
  /** 右侧文字与箭头的颜色。首页「本周推荐 09-24 周四 ›」整条是橙色，所以可换 */
  actionColor: Resource = AppTheme.textSecondary;
  onAction: () => void = () => {
  };

  build() {
    Row() {
      Row()
        .width(4)
        .height(16)
        .borderRadius(2)
        .backgroundColor(this.barColor)

      Text(this.title)
        .fontSize(AppTheme.fontTitleSection)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
        .layoutWeight(1)
        .margin({ left: 8 })

      if (this.showAction) {
        Row() {
          Text(this.actionText)
            .fontSize(AppTheme.fontSecondary)
            .fontColor(this.actionColor)
          appIcon(IconPath.CHEVRON_RIGHT, 14, this.actionColor)
        }
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.onAction();
        })
      }
    }
    .width('100%')
    .height(30)
    .alignItems(VerticalAlign.Center)
  }
}
