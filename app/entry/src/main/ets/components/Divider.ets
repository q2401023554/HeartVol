import { AppTheme } from '../common/AppTheme';

/**
 * Divider —— 全工程统一分割线
 *
 * 【为什么不用系统的 Divider 组件】
 *   Divider().strokeWidth($r('app.float.divider_height')) 会报 10505001：
 *   strokeWidth 的参数类型是 number | string，**不接受 Resource**。
 *   所以统一改用「定高 Row + 底色」——效果一样，且颜色能跟着深浅色模式走。
 *
 * 【用法】
 *   thinDivider()           整宽
 *   insetDivider(56)        左侧留出 56vp（列表项缩进用）
 */

/** 整宽分割线 */
@Builder
export function thinDivider() {
  Row()
    .width('100%')
    .height(AppTheme.dividerHeight)
    .backgroundColor(AppTheme.divider)
}

/**
 * 左侧留白的分割线。
 * 拆成「透明块 + 实色块」两段，而不是给整条线加 padding ——
 * 因为 padding 也属于背景绘制区域，加了 padding 底色仍会铺满整宽。
 */
@Builder
export function insetDivider(left: number) {
  Row() {
    Row()
      .width(left)
      .height('100%')
    Row()
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(AppTheme.divider)
  }
  .width('100%')
  .height(AppTheme.dividerHeight)
}
