import { AppTheme, IconTone, ToneColors } from '../common/AppTheme';
import { appIcon, lineIcon } from '../common/AppIcon';

/**
 * GradientIcon —— 圆角方块 + 白色矢量图标
 *
 * 设计稿里「宫格入口 / 快捷入口 / 消息类型」都是同一个东西：
 *   一块 40~48 的圆角方块，底是橙色（或绿/蓝/黄）渐变，中间一个白色线性图标。
 * 把它抽成一个组件，改圆角只改一处。
 *
 * 【为什么不直接传颜色】传 tone（语调字符串）而不是 Resource：
 *   ArkTS 的 @Prop / 普通成员传 Resource 时深浅色切换要自己处理，
 *   而 tone 走到 ToneColors 里查表，颜色永远来自资源文件 —— 深色模式天然生效。
 *
 * 【用法】
 *   GradientIcon({ path: IconPath.SCAN, tone: IconTone.ORANGE })
 *   GradientIcon({ path: IconPath.CART, tone: IconTone.GREEN, boxSize: 48, glyphSize: 26, radius: 14 })
 *   GradientIcon({ path: IconPath.LIST, tone: IconTone.YELLOW, boxSize: 36, glyphSize: 17,
 *                  useFlat: true, flatColor: AppTheme.iconSolidYellow })     // 纯色底
 *   GradientIcon({ path: LinePath.SCAN, linear: true, tone: IconTone.ORANGE,
 *                  useFlat: true, flatColor: AppTheme.primaryGradientStart,
 *                  boxSize: 36, glyphSize: 17 })                             // 首页宫格
 */
@Component
export struct GradientIcon {
  /** 图标路径，取 IconPath 里的常量 */
  path: string = '';
  /** 语调：IconTone.ORANGE / GREEN / BLUE / YELLOW / GRAY */
  tone: string = IconTone.ORANGE;
  /** 方块边长（vp） */
  boxSize: number = 40;
  /** 图标边长（vp），一般取 boxSize 的 0.55 倍左右 */
  glyphSize: number = 22;
  /** 方块圆角（vp） */
  radius: number = 12;
  /**
   * 实心底（不走渐变）。首页宫格四色在设计稿里是**纯色**：
   *   #FF8A4C / #4D9B70 / #4C8DFF / #EF9F27 —— 和 icon_grad_* 的起止色并不一致，
   *   硬套渐变会偏色（黄色尤其明显），所以留一个 flatColor 口子。
   */
  useFlat: boolean = false;
  /** useFlat = true 时的底色 */
  flatColor: Resource = AppTheme.primaryGradientStart;
  /**
   * 图标用**线性描边**而不是填充。
   * 设计稿的图标语言是 16×16 线性描边（宫格 / 导航 / 顶栏全是），
   * 只有应用标识那类才用填充。传 true 时 `path` 要取 `LinePath` 里的常量。
   */
  linear: boolean = false;

  build() {
    Stack() {
      if (this.linear) {
        lineIcon(this.path, this.glyphSize, AppTheme.textOnPrimary)
      } else {
        appIcon(this.path, this.glyphSize, AppTheme.textOnPrimary)
      }
    }
    .width(this.boxSize)
    .height(this.boxSize)
    .borderRadius(this.radius)
    // 实心与渐变统一走 linearGradient：两端取同色即纯色，省掉属性链上的 if
    .linearGradient({
      angle: 135,
      colors: [
        [this.useFlat ? this.flatColor : ToneColors.gradStart(this.tone), 0.0],
        [this.useFlat ? this.flatColor : ToneColors.gradEnd(this.tone), 1.0]
      ]
    })
  }
}
