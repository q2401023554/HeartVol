import { AppTheme, TagTone, ToneColors } from '../common/AppTheme';

/**
 * PillTag —— 药丸标签
 *
 * 两种形态：
 *   solid = false（默认）浅底 + 深色字 —— 分类标签、状态标签
 *   solid = true         实心 + 白字 —— 强调（如「报名中」「草稿」）
 *
 * 【为什么用 tone 而不是直接传色】分类标签有 6 种颜色，散在十几个页面里迟早写歪，
 *   统一走 ToneColors 查表，深浅色模式也自动跟着走。
 *
 * 【用法】
 *   PillTag({ text: $r('app.string.help_cat_errand'), tone: TagTone.BLUE })
 *   PillTag({ text: $r('app.string.detail_status_signuping'), solid: true })
 */
@Component
export struct PillTag {
  text: ResourceStr = '';
  tone: string = TagTone.GRAY;
  solid: boolean = false;

  build() {
    Text(this.text)
      .fontSize(AppTheme.fontCaption)
      .fontWeight(this.solid ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.solid ? AppTheme.textOnPrimary : ToneColors.onSoft(this.tone))
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(this.solid ? ToneColors.main(this.tone) : ToneColors.soft(this.tone))
      .borderRadius(AppTheme.buttonHeight)
  }
}
