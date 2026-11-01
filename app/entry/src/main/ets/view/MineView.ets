import { AppTheme } from '../common/AppTheme';
import { appIcon, IconPath, lineIcon, LinePath, personLineIcon, NavIconId } from '../common/AppIcon';
import { User } from '../model/User';
import { Signup } from '../model/Signup';
import { MineService } from '../service/MineService';
import { HelpService } from '../service/HelpService';
import { AuthService } from '../service/AuthService';
import { LoadingOverlay } from '../components/LoadingOverlay';

/** 头像直径 / 宫格装饰色块边长 / 勋章圆直径 —— 设计稿一次性几何值 1:1 取 vp */
const AVATAR: number = 44;
const GRID_BLOCK: number = 26;
const MEDAL_SIZE: number = 34;

/** 宫格槽位编号 —— 与 gridCell() 里的调用顺序严格一致 */
class GridSlot {
  static readonly SIGNUP: number = 0;
  static readonly HOURS: number = 1;
  static readonly CERT: number = 2;
  static readonly HELP: number = 3;
}

/**
 * MineView —— 我的（Tab 5）
 *
 * 版式照 `UI\鸿志愿_互助大厅_消息中心_我的_界面稿.png`，自上而下：
 *   ① 顶栏：右侧三颗线性图标（扫码 / 消息[带未读红点] / 设置），无页面标题
 *   ② 资料行：灰底圆头像 + 姓名 + 「学号 · 学院」 + 绿色「已认证」
 *   ③ 深色数据卡（#3A2A12）：志愿信用分大数字 + 白底「查看明细」+ 累计时长 / 公益积分
 *   ④ 2×2 宫格：我的报名 / 我的时长 / 电子证书 / 我的求助（标题 + 副文案 + 装饰色块）
 *   ⑤ 勋章成就卡：3 枚勋章圆 + 「+2」
 *
 * 【为什么「我的求助」跳 Tab 而不开新页】互助模块没有独立的列表页，
 *   直接切到互助 Tab 复用大厅 —— 与首页「求助大厅」入口同一策略（onSwitchTab 注入）。
 */
@Component
export struct MineView {
  /** 由 Index 注入：宫格「我的求助」要切到互助 Tab */
  onSwitchTab: (index: number) => void = (index: number) => {
  };

  @State loading: boolean = true;
  /** 消息未读数（顶栏气泡红点） */
  @State unreadTotal: number = 0;
  /** 用户资料（@State：设置页改完资料靠 @Watch 信号重拉后重绘） */
  @State user: User = new User();
  /**
   * 资料变更信号 —— 设置页保存成功后 AppStorage bump 该值。
   * 本页是 Tabs 内组件（非 @Entry），返回时 aboutToAppear 不会再触发，
   * 只能靠 @StorageProp + @Watch 跨组件通知刷新。
   */
  @StorageProp('userProfileTick') @Watch('onProfileTick') profileTick: number = 0;

  /** 宫格副文案要用的统计值 */
  private activeSignups: number = 0;
  private helpPublished: number = 0;
  private helpAccepted: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  /** 设置页改完资料 → 信号触发：只重拉用户（报名/互助计数没变，不发多余请求） */
  onProfileTick(): void {
    if (this.profileTick > 0) {
      this.refreshUser();
    }
  }

  private async refreshUser(): Promise<void> {
    try {
      const u: User = await MineService.profile();
      this.user = u;
    } catch (err) {
      // 拉取失败保持现值
    }
  }

  private async load(): Promise<void> {
    try {
      const u: User = await MineService.profile();
      const signs: Signup[] = await MineService.signups();
      const helps: number[] = await HelpService.counts();
      const unread: number = await MineService.unread('');
      this.user = u;
      for (let i = 0; i < signs.length; i++) {
        if (signs[i].status === 'signed_up' || signs[i].status === 'checked_in') {
          this.activeSignups = this.activeSignups + 1;
        }
      }
      this.helpPublished = helps[0];
      this.helpAccepted = helps[1];
      this.unreadTotal = unread;
    } catch (err) {
      // 拉取失败保持骨架
    }
    this.loading = false;
  }

  // ==================== 导航 ====================

  private goto(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: url });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  private toast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      // toast 失败不影响主流程
    }
  }

  private onTopIconTap(slot: number): void {
    if (slot === 0) {
      this.goto('pages/ScanSignInPage');
      return;
    }
    if (slot === 1) {
      this.goto('pages/MessagesPage');
      return;
    }
    if (slot === 2) {
      this.goto('pages/SettingsPage');
      return;
    }
  }

  private onGridTap(slot: number): void {
    if (slot === GridSlot.SIGNUP) {
      this.goto('pages/MySignupsPage');
    } else if (slot === GridSlot.HOURS) {
      this.goto('pages/MyHoursPage');
    } else if (slot === GridSlot.CERT) {
      this.goto('pages/CertificatePage');
    } else {
      this.onSwitchTab(NavIconId.HELP);
    }
  }

  // ==================== 局部 UI ====================

  /**
   * ① 顶栏右侧三颗线性图标（扫码 / 消息+红点 / 设置）。
   * 三槽统一 32×32 容器 + 22 图标（与首页顶栏同量级）：之前气泡带 28 容器、
   * 另两颗是裸图标，占位不一致导致垂直居中后不对齐（U13 走查用户反馈）。
   * 红点固定贴容器内右上角，不再用负 margin 顶出界。
   */
  @Builder
  topIcon(slot: number) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        lineIcon(slot === 0 ? LinePath.SCAN : (slot === 1 ? LinePath.BUBBLE : LinePath.GEAR),
          22, AppTheme.textSecondary)
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      if (slot === 1 && this.unreadTotal > 0) {
        Row()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(AppTheme.badgeRed)
          .margin({ top: 3, right: 3 })
      }
    }
    .width(32)
    .height(32)
  }

  @Builder
  topBar() {
    Row() {
      Blank()
      Row() {
        this.topIcon(0)
      }
      .margin({ right: 10 })
      .onClick(() => {
        this.onTopIconTap(0);
      })

      Row() {
        this.topIcon(1)
      }
      .margin({ right: 10 })
      .onClick(() => {
        this.onTopIconTap(1);
      })

      Row() {
        this.topIcon(2)
      }
      .onClick(() => {
        this.onTopIconTap(2);
      })
    }
    .width('100%')
    .height(40)
    .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 10 })
    .alignItems(VerticalAlign.Center)
  }

  /** ② 资料行 */
  @Builder
  profileRow() {
    Row() {
      Row() {
        personLineIcon(22, AppTheme.textHint)
      }
      .width(AVATAR)
      .height(AVATAR)
      .borderRadius(AVATAR / 2)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.fillGray)

      Column() {
        Text(this.user.name)
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
        Text(this.user.studentNo + ' · ' + this.user.college)
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10 })

      Text($r('app.string.mine_verified'))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.accent)
        .padding({ left: 7, right: 7, top: 2, bottom: 2 })
        .backgroundColor(AppTheme.accentLight)
        .borderRadius(9)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 12 })
    .onClick(() => {
      // 资料行可点 → 设置页（改资料/退出登录的正式入口，与顶栏齿轮等价）
      this.goto('pages/SettingsPage');
    })
  }

  /** ③ 深色数据卡的数字格 */
  @Builder
  darkCell(label: Resource, value: string, unit: Resource) {
    Column() {
      Text(label)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.cardLabelTan)
      Text() {
        Span(value + ' ')
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textOnDark)
        Span(unit)
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.cardLabelTan)
      }
      .margin({ top: 3 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  /** ③ 深色数据卡 */
  @Builder
  darkCard() {
    Column() {
      Row() {
        Column() {
          Text($r('app.string.mine_credit_prefix'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.cardLabelTan)
          Text(this.user.creditScore.toString())
            .fontSize(AppTheme.fontNumberMd)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textOnDark)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text($r('app.string.mine_view_detail'))
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.cardDarkEnd)
          .padding({ left: 11, right: 11, top: 5, bottom: 5 })
          .backgroundColor(AppTheme.surface)
          .borderRadius(12)
          .onClick(() => {
            this.goto('pages/MyHoursPage');
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row()
        .width('100%')
        .height(AppTheme.dividerHeight)
        .backgroundColor(AppTheme.cardDarkDivider)
        .margin({ top: 12, bottom: 12 })

      Row() {
        this.darkCell($r('app.string.mine_total_hours'), this.user.totalHours.toString(), $r('app.string.common_unit_hour'))
        this.darkCell($r('app.string.mine_point'), this.user.point.toString(), $r('app.string.common_unit_point'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(AppTheme.cardDarkEnd)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 12 })
  }

  /** ④ 宫格副文案（各格数据形状不同，逐格拼 Span，$r 不参与拼接；间距写在 Builder 内部） */
  @Builder
  gridSub(slot: number) {
    if (slot === GridSlot.SIGNUP) {
      Text($r('app.string.mine_signup_active_count', this.activeSignups))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)
        .margin({ top: 3 })
    } else if (slot === GridSlot.HOURS) {
      Text() {
        Span(this.user.totalHours.toString() + ' ')
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
        Span($r('app.string.common_unit_hour'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
        Span($r('app.string.mine_sub_detail'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
      }
      .margin({ top: 3 })
    } else if (slot === GridSlot.CERT) {
      Text($r('app.string.mine_cert_count', 1))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)
        .margin({ top: 3 })
    } else {
      Text() {
        Span($r('app.string.mine_help_pub'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
        Span(' ' + this.helpPublished.toString() + ' · ')
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
        Span($r('app.string.mine_help_order'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
        Span(' ' + this.helpAccepted.toString())
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
      }
      .margin({ top: 3 })
    }
  }

  /** 宫格底色：按「颜色语义」重排 —— 橙=报名动作 / 蓝=时长数据 / 黄=证书荣誉 / 绿=互助域 */
  private gridBlockColor(slot: number): Resource {
    if (slot === GridSlot.SIGNUP) {
      return AppTheme.orangeTint;
    }
    if (slot === GridSlot.HOURS) {
      return AppTheme.blueLight;
    }
    if (slot === GridSlot.CERT) {
      return AppTheme.yellowLight;
    }
    return AppTheme.accentLight;
  }

  /** 宫格图标：浅 tint 底 + 同语调图标（替换 U13 的纯色块——用户反馈色块填充太丑） */
  @Builder
  gridIcon(slot: number) {
    if (slot === GridSlot.SIGNUP) {
      lineIcon(LinePath.CHECK, 13, AppTheme.primary)
    } else if (slot === GridSlot.HOURS) {
      lineIcon(LinePath.CLOCK, 13, AppTheme.ringBlue)
    } else if (slot === GridSlot.CERT) {
      appIcon(IconPath.CERTIFICATE, 13, AppTheme.yellowDeep)
    } else {
      lineIcon(LinePath.NAV_HELP_SHOULDER, 13, AppTheme.accent)
    }
  }

  private gridTitle(slot: number): Resource {
    if (slot === GridSlot.SIGNUP) {
      return $r('app.string.mine_my_signup');
    }
    if (slot === GridSlot.HOURS) {
      return $r('app.string.mine_my_hours');
    }
    if (slot === GridSlot.CERT) {
      return $r('app.string.mine_certificate');
    }
    return $r('app.string.mine_my_help');
  }

  @Builder
  gridCell(slot: number) {
    Column() {
      Text(this.gridTitle(slot))
        .fontSize(AppTheme.fontSecondary)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)

      this.gridSub(slot)

      Row() {
        this.gridIcon(slot)
      }
      .width(GRID_BLOCK)
      .height(GRID_BLOCK)
      .borderRadius(9)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.gridBlockColor(slot))
      .margin({ top: 9 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(12)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .onClick(() => {
      this.onGridTap(slot);
    })
  }

  /** 我的发布入口卡：发布者回看活动/求助，活动详情里有签到二维码 */
  @Builder
  publishEntry() {
    Row() {
      Row() {
        appIcon(IconPath.LIST, 16, AppTheme.primary)
      }
      .width(38)
      .height(38)
      .borderRadius(12)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.orangeTint)

      Column() {
        Text($r('app.string.mypub_entry_title'))
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
        Text($r('app.string.mypub_entry_sub'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 11 })

      appIcon(IconPath.CHEVRON_RIGHT, 13, AppTheme.textHint)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(13)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 9 })
    .onClick(() => {
      this.goto('pages/MyPublishPage');
    })
  }

  @Builder
  gridArea() {
    Row() {
      this.gridCell(GridSlot.SIGNUP)
      this.gridCell(GridSlot.HOURS)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ top: 12 })

    Row() {
      this.gridCell(GridSlot.CERT)
      this.gridCell(GridSlot.HELP)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ top: 9 })
  }

  /** ⑤ 单枚勋章圆 */
  @Builder
  medalCircle(bg: Resource, slot: number) {
    Row() {
      if (slot === 0) {
        appIcon(IconPath.HEART, 16, AppTheme.primary)
      } else if (slot === 1) {
        appIcon(IconPath.STAR, 16, AppTheme.accent)
      } else {
        appIcon(IconPath.CLOCK, 16, AppTheme.ringBlue)
      }
    }
    .width(MEDAL_SIZE)
    .height(MEDAL_SIZE)
    .borderRadius(MEDAL_SIZE / 2)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(bg)
  }

  @Builder
  medalCard() {
    Column() {
      Row() {
        Text($r('app.string.mine_medal'))
          .fontSize(AppTheme.fontSecondary)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)

        Text($r('app.string.mine_medal_count', 5))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textHint)
          .layoutWeight(1)
          .margin({ left: 6 })

        appIcon(IconPath.CHEVRON_RIGHT, 12, AppTheme.primary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        // ⚠️ medalCircle 是 @Builder，调用是语句不能链属性 → 间距包在 Row 上
        Row() {
          this.medalCircle(AppTheme.orangeTint, 0)
        }

        Row() {
          this.medalCircle(AppTheme.accentLight, 1)
        }
        .margin({ left: 12 })

        Row() {
          this.medalCircle(AppTheme.blueLight, 2)
        }
        .margin({ left: 12 })

        Row() {
          Text($r('app.string.mine_medal_more', 2))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textHint)
        }
        .width(MEDAL_SIZE)
        .height(MEDAL_SIZE)
        .borderRadius(MEDAL_SIZE / 2)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.fillGray)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 10 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
      .backgroundColor(AppTheme.surface)
      .borderRadius(AppTheme.cardRadius)
      .margin({ top: 12 })
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingOverlay({ text: $r('app.string.common_loading') })
      } else {
        Scroll() {
          Column() {
            this.topBar()
            this.profileRow()
            Column() {
              this.darkCard()
              this.gridArea()
              this.publishEntry()
              this.medalCard()
              Row()
                .width('100%')
                .height(16)
            }
            .width('100%')
            .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })
          }
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
