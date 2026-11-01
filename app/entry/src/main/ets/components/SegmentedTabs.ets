import { AppTheme } from '../common/AppTheme';

/**
 * SegmentedTabs —— 横向滚动的胶囊筛选条
 *
 * 志愿大厅的分类筛选（推荐/附近/环保/支教/赛会/助老）、
 * 互助大厅的（全部/跑腿/借物/问答/技能/搬运）、消息中心的四个 Tab，都用它。
 *
 * 【为什么不用系统的 Tabs】系统 Tabs 是「整屏切换」语义，这里只是列表筛选，
 *   用胶囊条更轻，也不会把页面结构绑死在 Tabs 上。
 *
 * 【用法】
 *   SegmentedTabs({ items: this.filters, selectedIndex: this.filterIndex,
 *                   onSelect: (i: number) => { this.filterIndex = i } })
 * items 是 $r 资源数组，顺序与页面的分类码数组一一对应。
 */
@Component
export struct SegmentedTabs {
  items: Resource[] = [];
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = (index: number) => {
  };

  build() {
    Scroll() {
      Row() {
        ForEach(this.items, (item: Resource, index: number) => {
          Text(item)
            .fontSize(AppTheme.fontSecondary)
            .fontWeight(index === this.selectedIndex ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(index === this.selectedIndex ? AppTheme.textOnPrimary : AppTheme.textSecondary)
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor(index === this.selectedIndex ? AppTheme.primary : AppTheme.fillGray)
            .borderRadius(AppTheme.buttonHeight)
            .margin({ right: 8 })
            .onClick(() => {
              this.onSelect(index);
            })
        }, (item: Resource, index: number) => index.toString())
      }
      .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Start)
  }
}
