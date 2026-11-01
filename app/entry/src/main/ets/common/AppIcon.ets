import { AppTheme } from './AppTheme';

/**
 * 【2026-09-23 真机踩坑 · 图标缩成小点】—— Shape 子组件必须显式声明宽高！
 *
 * 现象：设计稿上 17vp 的宫格图标，实机只有 6.5vp（约 38%），四个宫格、顶栏、
 *   活动卡缩略图**全部**如此，且与调用方传的 size 无关地等比缩小。
 *
 * 原因：`viewPort` 的作用是"把视口矩形映射到 Shape 的宽高框"，**映射对象是子组件的
 *   宽高**。官方 Shape 示例里每个子组件都写了 `.width().height()`，指南里更是
 *   `Rect().width('100%').height('100%')` 这种写法固定填充视口。
 *   我们的 `Path()` 一个尺寸都没写 —— `Path` 的 width/height「缺省时按自身内容处理」，
 *   内容是 `commands`，而 **commands 的单位是 px**（官方 Path 文档原文）。于是
 *   Path 的框变成 16px（≈8vp），视口 16 → 框 size 的缩放也就套不到正确尺寸上，
 *   最终渲染出来就是"16 个单位 = 16 物理 px"，与 size 完全脱钩。
 *
 * 修法（三条一起上，做到与单位解释无关、怎么解释都对）：
 *   ① 子 `Path` 显式 `.width().height()` = 视口尺寸；
 *   ② 视口尺寸本身也写成 **px 字符串**，和 commands 的坐标系单位严格一致；
 *   ③ 于是 "视口 px → Shape 的 vp 框" 这一个比值就承担全部缩放，
 *      16 个坐标单位必然 = size vp，不依赖 devicePixelRatio。
 *
 * 结论（写进 MEMORY）：**`Shape()` 里画图标，viewPort、子组件宽高、commands 三者
 *   必须同尺寸；子组件不写宽高 = 图标报废。** 只写 viewPort 是不够的。
 */
/** 填充型图标坐标系（24×24，单位 px，与 commands 一致） */
const VB_FILL: string = '24px';
/** 线性型 / 标识型图标坐标系（16×16，单位 px，与 commands 一致） */
const VB_LINE: string = '16px';

/**
 * AppIcon —— 自建矢量图标库（两套坐标系，别混用）
 *
 * ┌ 填充型｜坐标系 24×24｜`IconPath` + `appIcon()`   ── 内容区实心图标
 * ├ 线性型｜坐标系 16×16｜`LinePath` + `lineIcon()`  ── 导航 / 返回 / 表单小图标（设计稿语言）
 * ├ 标识型｜坐标系 16×16｜`MarkPath` + `appMark()`   ── 只有「应用标识」一个用途（渐变底 + 双叶 + 白心，与桌面图标同源）
 * └ 小鸿型｜坐标系 16×16｜`AgentPath` + `agentMark()` ── 「志愿小鸿」机器人（填充 + 圆底色挖空）
 *
 * 其余专用 Builder：`personLineIcon`（人像）、`checkMark`（小号勾）、
 * `navIcon`（底部导航分发）、`IconGeom.circle`（弧线圆，替代不可用的 `Circle` 子组件）。
 *
 * 【为什么不用 SVG 资源文件】工程里一个图标都没有，而设计稿需要十几个图标。
 *   用 Shape + viewPort + Path 自绘：① 一套路径走遍全工程，改一个数字全变；
 *   ② 颜色作为参数传入，天然跟随 AppTheme 的深浅色；
 *   ③ 不需要往 resources/base/media 塞十几个文件。
 *
 * 【原理】Path 的 commands 用各自的坐标系，靠 Shape 的 viewPort 整体缩放，
 *   所以调用方给任意 size 都能得到等比图标。
 *
 * 【用法】
 *   appIcon(IconPath.SEARCH, 22, AppTheme.textPrimary)          // 填充型
 *   lineIcon(LinePath.CHEVRON_LEFT, 20, AppTheme.textPrimary)   // 线性型
 */
export class IconPath {
  /** 放大镜（搜索框左侧） */
  static readonly SEARCH: string =
    'M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z';

  /** 扫描取景框四角（扫码签到 / 扫一扫） */
  static readonly SCAN: string =
    'M3 3h6v2H5v4H3V3zm18 0v6h-2V5h-4V3h6zM3 21v-6h2v4h4v2H3zm18 0h-6v-2h4v-4h2v6z';

  /** 消息气泡（互助 / 分享） */
  static readonly MESSAGE: string =
    'M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z';

  /** 加号（发布） */
  static readonly PLUS: string =
    'M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z';

  /** 列表（我的报名 / 我的求助 / 求助大厅） */
  static readonly LIST: string =
    'M3 5h2v2H3V5zm0 6h2v2H3v-2zm0 6h2v2H3v-2zM7 5h14v2H7V5zm0 6h14v2H7v-2zm0 6h14v2H7v-2z';

  /** 时钟（时长 / 时间） */
  static readonly CLOCK: string =
    'M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z';

  /** 定位（地点 / 距离） */
  static readonly LOCATION: string =
    'M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z';

  /** 爱心（志愿 / 点赞） */
  static readonly HEART: string =
    'M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z';

  /** 人像（我的 / 接单人） */
  static readonly PERSON: string =
    'M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z';

  /** 一群人（互助） */
  static readonly PEOPLE: string =
    'M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z';

  /** 房子（首页） */
  static readonly HOME: string =
    'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z';

  /** 勋章（电子证书 / 已认证） */
  static readonly CERTIFICATE: string =
    'M23 12l-2.44-2.79.34-3.69-3.61-.82-1.89-3.2L12 2.96 8.6 1.5 6.71 4.69 3.1 5.5l.34 3.7L1 12l2.44 2.79-.34 3.7 3.61.82L8.6 22.5l3.4-1.47 3.4 1.46 1.89-3.19 3.61-.82-.34-3.69L23 12zm-12.91 4.72l-3.8-3.81 1.48-1.48 2.32 2.33 5.85-5.87 1.48 1.48-7.33 7.35z';

  /** 收纳箱（空状态） */
  static readonly INBOX: string =
    'M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 12h-4c0 1.66-1.35 3-3 3s-3-1.34-3-3H5V5h14v10z';

  /** 发送箭头（小鸿输入条） */
  static readonly SEND: string =
    'M2.01 21L23 12 2.01 3 2 10l15 2-15 2z';

  /** 星（互评） */
  static readonly STAR: string =
    'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z';

  /** 齿轮（设置） */
  static readonly SETTING: string =
    'M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.48.48 0 0 0-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.48.48 0 0 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6A3.6 3.6 0 1 1 12 8.4a3.6 3.6 0 0 1 0 7.2z';

  /** 右箭头（列表项尾部 / 查看更多） */
  static readonly CHEVRON_RIGHT: string =
    'M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z';

  /** 勾（签到成功 / 已完成） */
  static readonly CHECK: string =
    'M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z';

  /** 勾在圆里（成功态大图标） */
  static readonly CHECK_CIRCLE: string =
    'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z';

  /** 编辑（去修改） */
  static readonly EDIT: string =
    'M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z';

  // ==================== 分类图标（活动 / 互助） ====================

  /** 叶子（环保） */
  static readonly LEAF: string =
    'M6.05 8.05c-2.73 2.73-2.73 7.15-.02 9.88 1.47-3.4 4.09-6.24 7.36-7.93-2.77 2.34-4.71 5.61-5.39 9.32 2.6 1.23 5.8.78 7.95-1.37C19.43 14.47 20 4 20 4S9.53 4.57 6.05 8.05z';

  /** 书（支教 / 学习） */
  static readonly BOOK: string =
    'M18 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 18H6V4h2v8l2.5-1.5L13 12V4h5v16z';

  /** 奖杯（赛会 / 荣誉） */
  static readonly TROPHY: string =
    'M19 5h-2V3H7v2H5c-1.1 0-2 .9-2 2v1c0 2.55 1.92 4.63 4.39 4.94A5.01 5.01 0 0 0 11 15.9V19H7v2h10v-2h-4v-3.1a5.01 5.01 0 0 0 3.61-2.96C19.08 12.63 21 10.55 21 8V7c0-1.1-.9-2-2-2zM5 8V7h2v3.82C5.84 10.4 5 9.3 5 8zm14 0c0 1.3-.84 2.4-2 2.82V7h2v1z';

  /** 购物车（搬运） */
  static readonly CART: string =
    'M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49A1 1 0 0 0 20 4H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z';

  /** 扳手（技能） */
  static readonly TOOL: string =
    'M22.7 19l-9.1-9.1c.9-2.3.4-5-1.5-6.9-2-2-5-2.4-7.4-1.3L9 6 6 9 1.6 4.7C.4 7.1.9 10.1 2.9 12.1c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4z';

  /** 箱子（借物） */
  static readonly BOX: string =
    'M20 2H4c-1 0-2 .9-2 2v3.01c0 .72.43 1.34 1 1.69V20c0 1.1 1.1 2 2 2h14c.9 0 2-.9 2-2V8.7c.57-.35 1-.97 1-1.69V4c0-1.1-1-2-2-2zm-5 12H9v-2h6v2zm5-7H4V4h16v3z';

  /** 奔跑（跑腿） */
  static readonly RUN: string =
    'M13.49 5.48c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm-3.6 13.9l1-4.4 2.1 2v6h2v-7.5l-2.1-2 .6-3c1.3 1.5 3.3 2.5 5.5 2.5v-2c-1.9 0-3.5-1-4.3-2.4l-1-1.6c-.4-.6-1-1-1.7-1-.3 0-.5.1-.8.1l-5.2 2.2v4.7h2v-3.4l1.8-.7-1.6 8.1-4.9-1-.4 2 7 1.4z';

  /** 铃铛（通知类消息） */
  static readonly BELL: string =
    'M12 22c1.1 0 2-.9 2-2h-4c0 1.1.89 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z';
}

/**
 * 【2026-09-23 真机踩坑 ②·结论修正 · 黑色其实来自「默认描边」】
 *
 * 自检页（`pages/IconProbePage.ets`）把同一段 `IconPath.BOOK` 用 12 种写法并排画出来，
 * 逐格放大看到真相：
 *   · 格子 8「`fill(Color.Transparent)` + 白描边」→ 白描边正常，说明 **fill 是生效的**
 *   · 格子 1/2/3/10（只设 fill，不设 stroke）→ 图标里外全黑，只在「填充够宽、
 *     描边盖不住」的地方露出一小条**白色**（放大图里在 x=13 那条路径边上）
 *   · 量到底：黑边带约 4 个坐标单位宽，中间挖空处露的是**蓝底**
 *
 * ⇒ **`fill` 一直是对的；凶手是「默认黑描边」。** `Path` / `Shape` 不显式设 `stroke`
 *   时，会带一条约 2 个坐标单位宽的**黑色描边**，它把白色填充整片盖掉，于是整个图标
 *   看上去就是一坨黑 —— 用户口径「被加粗了有阴影」。
 *
 * 这也解释了**为什么线性图标从来没坏**：`lineIcon` 里写了 `.stroke(color)`，
 * 早就把默认黑描边顶掉了；而 4 个填充型 Builder 一个 `stroke` 都没写。
 *
 * 修法：填充型图标的 `Path` 与父 `Shape` **都显式 `.stroke(Color.Transparent)`**。
 *   `strokeWidth` 不用管 —— 描边透明了，宽多少都看不见。
 *
 * 记法：**`Shape` 里画图标，`width/height/commands` 写子 `Path`，`fill` 写子 `Path`
 *   （父 `Shape` 上也补一份），并且 `stroke(Color.Transparent)` 两处都要写。**
 *
 * 【旧版（错误）判断，留档别再回头】以为「fill 写在子 Path 上会回落成黑色」——
 *   错。fill 写哪儿都生效，缺的是 `stroke` 那一句。
 */
@Builder
export function appIcon(path: string, size: number, color: ResourceColor) {
  Shape() {
    Path()
      .width(VB_FILL)
      .height(VB_FILL)
      .commands(path)
      .fill(color)
      // 🔴 关键：不写这句就会落到默认的黑描边，把填充整片盖掉
      .stroke(Color.Transparent)
  }
  .viewPort({ x: 0, y: 0, width: VB_FILL, height: VB_FILL })
  .width(size)
  .height(size)
  .fill(color)
  .stroke(Color.Transparent)
}

// ==================================================================
// 线性图标（16×16 描边）
// ==================================================================

/**
 * 【为什么另起一套】
 *   设计稿（`UI\UI界面稿.html`）里所有图标都是 **16×16 线性描边**（stroke-width 1.3~1.9、
 *   fill:none），而上面 IconPath 那套是 24×24 的填充型。两者差别肉眼可见：
 *   填充型是"实心块"，线性型是"细线勾边"。
 *
 *   导航栏 / 返回箭头 / 表单里的小图标一律用这一套。路径**逐字照抄设计稿**，
 *   不做二次创作 —— 设计稿就是视觉权威。
 */
export class LinePath {
  /** 返回「‹」 */
  static readonly CHEVRON_LEFT: string = 'M10 3.5L5.5 8l4.5 4.5';
  /** 展开「⌄」（下拉选择器） */
  static readonly CHEVRON_DOWN: string = 'M4 6.5L8 10.5l4-4';
  /** 勾（协议勾选框 / 已完成） */
  static readonly CHECK: string = 'M3 8.5l3.2 3.2L13 4.8';
  /** 锁（密码输入框）—— 圆角矩形锁体 + 锁梁，两段子路径合成一条 */
  static readonly LOCK: string =
    'M4.5 6.8H11.5A1.5 1.5 0 0 1 13 8.3V12.3A1.5 1.5 0 0 1 11.5 13.8H4.5A1.5 1.5 0 0 1 3 12.3V8.3A1.5 1.5 0 0 1 4.5 6.8Z' +
    'M5.5 6.8V5A2.5 2.5 0 0 1 10.5 5V6.8';
  /** 底部导航 · 首页（设计稿原路径） */
  static readonly NAV_HOME: string = 'M2.5 6.8L8 2.5l5.5 4.3v6.2h-11z';
  /** 底部导航 · 志愿（设计稿原路径） */
  static readonly NAV_VOLUNTEER: string =
    'M8 13.5S3 10 3 6.7A2.7 2.7 0 0 1 8 4.8a2.7 2.7 0 0 1 5 1.9C13 10 8 13.5 8 13.5z';
  /** 小鸿标志里的「加号」——**已弃用**（2026-09-23 小鸿改为机器人标识，见 `AgentPath`）。保留常量仅为便于回退对比。 */
  static readonly AGENT_PLUS: string = 'M8 5.5v5M5.5 8h5';
  /** 底部导航 · 互助：左人肩膀（设计稿原路径） */
  static readonly NAV_HELP_SHOULDER: string = 'M2 13c0-1.7 1.7-2.9 3.8-2.9S9.6 11.3 9.6 13';
  /** 人像的肩膀（设计稿原路径，「我的」与输入框共用） */
  static readonly PERSON_SHOULDER: string = 'M3 13.5c0-2 2.2-3.2 5-3.2s5 1.2 5 3.2';
  /** 放大镜（圆 + 手柄）—— 搜索框左侧 */
  static readonly SEARCH: string =
    'M2.8 7a4.2 4.2 0 1 0 8.4 0a4.2 4.2 0 1 0-8.4 0M10.2 10.2l3 3';
  /** 扫码取景框（四角 + 中线）—— 首页顶栏与宫格「扫码签到」 */
  static readonly SCAN: string =
    'M1.5 5V1.5H5M11 1.5h3.5V5M14.5 11v3.5H11M5 14.5H1.5V11M1.5 8h13';
  /** 加号 —— 宫格「发布活动」 */
  static readonly PLUS: string = 'M8 3v10M3 8h10';
  /** 消息气泡 —— 首页顶栏（设计稿 15px 版） */
  static readonly BUBBLE: string = 'M2 3.5h12v8H7l-3 2.5V11.5H2z';
  /** 消息气泡 —— 宫格「发布求助」（设计稿 17px 版，比顶栏那颗略扁） */
  static readonly CHAT: string = 'M2 3.5h12v7H7l-3 2.5V10.5H2z';
  /** 三横线 —— 宫格「求助大厅」 */
  static readonly LIST_H: string = 'M2.5 4.5h11M2.5 8h11M2.5 11.5h7';
  /**
   * 齿轮（「我的」顶栏设置）—— 中圆 + 四向刻度，照设计稿 16×16 线性原路径。
   * 圆直接写弧线命令而不用 `IconGeom.circle`：`LinePath` 的静态字段初始化先于
   * `IconGeom` 类声明执行，跨类引用会在模块加载期踩 TDZ。
   */
  static readonly GEAR: string =
    'M5.6 8A2.4 2.4 0 1 0 10.4 8A2.4 2.4 0 1 0 5.6 8Z' +
    'M8 1.5v1.6M8 12.9v1.6M1.5 8h1.6M12.9 8h1.6';
  /** 时钟（报名卡时间行）—— 外圆 + 指针，照设计稿 16×16 线性原路径 */
  static readonly CLOCK: string =
    'M2.4 8A5.6 5.6 0 1 0 13.6 8A5.6 5.6 0 1 0 2.4 8Z' +
    'M8 5v3.2l2.2 1.3';
  /** 相机（扫码页顶栏右上）—— 机身圆角矩形 + 提手 + 镜头圆，弧线直接写 commands（避开 IconGeom TDZ） */
  static readonly CAMERA: string =
    'M2 6.2A1.5 1.5 0 0 1 3.5 4.7H5L6 3H10L11 4.7H12.5A1.5 1.5 0 0 1 14 6.2V11.4A1.5 1.5 0 0 1 12.5 12.9H3.5A1.5 1.5 0 0 1 2 11.4Z' +
    'M5.8 8.6A2.2 2.2 0 1 0 10.2 8.6A2.2 2.2 0 1 0 5.8 8.6Z';
  /** 导航箭头（活动地址尾部，预留地图导航入口）—— 参考通行「➤」造型 */
  static readonly NAV: string = 'M2.5 8.5L13.5 3L10 13.5L7.8 9.2L2.5 8.5Z';
  /** 电话（发布者卡「活动联系人」行）—— 听筒 */
  static readonly PHONE: string =
    'M3 2.8H5.2L6.2 5.4L4.8 6.7C5.5 8.4 7.6 10.5 9.3 11.2L10.6 9.8L13.2 10.8V13' +
    'C13.2 13.7 12.6 14.2 11.9 14.1C6.9 13.5 2.5 9.1 1.9 4.1C1.8 3.4 2.3 2.8 3 2.8Z';
  /** 定位图钉（表单地点行的「地图选点」入口）—— 外轮廓 + 内孔，弧线直接写 commands */
  static readonly PIN: string =
    'M8 1.8A4.2 4.2 0 0 1 12.2 6C12.2 9.5 8 14 8 14S3.8 9.5 3.8 6A4.2 4.2 0 0 1 8 1.8Z' +
    'M8 7.4A1.6 1.6 0 1 0 8 4.2A1.6 1.6 0 1 0 8 7.4Z';
  /**
   * 分享（右上一个圆 + 右下两个圆 + 两条连线）—— 活动详情页封面右上角。
   * 三个圆照设计稿是 `fill:none` 的描边圆，所以用 `IconGeom.circle` 同款的
   * 「两段半圆弧拼整圆」写法把它们写进 commands，而不是用 `Shape` 的 `Circle` 子组件
   * （那个的 fill/stroke 是 API 26 才有的，本工程 compatSdk=24，实机画不出来）。
   */
  static readonly SHARE: string =
    'M10.4 4A1.6 1.6 0 1 0 13.6 4A1.6 1.6 0 1 0 10.4 4Z' +
    'M10.4 12A1.6 1.6 0 1 0 13.6 12A1.6 1.6 0 1 0 10.4 12Z' +
    'M2.4 8A1.6 1.6 0 1 0 5.6 8A1.6 1.6 0 1 0 2.4 8Z' +
    'M10.5 4.8L5.5 7.3M10.5 11.2L5.5 8.8';
}

/**
 * MarkPath —— 16×16 的**填充型**路径，只服务「应用标识」这一处。
 * 单独列一类是为了不把填充路径混进 `LinePath`（那个类全是描边路径）。
 */
export class MarkPath {
  /** 应用标识里的心形（设计稿原路径，`A` 的压缩旗标已展开成空格分隔） */
  static readonly HEART: string =
    'M8 14.2S1.8 9.9 1.8 5.9A3.5 3.5 0 0 1 8 3.4a3.5 3.5 0 0 1 6.2 2.5c0 4-6.2 8.3-6.2 8.3z';

  /**
   * 应用标识里的双叶手 —— 与桌面图标 `foreground.png` 同源的「捧」形：
   * 掌端在内下、叶尖朝外上，心尖从两叶之间垂下。
   * 胶囊形用两段半圆弧 `A` 拼（扫过外侧鼓包点的方向已逐弧验算，sweep=0）。
   */
  static readonly LEAF_LEFT: string =
    'M7.37 12.61 L2.77 10.41 A1.1 1.1 0 0 0 1.83 12.39 L6.43 14.59 A1.1 1.1 0 0 0 7.37 12.61 Z';
  static readonly LEAF_RIGHT: string =
    'M9.57 14.59 L14.17 12.39 A1.1 1.1 0 0 0 13.23 10.41 L8.63 12.61 A1.1 1.1 0 0 0 9.57 14.59 Z';
}

/**
 * AgentPath —— 「志愿小鸿」机器人标识的几何（16×16，**填充型**）。
 *
 * 【2026-09-23 用户反馈】原来的「圈 + 加号」记号看不出是「小鸿」，
 *   希望是小机器人。取「方头 + 天线 + 两点眼 + 一字嘴」——
 *   这是机器人在 13vp 圆内唯一还能一眼认出的特征组合，再加细节就会糊成一团。
 *
 * 【为什么用填充而不是描边】导航栏里 小鸿 只有 22vp，圆内可用区约 13vp。
 *   描边型在这里五官会糊（光描边就占 1.3/16）。实心色块对比度最高，
 *   而且眼睛/嘴用「把圆底色画在白色头上」的做法，不依赖 fill-rule 绕向技巧。
 *
 * 注：路径单位与 `VB_LINE` 一致（都是 px 字符串的 16 坐标系），
 *   所以这些字符串可以直接原样粘进 SVG 的 `<path d="...">` 做预览。
 */
export class AgentPath {
  /** 天线小球：圆心 (8,3) 半径 1.05 的实心圆 */
  static readonly ANTENNA_BALL: string =
    'M6.95 3A1.05 1.05 0 1 0 9.05 3A1.05 1.05 0 1 0 6.95 3Z';
  /** 天线杆 */
  static readonly ANTENNA_STEM: string = 'M7.55 3.7H8.45V5.7H7.55Z';
  /** 头：圆角方（x 3.4~12.6，y 5.7~14.1，圆角 2.3） */
  static readonly HEAD: string =
    'M5.7 5.7H10.3A2.3 2.3 0 0 1 12.6 8V11.8A2.3 2.3 0 0 1 10.3 14.1H5.7A2.3 2.3 0 0 1 3.4 11.8V8A2.3 2.3 0 0 1 5.7 5.7Z';
  /** 左眼：(6.35, 9.6) 半径 1.05 —— 填圆底色，视觉上就是挖空 */
  static readonly EYE_LEFT: string =
    'M5.3 9.6A1.05 1.05 0 1 0 7.4 9.6A1.05 1.05 0 1 0 5.3 9.6Z';
  /** 右眼：(9.65, 9.6) 半径 1.05 */
  static readonly EYE_RIGHT: string =
    'M8.6 9.6A1.05 1.05 0 1 0 10.7 9.6A1.05 1.05 0 1 0 8.6 9.6Z';
  /** 嘴：一根圆头短横（2.2 × 0.9），圆心线 y=12.35 */
  static readonly MOUTH: string =
    'M7.35 11.9H8.65A0.45 0.45 0 0 1 9.1 12.35A0.45 0.45 0 0 1 8.65 12.8H7.35' +
    'A0.45 0.45 0 0 1 6.9 12.35A0.45 0.45 0 0 1 7.35 11.9Z';
  /**
   * 输入条发送键的「小飞机」——**设计稿原路径**（`UI界面稿.html` 小鸿屏）：
   * `M2 13.5L14 8 2 2.5 4 8z`，实心三角 + 横切，比 `IconPath.SEND`（24 坐标系的
   * 经典纸飞机）更贴设计稿，而且它本来就是 16 坐标系，直接塞进 `VB_LINE`。
   */
  static readonly SEND_PLANE: string = 'M2 13.5L14 8 2 2.5 4 8z';
}

/**
 * IconGeom —— 用 `Path` 的 SVG 弧线命令拼出圆 / 圆环。
 *
 * 【为什么不用 `Shape` 里的 `Circle()` 子组件】（U5 实测结论，踩过一次）
 *   编译器报：`The 'fill' API is supported since SDK version 26.0.0.
 *   However, the current compatible SDK version is 6.1.1(24).`
 *   —— `Circle` 的 `fill` / `stroke` 是 **API 26** 才有的，本工程 compatibleSdkVersion
 *   是 24，实机上会画不出描边。而同样写在 `Path` 上的 `fill` / `stroke` 从旧版本就有，零告警。
 *   顺带解决了另一个隐患：`Circle` 子组件在 `Shape` 里的 `position()` 行为不确定，
 *   而弧线路径把圆心**直接编码进坐标**，不依赖任何布局属性。
 *
 * 【圆心路径的写法】两段半圆弧拼一个整圆（SVG 通行写法）：
 *   M (cx-r) cy  A r r 0 1 0 (cx+r) cy  A r r 0 1 0 (cx-r) cy  Z
 *   `A rx ry x轴旋转 大弧标志 扫描方向 终点x 终点y`
 */
export class IconGeom {
  /** 生成圆心 (cx,cy)、半径 r 的整圆路径（坐标系随调用方的 viewPort） */
  static circle(cx: number, cy: number, r: number): string {
    const x1: number = cx - r;
    const x2: number = cx + r;
    return `M${x1} ${cy}A${r} ${r} 0 1 0 ${x2} ${cy}A${r} ${r} 0 1 0 ${x1} ${cy}Z`;
  }
}

/**
 * 描边线宽（16 坐标系）。**与设计稿一致：1.3**
 *
 * 【2026-09-23 第二次真机目视：用户反馈「这些图标会不会加粗得太严重了」】
 *   此前按「高刷屏上略粗一点更稳」取了 1.5（比设计稿粗 15%）。
 *   用 `.workbuddy/tmp/nav_cmp.png`（设计稿 vs 实机底部导航同尺度放大对比）复核后
 *   确认实机确实偏重 —— 尤其小半径圆（互助 r=1.7/2.1、我的头像 r=2.5），
 *   1.5 的描边会占到小圆直径的 44%，糊成一坨。改回设计稿原值 1.3。
 *   若后续仍偏重，下一档是 1.15~1.2；白底彩块上的字形（宫格）设计稿用的是
 *   1.5~1.9，若这里调薄后白字显细，再拆一个 onColor 专用线宽。
 *
 * **必须写成 px 字符串**：坐标系的单位是 px（视口 VB_LINE = '16px'），
 * 裸数字会被按默认单位 vp 解析（官方 Path 文档：默认单位 vp），
 * 在 density=2 的机器上等于 3 个坐标单位，描边会粗一倍。
 */
const LINE_STROKE: string = '1.3px';

/**
 * lineIcon —— 线性图标（描边，随 size 等比缩放）
 *
 * `Shape` 的 viewPort 会把整条路径等比缩放到 `size`，
 * 所以路径一律按 16×16 坐标系来写。
 */
@Builder
export function lineIcon(path: string, size: number, color: ResourceColor) {
  Shape() {
    Path()
      .width(VB_LINE)
      .height(VB_LINE)
      .commands(path)
      .fill(Color.Transparent)
      .stroke(color)
      .strokeWidth(LINE_STROKE)
  }
  .viewPort({ x: 0, y: 0, width: VB_LINE, height: VB_LINE })
  .width(size)
  .height(size)
}

/** 底部导航项编号（与 Index.ets 里 5 个 Tab 的顺序严格一致） */
export class NavIconId {
  static readonly HOME: number = 0;
  static readonly VOLUNTEER: number = 1;
  static readonly AGENT: number = 2;
  static readonly HELP: number = 3;
  static readonly MINE: number = 4;
}

/**
 * 小鸿标志：**橙色实心圆 + 白色小机器人**（5 项导航里唯一的实心项）。
 *
 * 2026-09-23 改版：原设计稿是「圈 + 加号」，用户反馈看不出是「小鸿」，
 * 要求做成小机器人。几何见 `AgentPath`。因为它是标识型（不是线性图标），
 * 所以不受 `LINE_STROKE` 影响 —— 全部是填充路径。
 *
 * 【U13 走查调整】① 机器人占比 0.75 → 0.84（用户反馈「图标太小体现不出小鸿」）；
 * ② 加选中态：圆底切 primary（更深一档的橙）；眼睛/嘴的「挖空色」必须同步跟圆底
 * ——挖空就是拿圆底色填的，不同步会在深橙圆上留下浅橙五官。
 */
@Builder
export function agentMark(size: number, selected: boolean) {
  Stack() {
    Shape() {
      // 天线 2 段 + 头：白色实心
      Path()
        .width(VB_LINE)
        .height(VB_LINE)
        .commands(AgentPath.ANTENNA_BALL)
        .fill(AppTheme.textOnPrimary)
        .stroke(Color.Transparent)
      Path()
        .width(VB_LINE)
        .height(VB_LINE)
        .commands(AgentPath.ANTENNA_STEM)
        .fill(AppTheme.textOnPrimary)
        .stroke(Color.Transparent)
      Path()
        .width(VB_LINE)
        .height(VB_LINE)
        .commands(AgentPath.HEAD)
        .fill(AppTheme.textOnPrimary)
        .stroke(Color.Transparent)
      // 两点眼 + 一字嘴：填**圆底色**（= 视觉挖空）——必须跟圆底同色
      Path()
        .width(VB_LINE)
        .height(VB_LINE)
        .commands(AgentPath.EYE_LEFT)
        .fill(selected ? AppTheme.primary : AppTheme.iconGradOrangeStart)
        .stroke(Color.Transparent)
      Path()
        .width(VB_LINE)
        .height(VB_LINE)
        .commands(AgentPath.EYE_RIGHT)
        .fill(selected ? AppTheme.primary : AppTheme.iconGradOrangeStart)
        .stroke(Color.Transparent)
      Path()
        .width(VB_LINE)
        .height(VB_LINE)
        .commands(AgentPath.MOUTH)
        .fill(selected ? AppTheme.primary : AppTheme.iconGradOrangeStart)
        .stroke(Color.Transparent)
    }
    .viewPort({ x: 0, y: 0, width: VB_LINE, height: VB_LINE })
    .width(size * 0.84)
    .height(size * 0.84)
    .fill(AppTheme.textOnPrimary)
    // 不写这句 = 默认黑描边把白色机器人盖成一坨黑（见 appIcon 的坑记录）
    .stroke(Color.Transparent)
  }
  .width(size)
  .height(size)
  .borderRadius(size / 2)
  .backgroundColor(selected ? AppTheme.primary : AppTheme.iconGradOrangeStart)
}

/**
 * 小鸿输入条的发送键：橙色实心圆 + 白色小飞机。
 * 圆底用 `primary`（#FF6B2C）而不是 `agentMark` 的 #FF8A4C —— 照设计稿：
 * 小鸿标识是「图标色」，可点的按钮是「主色」，两者不是同一个橙。
 */
@Builder
export function agentSendIcon(size: number, glyph: number) {
  Stack() {
    Shape() {
      Path()
        .width(VB_LINE)
        .height(VB_LINE)
        .commands(AgentPath.SEND_PLANE)
        .fill(AppTheme.textOnPrimary)
        // 不写这句 = 默认黑描边把白色飞机盖黑
        .stroke(Color.Transparent)
    }
    .viewPort({ x: 0, y: 0, width: VB_LINE, height: VB_LINE })
    .width(glyph)
    .height(glyph)
    .fill(AppTheme.textOnPrimary)
    .stroke(Color.Transparent)
  }
  .width(size)
  .height(size)
  .borderRadius(size / 2)
  .backgroundColor(AppTheme.primary)
}

/** 底部导航 · 互助：两个描边人像（头是圆环，肩是弧线） */
@Builder
export function navHelpIcon(size: number, color: ResourceColor) {
  Shape() {
    Path()
      .width(VB_LINE)
      .height(VB_LINE)
      .commands(IconGeom.circle(5.8, 5.5, 2.1))
      .fill(Color.Transparent)
      .stroke(color)
      .strokeWidth(LINE_STROKE)
    Path()
      .width(VB_LINE)
      .height(VB_LINE)
      .commands(LinePath.NAV_HELP_SHOULDER)
      .fill(Color.Transparent)
      .stroke(color)
      .strokeWidth(LINE_STROKE)
    Path()
      .width(VB_LINE)
      .height(VB_LINE)
      .commands(IconGeom.circle(11, 6.3, 1.7))
      .fill(Color.Transparent)
      .stroke(color)
      .strokeWidth(LINE_STROKE)
  }
  .viewPort({ x: 0, y: 0, width: VB_LINE, height: VB_LINE })
  .width(size)
  .height(size)
}

/**
 * 线性人像（头 + 肩）。
 * 输入框前缀图标（14vp）用 16×16 坐标系缩放；比新增一个独立路径更省事，
 * 而且能保证「我的」Tab 与表单里的人像永远长一样。
 */
@Builder
export function personLineIcon(size: number, color: ResourceColor) {
  Shape() {
    Path()
      .width(VB_LINE)
      .height(VB_LINE)
      .commands(IconGeom.circle(8, 5.3, 2.5))
      .fill(Color.Transparent)
      .stroke(color)
      .strokeWidth(LINE_STROKE)
    Path()
      .width(VB_LINE)
      .height(VB_LINE)
      .commands(LinePath.PERSON_SHOULDER)
      .fill(Color.Transparent)
      .stroke(color)
      .strokeWidth(LINE_STROKE)
  }
  .viewPort({ x: 0, y: 0, width: VB_LINE, height: VB_LINE })
  .width(size)
  .height(size)
}

/** 底部导航 · 我的：一个描边人像（与输入框的 `personLineIcon` 同一形状，尺寸不同） */
@Builder
export function navMineIcon(size: number, color: ResourceColor) {
  personLineIcon(size, color)
}

/**
 * 小号勾（协议勾选框用）。
 * 单独一个 Builder 是因为 `lineIcon` 把线宽写死成 1.5：13vp 的框里塞 8vp 的勾，
 * 缩放后实际只有 0.75vp，浅色模式下一眼看不见。这里把 16 坐标系里的线宽加到 2.4，
 * 缩放 0.5 倍后正好 1.2vp（= 设计稿的 2.4 在 8px 下的效果）。同样必须是 px 字符串。
 */
@Builder
export function checkMark(size: number, color: ResourceColor) {
  Shape() {
    Path()
      .width(VB_LINE)
      .height(VB_LINE)
      .commands(LinePath.CHECK)
      .fill(Color.Transparent)
      .stroke(color)
      .strokeWidth('2.4px')
  }
  .viewPort({ x: 0, y: 0, width: VB_LINE, height: VB_LINE })
  .width(size)
  .height(size)
}

/**
 * 应用标识 —— 与桌面图标完全同源：橙渐变圆角方块 + 白心 + 双绿叶手（捧）。
 * 启动页 86vp/26 圆角，登录页 34vp/11 圆角，证书页 22vp/8 圆角，几何值全部走参数。
 * 渐变方向照 `background.png` 实测采样：右上浅（primary_gradient_start）
 * → 左下深（primary），即 angle 135、起点色 gradient_start。
 * 叶用 accent 绿（互助域身份色，与图标的绿叶手同一色）。
 */
@Builder
export function appMark(box: number, radius: number, glyph: number) {
  Stack() {
    // 双叶手：先画，被心压住内端（真图标里叶尖朝外上、完整可见）
    Shape() {
      Path()
        .width(VB_LINE)
        .height(VB_LINE)
        .commands(MarkPath.LEAF_LEFT)
        .fill(AppTheme.accent)
        .stroke(Color.Transparent)
      Path()
        .width(VB_LINE)
        .height(VB_LINE)
        .commands(MarkPath.LEAF_RIGHT)
        .fill(AppTheme.accent)
        .stroke(Color.Transparent)
    }
    .viewPort({ x: 0, y: 0, width: VB_LINE, height: VB_LINE })
    .width(glyph)
    .height(glyph)

    Shape() {
      Path()
        .width(VB_LINE)
        .height(VB_LINE)
        .commands(MarkPath.HEART)
        .fill(AppTheme.textOnPrimary)
        // 不写这句 = 默认黑描边把白心盖黑
        .stroke(Color.Transparent)
    }
    .viewPort({ x: 0, y: 0, width: VB_LINE, height: VB_LINE })
    .width(glyph)
    .height(glyph)
    .fill(AppTheme.textOnPrimary)
    .stroke(Color.Transparent)
  }
  .width(box)
  .height(box)
  .borderRadius(radius)
  .linearGradient({
    angle: 135,
    colors: [[AppTheme.primaryGradientStart, 0], [AppTheme.primary, 1]]
  })
}

/**
 * navIcon —— 底部导航图标分发器。
 * 颜色由调用方给：选中传 AppTheme.primary，未选中传 AppTheme.textHint。
 * 第 3 项「小鸿」是实心橙圆：selected 时圆底切 primary 加深一档，体现选中反馈。
 *
 * ⚠️ selected 必须由调用方显式传入（见 Index.tabItem 的双分支写法）：
 * 嵌套 @Builder 按值传参，参数变化不触发本 Builder 重绘。
 */
@Builder
export function navIcon(id: number, size: number, color: ResourceColor, selected: boolean) {
  if (id === NavIconId.AGENT) {
    agentMark(size, selected)
  } else if (id === NavIconId.HELP) {
    navHelpIcon(size, color)
  } else if (id === NavIconId.MINE) {
    navMineIcon(size, color)
  } else if (id === NavIconId.VOLUNTEER) {
    lineIcon(LinePath.NAV_VOLUNTEER, size, color)
  } else {
    lineIcon(LinePath.NAV_HOME, size, color)
  }
}
