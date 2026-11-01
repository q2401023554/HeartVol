/**
 * AppTheme —— 全工程主题常量
 *
 * 【设计原则 R-2】本文件所有值都是对 U1 已定义资源（resources/base|dark/element/*.json）的引用。
 *   深色模式由系统按限定词目录自动切换，代码零改动。
 *   ⚠️ 任何情况下都不要在本文件写十六进制字面量 —— 那会让深色模式彻底失效。
 *
 * 【用法】
 *   .backgroundColor(AppTheme.surface)
 *   .fontSize(AppTheme.fontTitlePage)
 */
export class AppTheme {
  // ==================== 颜色 ====================

  /** 页面底色 #F5F6F7 / 深色 #121212 —— 靠它和白卡形成层次，几乎不用描边 */
  static readonly pageBackground: Resource = $r('app.color.page_background');
  /** 卡片、底部导航 纯白 / 深色 #1E1E1E */
  static readonly surface: Resource = $r('app.color.surface');
  /** 主色 #FF6B2C —— 唯一强调色：选中态、文字按钮、FAB、关键数字 */
  static readonly primary: Resource = $r('app.color.primary');
  /** 橙色渐变起 #FF8A4C */
  static readonly primaryGradientStart: Resource = $r('app.color.primary_gradient_start');
  /** 橙色渐变止 #FFA24D */
  static readonly primaryGradientEnd: Resource = $r('app.color.primary_gradient_end');
  /** 橙色浅底 #FFF1E8 —— 标签底、图标底 */
  static readonly primaryLight: Resource = $r('app.color.primary_light');
  /** 校园绿 #4D9B70 —— 成功、互助、正向状态 */
  static readonly accent: Resource = $r('app.color.accent');
  /** 绿色浅底 #EAF5EF */
  static readonly accentLight: Resource = $r('app.color.accent_light');

  /** 标题 / 正文 / 大数字 #1A1A1A */
  static readonly textPrimary: Resource = $r('app.color.text_primary');
  /** 副标题 / 说明 #8A8F99 */
  static readonly textSecondary: Resource = $r('app.color.text_secondary');
  /** 占位文字 / 时间戳 #B0B5BD */
  static readonly textHint: Resource = $r('app.color.text_hint');
  /** 实心橙底上的前景色（白） */
  static readonly textOnPrimary: Resource = $r('app.color.text_on_primary');
  /** 深色数据卡上的前景色（白） */
  static readonly textOnDark: Resource = $r('app.color.text_on_dark');

  /** 分割线 #EEF0F2 */
  static readonly divider: Resource = $r('app.color.divider');
  /** 浅灰底（次要按钮 / 输入框底 / 胶囊标签底）#F2F3F5 */
  static readonly fillGray: Resource = $r('app.color.fill_gray');
  /** 未读角标 #FF3B30 */
  static readonly badgeRed: Resource = $r('app.color.badge_red');
  /** 全屏遮罩（扫码页取景框外） */
  static readonly maskScrim: Resource = $r('app.color.mask_scrim');

  /** 数据环：橙 / 黄 / 蓝 */
  static readonly ringOrange: Resource = $r('app.color.ring_orange');
  static readonly ringYellow: Resource = $r('app.color.ring_yellow');
  static readonly ringBlue: Resource = $r('app.color.ring_blue');

  /** 补充浅底：蓝 / 黄 / 红（U4 加，配合 ToneColors 使用） */
  static readonly blueLight: Resource = $r('app.color.blue_light');
  static readonly yellowLight: Resource = $r('app.color.yellow_light');
  static readonly redLight: Resource = $r('app.color.red_light');
  /** 黄底上的深黄文字（浅色底对比度不够，浅色模式下半屏会看不清） */
  static readonly yellowDeep: Resource = $r('app.color.yellow_deep');

  /** 琥珀色实心图标底 #EF9F27 —— 首页宫格「求助大厅」用。
   *  宫格四色是设计稿**实心**取值（#FF8A4C / #4D9B70 / #4C8DFF / #EF9F27），
   *  与渐变起止色不同，所以单独出一个「实心」色口，别拿 gradEnd 硬凑。 */
  static readonly iconSolidYellow: Resource = $r('app.color.icon_solid_yellow');
  /** 比 primaryLight 更深的橙浅底 #FFE3D2 —— 橙色底纹（封面占位 / 强调块） */
  static readonly orangeTint: Resource = $r('app.color.orange_tint');

  /** 「我的」页顶部深色数据卡渐变 */
  static readonly cardDarkStart: Resource = $r('app.color.card_dark_start');
  static readonly cardDarkEnd: Resource = $r('app.color.card_dark_end');
  /** 深色数据卡上的标签字（浅棕 #E8D8BF，U11 加） */
  static readonly cardLabelTan: Resource = $r('app.color.card_label_tan');
  /** 深色数据卡内分割线 #5B4526（U11 加） */
  static readonly cardDarkDivider: Resource = $r('app.color.card_dark_divider');
  /** 扫码签到页深底 #1A1A1A（U12 加；该页恒深底，深浅色同值） */
  static readonly scanBg: Resource = $r('app.color.scan_bg');
  /** 小鸿主动气泡的柔和投影（G+） */
  static readonly bubbleShadow: Resource = $r('app.color.bubble_shadow');
  /** 扫码页深底上的卡片/按钮底 #2A2A2A（U12 加） */
  static readonly scanDarkCard: Resource = $r('app.color.scan_dark_card');
  /** 封面浮层深遮罩：约 32% 黑（U13 走查定稿；白字叠任何分类色封面都够对比，深浅色同值） */
  static readonly coverScrim: Resource = $r('app.color.cover_scrim');

  // ---- 大号彩色图标渐变（4 色，用于宫格 / 快捷入口 / 消息中心） ----
  static readonly iconGradOrangeStart: Resource = $r('app.color.icon_grad_orange_start');
  static readonly iconGradOrangeEnd: Resource = $r('app.color.icon_grad_orange_end');
  static readonly iconGradGreenStart: Resource = $r('app.color.icon_grad_green_start');
  static readonly iconGradGreenEnd: Resource = $r('app.color.icon_grad_green_end');
  static readonly iconGradBlueStart: Resource = $r('app.color.icon_grad_blue_start');
  static readonly iconGradBlueEnd: Resource = $r('app.color.icon_grad_blue_end');
  static readonly iconGradYellowStart: Resource = $r('app.color.icon_grad_yellow_start');
  static readonly iconGradYellowEnd: Resource = $r('app.color.icon_grad_yellow_end');

  // ==================== 尺寸 / 间距 ====================

  /** 页面水平留白 16vp */
  static readonly pagePaddingH: Resource = $r('app.float.page_padding_h');
  /** 卡片圆角 16vp */
  static readonly cardRadius: Resource = $r('app.float.card_radius');
  /** 小卡圆角 12vp */
  static readonly cardRadiusSmall: Resource = $r('app.float.card_radius_small');
  /** 卡片内边距 16vp */
  static readonly cardPadding: Resource = $r('app.float.card_padding');
  /** 小卡内边距 12vp */
  static readonly cardPaddingSmall: Resource = $r('app.float.card_padding_small');
  /** 卡片间距 12vp */
  static readonly cardGap: Resource = $r('app.float.card_gap');
  /** 大区块间距 16vp */
  static readonly sectionGap: Resource = $r('app.float.section_gap');

  /** 大号图标 48vp（列表项） */
  static readonly iconSizeLarge: Resource = $r('app.float.icon_size_large');
  /** 宫格图标 48vp（设计稿 HTML 规格为 40~48vp，取上限以贴近 PNG 实绘） */
  static readonly iconSizeGrid: Resource = $r('app.float.icon_size_grid');
  /** 底部导航图标 22vp */
  static readonly iconSizeNav: Resource = $r('app.float.icon_size_nav');
  /** 行内小图标 18vp */
  static readonly iconSizeSmall: Resource = $r('app.float.icon_size_small');

  /** 底部导航高 60vp */
  static readonly navBarHeight: Resource = $r('app.float.nav_bar_height');
  /** 主 / 次要按钮高 44vp */
  static readonly buttonHeight: Resource = $r('app.float.button_height');
  /** 全圆角胶囊半径 22vp —— 44vp 高按钮的一半，设计稿里所有主按钮都是全圆角 */
  static readonly pillRadius: Resource = $r('app.float.pill_radius');
  /** 表单输入框高 40vp（登录 / 注册 / 发布表单统一） */
  static readonly inputHeight: Resource = $r('app.float.input_height');
  /** 搜索框高 40vp */
  static readonly searchBarHeight: Resource = $r('app.float.search_bar_height');
  /** 分割线厚度 1vp */
  static readonly dividerHeight: Resource = $r('app.float.divider_height');

  /** 头像 56vp / 小头像 40vp */
  static readonly avatarSize: Resource = $r('app.float.avatar_size');
  static readonly avatarSizeSmall: Resource = $r('app.float.avatar_size_small');
  /** 活动封面高 180vp */
  static readonly coverHeight: Resource = $r('app.float.cover_height');

  // ==================== 字号（字重只用 400 / 500） ====================

  /** 页面主标题 20fp */
  static readonly fontTitlePage: Resource = $r('app.float.font_title_page');
  /** 区块标题 18fp */
  static readonly fontTitleSection: Resource = $r('app.float.font_title_section');
  /** 卡片标题 16fp */
  static readonly fontTitleCard: Resource = $r('app.float.font_title_card');
  /** 正文 15fp */
  static readonly fontBody: Resource = $r('app.float.font_body');
  /** 次要 13fp */
  static readonly fontSecondary: Resource = $r('app.float.font_secondary');
  /** 说明 12fp */
  static readonly fontCaption: Resource = $r('app.float.font_caption');
  /** 大数字 28fp / 中数字 22fp */
  static readonly fontNumberLg: Resource = $r('app.float.font_number_lg');
  static readonly fontNumberMd: Resource = $r('app.float.font_number_md');
  /** 角标数字 10fp（未读红点里的计数，U13 走查补档） */
  static readonly fontBadge: Resource = $r('app.float.font_badge');
}

/**
 * IconTone —— 图标底色语调。宫格、快捷入口、消息类型都从这里取。
 * 传字符串而不是直接传颜色，是为了让「分类 → 长什么样」只有一处定义。
 */
export class IconTone {
  static readonly ORANGE: string = 'orange';
  static readonly GREEN: string = 'green';
  static readonly BLUE: string = 'blue';
  static readonly YELLOW: string = 'yellow';
  static readonly GRAY: string = 'gray';
}

/** TagTone —— 标签语调，比 IconTone 多一个「警示红」 */
export class TagTone {
  static readonly ORANGE: string = 'orange';
  static readonly GREEN: string = 'green';
  static readonly BLUE: string = 'blue';
  static readonly YELLOW: string = 'yellow';
  static readonly GRAY: string = 'gray';
  static readonly RED: string = 'red';
}

/**
 * CardMode —— 列表卡片的形态。
 *
 * 用字符串常量而不是两个 boolean（`feature` + `compact`）：
 *   布尔组合会造出「既 feature 又 compact」这种不存在的状态，
 *   字符串只会取到三个合法值之一，读代码的人不用去猜优先级。
 */
export class CardMode {
  /** 列表横排卡：92 缩略图 + 标题 + 分类/状态标签 + 时间 + 时长 —— 志愿大厅 */
  static readonly LIST: string = 'list';
  /** 首页大卡：通栏封面 + 信息 —— 单独主推一场活动时用 */
  static readonly FEATURE: string = 'feature';
  /** 紧凑行：56 缩略图 + 标题 + 时间/时长/距离 + 尾部动作 —— 首页活动流 */
  static readonly COMPACT: string = 'compact';
}

/**
 * ToneColors —— 「语调 → 具体颜色」的唯一映射表。
 *
 * 四个取色口：
 *   gradStart/gradEnd —— 渐变（或纯色，起止同色）底，上面配白色图标
 *   soft              —— 浅底色（标签底、图标浅底）
 *   main              —— 实心主色（实心标签、强调点）
 *   onSoft            —— 浅底色上的文字/图标色
 */
export class ToneColors {
  /** 渐变起点 */
  static gradStart(tone: string): Resource {
    if (tone === IconTone.GREEN) {
      return AppTheme.iconGradGreenStart;
    }
    if (tone === IconTone.BLUE) {
      return AppTheme.iconGradBlueStart;
    }
    if (tone === IconTone.YELLOW) {
      return AppTheme.iconGradYellowStart;
    }
    if (tone === IconTone.GRAY) {
      return AppTheme.textHint;
    }
    if (tone === TagTone.RED) {
      return AppTheme.badgeRed;
    }
    return AppTheme.iconGradOrangeStart;
  }

  /** 渐变终点 */
  static gradEnd(tone: string): Resource {
    if (tone === IconTone.GREEN) {
      return AppTheme.iconGradGreenEnd;
    }
    if (tone === IconTone.BLUE) {
      return AppTheme.iconGradBlueEnd;
    }
    if (tone === IconTone.YELLOW) {
      return AppTheme.iconGradYellowEnd;
    }
    if (tone === IconTone.GRAY) {
      return AppTheme.textHint;
    }
    if (tone === TagTone.RED) {
      return AppTheme.badgeRed;
    }
    return AppTheme.iconGradOrangeEnd;
  }

  /** 浅底 */
  static soft(tone: string): Resource {
    if (tone === IconTone.GREEN) {
      return AppTheme.accentLight;
    }
    if (tone === IconTone.BLUE) {
      return AppTheme.blueLight;
    }
    if (tone === IconTone.YELLOW) {
      return AppTheme.yellowLight;
    }
    if (tone === TagTone.RED) {
      return AppTheme.redLight;
    }
    if (tone === IconTone.GRAY) {
      return AppTheme.fillGray;
    }
    return AppTheme.primaryLight;
  }

  /** 实心主色 */
  static main(tone: string): Resource {
    if (tone === IconTone.GREEN) {
      return AppTheme.accent;
    }
    if (tone === IconTone.BLUE) {
      return AppTheme.ringBlue;
    }
    if (tone === IconTone.YELLOW) {
      return AppTheme.ringYellow;
    }
    if (tone === TagTone.RED) {
      return AppTheme.badgeRed;
    }
    if (tone === IconTone.GRAY) {
      return AppTheme.textSecondary;
    }
    return AppTheme.primary;
  }

  /** 浅底上的前景色（文字 / 图标） */
  static onSoft(tone: string): Resource {
    if (tone === IconTone.GREEN) {
      return AppTheme.accent;
    }
    if (tone === IconTone.BLUE) {
      return AppTheme.ringBlue;
    }
    if (tone === IconTone.YELLOW) {
      return AppTheme.yellowDeep;
    }
    if (tone === TagTone.RED) {
      return AppTheme.badgeRed;
    }
    if (tone === IconTone.GRAY) {
      return AppTheme.textSecondary;
    }
    return AppTheme.primary;
  }
}
