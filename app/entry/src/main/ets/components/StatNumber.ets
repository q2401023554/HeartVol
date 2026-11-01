import { AppTheme } from '../common/AppTheme';

/**
 * StatNumber —— 大数字 + 单位 + 说明
 *
 * 志愿大厅顶部「累计时长 18.5 小时 / 参与次数 6 次」、
 * 「我的」页深色卡里的三个数字，都是这个。
 *
 * 【用法】
 *   StatNumber({ valueText: '18.5', unitText: $r('app.string.common_unit_hour'),
 *                labelText: $r('app.string.hall_total_hours') })
 *   StatNumber({ valueText: '92', labelText: $r('app.string.mine_credit_prefix'),
 *                showUnit: false, valueColor: AppTheme.textOnDark })
 */
@Component
export struct StatNumber {
  /** 数字，已经格式化好的字符串（避免组件里做格式化，格式化归页面管） */
  valueText: string = '0';
  unitText: ResourceStr = '';
  /** 是否显示单位 */
  showUnit: boolean = true;
  labelText: ResourceStr = '';
  valueColor: Resource = AppTheme.textPrimary;
  /** 说明文字颜色，深色卡里要传浅色 */
  labelColor: Resource = AppTheme.textSecondary;

  build() {
    Column() {
      Row() {
        Text(this.valueText)
          .fontSize(AppTheme.fontNumberLg)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.valueColor)

        if (this.showUnit) {
          Text(this.unitText)
            .fontSize(AppTheme.fontSecondary)
            .fontColor(this.valueColor)
            .margin({ left: 3, bottom: 4 })
        }
      }
      .alignItems(VerticalAlign.Bottom)

      Text(this.labelText)
        .fontSize(AppTheme.fontSecondary)
        .fontColor(this.labelColor)
        .margin({ top: 3 })
    }
    .alignItems(HorizontalAlign.Center)
  }
}
