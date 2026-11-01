import { AppTheme } from '../common/AppTheme';

/**
 * SegmentedSwitch —— 双段切换（iOS 式分段控件）
 *
 * 【和 U4 的 `SegmentedTabs` 不是一回事，别混用】
 *   SegmentedTabs：横向可滚动的**多个**胶囊筛选条（志愿大厅 / 互助大厅的分类筛选）
 *   SegmentedSwitch：固定**两段**的单选开关（登录 / 注册）
 *   前者是"筛选"，后者是"切换身份"，视觉也不同（后者有白色滑块）。
 *
 * 【视觉】灰底轨道 + 白色滑块；选中文字橙色 + 字重 500，未选中次要灰。
 *   照设计稿 `UI\UI界面稿.html`：轨道 padding 3 / 圆角 11，滑块高 30 / 圆角 9。
 *
 * 【用法】
 *   SegmentedSwitch({ leftText: $r('app.string.auth_tab_login'),
 *                     rightText: $r('app.string.auth_tab_register'),
 *                     selectedIndex: 0,
 *                     onSelect: (i: number) => { ... } })
 */
@Component
export struct SegmentedSwitch {
  leftText: ResourceStr = '';
  rightText: ResourceStr = '';
  /** 0 = 左段选中，1 = 右段选中 */
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = () => {
  };

  @Builder
  segItem(index: number, label: ResourceStr) {
    Row() {
      Text(label)
        .fontSize(AppTheme.fontSecondary)
        .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selectedIndex === index ? AppTheme.primary : AppTheme.textSecondary)
    }
    .layoutWeight(1)
    .height(30)
    .borderRadius(9)
    .backgroundColor(this.selectedIndex === index ? AppTheme.surface : Color.Transparent)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onSelect(index);
    })
  }

  build() {
    Row() {
      this.segItem(0, this.leftText)
      this.segItem(1, this.rightText)
    }
    .width('100%')
    .padding(3)
    .borderRadius(11)
    .backgroundColor(AppTheme.fillGray)
  }
}
