import { AppTheme } from '../common/AppTheme';
import { lineIcon, LinePath } from '../common/AppIcon';

/**
 * SearchBar —— 胶囊搜索框（两态复用）
 *
 *   editable = false → 只读按钮：首页那个「跟志愿小鸿说一句话」，点了跳对话页
 *   editable = true  → 真输入框：志愿大厅 / 求助大厅的关键词筛选
 *
 * 【外观照设计稿】白底胶囊 + **线性**放大镜 + 右侧橙色「搜索」；
 *   注意放大镜是线性（描边）不是填充 —— 这是设计稿的图标语言，
 *   所以这里用 `lineIcon` 而不是填充型的 `appIcon`。
 *   放大镜颜色可换：首页是橙色（强调「去问小鸿」），大厅里是灰色（普通筛选框）。
 *
 * 【为什么不做「回车才搜」】大厅是本地/短列表筛选，边打边过滤体验更好，
 *   所以对外只抛 onKeywordChange，由页面自己决定怎么过滤。
 *
 * 【用法】
 *   SearchBar({ placeholder: $r('app.string.home_search_placeholder'),
 *               iconColor: AppTheme.primary, showAction: true,
 *               onTap: () => { this.switchTab(NavIconId.AGENT) } })
 *   SearchBar({ placeholder: $r('app.string.hall_search_placeholder'), editable: true,
 *               onKeywordChange: (kw: string) => { this.keyword = kw } })
 */
@Component
export struct SearchBar {
  placeholder: ResourceStr = $r('app.string.common_search');
  /** true = 真输入框 */
  editable: boolean = false;
  /** 左侧放大镜颜色 */
  iconColor: Resource = AppTheme.textHint;
  /** 右侧是否显示橙色「搜索」二字 */
  showAction: boolean = false;
  onTap: () => void = () => {
  };
  onKeywordChange: (keyword: string) => void = (keyword: string) => {
  };

  build() {
    Row() {
      // 13vp 是设计稿里这颗放大镜的一次性尺寸，不留进 float.json
      lineIcon(LinePath.SEARCH, 13, this.iconColor)

      if (this.editable) {
        TextInput({ placeholder: this.placeholder })
          .layoutWeight(1)
          .height('100%')
          .padding(0)
          .margin({ left: 7 })
          .backgroundColor(Color.Transparent)
          .fontSize(AppTheme.fontSecondary)
          .fontColor(AppTheme.textPrimary)
          .placeholderColor(AppTheme.textHint)
          .caretColor(AppTheme.primary)
          .onChange((value: string) => {
            this.onKeywordChange(value);
          })
      } else {
        Text(this.placeholder)
          .fontSize(AppTheme.fontSecondary)
          .fontColor(AppTheme.textHint)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 7 })
      }

      if (this.showAction) {
        Text($r('app.string.common_search'))
          .fontSize(AppTheme.fontSecondary)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.primary)
          .margin({ left: 6 })
      }
    }
    .width('100%')
    .height(AppTheme.searchBarHeight)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.searchBarHeight)
    .onClick(() => {
      if (!this.editable) {
        this.onTap();
      }
    })
  }
}
