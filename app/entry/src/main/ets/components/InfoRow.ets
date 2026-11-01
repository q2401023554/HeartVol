import { AppTheme, IconTone } from '../common/AppTheme';
import { GradientIcon } from './GradientIcon';
import { thinDivider } from './Divider';

/**
 * InfoRow —— 「图标 + 标签 + 值」一行
 *
 * 活动详情 / 求助详情 / 我的资料里的「活动时间、活动地点、志愿时长、招募名额」
 * 全是这个结构，差别只在图标和语调。
 *
 * 【用法】
 *   InfoRow({ iconPath: IconPath.CLOCK, tone: IconTone.ORANGE,
 *             label: $r('app.string.detail_label_time'), value: '09-24 08:30 ~ 11:30' })
 *   InfoRow({ ..., showDivider: true })     // 行末带分割线
 */
@Component
export struct InfoRow {
  labelText: ResourceStr = '';
  valueText: ResourceStr = '';
  /** 留空则不显示左侧图标（用于纯文字信息行） */
  iconPath: string = '';
  tone: string = IconTone.ORANGE;
  /** 值文字颜色，默认正文色；报名人数等可用 AppTheme.primary 强调 */
  valueColor: Resource = AppTheme.textPrimary;
  /** 行末是否带分割线 */
  showDivider: boolean = false;

  build() {
    Column() {
      Row() {
        if (this.iconPath !== '') {
          GradientIcon({
            path: this.iconPath,
            tone: this.tone,
            boxSize: 28,
            glyphSize: 16,
            radius: 8
          })
        }

        Text(this.labelText)
          .fontSize(AppTheme.fontBody)
          .fontColor(AppTheme.textSecondary)
          .margin({ left: this.iconPath !== '' ? 10 : 0 })

        Text(this.valueText)
          .fontSize(AppTheme.fontBody)
          .fontColor(this.valueColor)
          .textAlign(TextAlign.End)
          .layoutWeight(1)
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      if (this.showDivider) {
        thinDivider()
      }
    }
    .width('100%')
  }
}
