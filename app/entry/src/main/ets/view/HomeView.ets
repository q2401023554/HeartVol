import { AppTheme, CardMode, IconTone } from '../common/AppTheme';
import { lineIcon, LinePath, NavIconId } from '../common/AppIcon';
import { DateFmt } from '../common/DateFmt';
import { RouteParams } from '../common/RouteParams';
import { Activity } from '../model/Activity';
import { HomeSummary } from '../model/HomeSummary';
import { HomeService } from '../service/HomeService';
import { SearchBar } from '../components/SearchBar';
import { SectionHeader } from '../components/SectionHeader';
import { ActivityCard } from '../components/ActivityCard';
import { GradientIcon } from '../components/GradientIcon';
import { LoadingOverlay } from '../components/LoadingOverlay';

/** 活动流最多显示几条（再多也没有人能一屏看完，剩下的去志愿大厅） */
const FEED_SIZE: number = 3;

/** 宫格槽位编号 —— 与 build() 里 4 个 gridItem 的顺序严格一致 */
class GridSlot {
  static readonly SCAN: number = 0;
  static readonly PUBLISH_ACTIVITY: number = 1;
  static readonly PUBLISH_HELP: number = 2;
  static readonly HELP_HALL: number = 3;
}

/**
 * HomeView —— 首页（Tab 1）
 *
 * 版式照 `UI\鸿志愿_首页_志愿大厅_志愿小鸿_界面稿.png`，自上而下：
 *   ① 顶栏：橙色「志愿时长 18.5h」胶囊 + 消息 / 扫码两颗线性图标
 *   ② 34vp 白底胶囊搜索框（线性橙放大镜 + 「搜索」）
 *   ③ 通知条：橙色竖条 + 「活动名 · 时间」+ 「还没签到，别错过时长」+ 「详情」
 *   ④ 数据卡：今日志愿 / 参与中 / 待签到 + 三个叠环（蓝环中间是今日完成度）
 *   ⑤ 4 宫格大彩图标：扫码签到 / 发布活动 / 发布求助 / 求助大厅
 *   ⑥ 「本周推荐 09-23 周三 ›」+ 一张紧凑活动行
 *   ⑦ 「志愿活动 查看更多 ›」+ 三张紧凑活动行
 *
 * 【为什么两个区块都用紧凑行，而不是「推荐大卡」】
 *   设计稿 PNG 里「本周推荐」下面就是一张 56vp 缩略图的紧凑行（不是通栏大卡），
 *   PNG 是视觉权威，所以首页统一用紧凑行；通栏大卡留给「志愿大厅」的场景。
 *
 * 【为什么首页没有 FAB】
 *   计划文本里写了 FAB，但 4 个快捷入口（扫码 / 发活动 / 发求助 / 求助大厅）在宫格里
 *   已经全部覆盖，再加一个橙色悬浮球会和宫格功能重复、也破坏 PNG 的观感。故按 PNG 不做。
 *
 * 【数据】只经 `HomeService` 拿，不认识 MockData —— 这是 D 阶段「改一个开关就切真接口」的前提。
 *
 * 【为什么数据成员不加 @State】
 *   首页内容整块包在 `if (this.loading) … else …` 里，`loading` 一翻转整块重建，
 *   普通成员也能刷出新值。而 @State/@Prop 作用在「带方法的类」（Activity）上时，
 *   ArkUI 的代理层有丢方法的风险（ActivityCard 里要调 isFull()/hasDistance()），
 *   所以对象一律用普通成员，只让 loading 这个布尔量触发重绘。
 */
@Component
export struct HomeView {
  /** 跨 Tab 跳转：宫格「求助大厅」→ 互助 Tab，搜索框 → 小鸿 Tab。由 Index 注入。 */
  onSwitchTab: (index: number) => void = (index: number) => {
  };

  @State loading: boolean = true;
  private summary: HomeSummary = new HomeSummary();
  private featured: Activity = new Activity();
  private feed: Activity[] = [];

  aboutToAppear(): void {
    this.load();
  }

  /** 三份数据串行取（活动流要跳过「本周推荐」那一场，所以得等 featured 先回来） */
  private async load(): Promise<void> {
    try {
      const s: HomeSummary = await HomeService.summary();
      const f: Activity = await HomeService.featured();
      const list: Activity[] = await HomeService.activityFeed(f.id, FEED_SIZE);
      this.summary = s;
      this.featured = f;
      this.feed = list;
    } catch (err) {
      // 拉取失败保持页面骨架，不弹窗打断（D 阶段在这里补重试与 toast）
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

  private openActivity(id: number): void {
    if (id <= 0) {
      return;
    }
    // 详情页靠 activityId 拉数据 —— 不带参数它会直接显示「活动不存在」
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ActivityDetailPage',
        params: RouteParams.activityDetail(id)
      });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  /** 宫格点击：前三格是页面跳转，第四格是切到「互助」Tab */
  private onGridTap(slot: number): void {
    if (slot === GridSlot.SCAN) {
      this.goto('pages/ScanSignInPage');
    } else if (slot === GridSlot.PUBLISH_ACTIVITY) {
      this.goto('pages/PublishActivityPage');
    } else if (slot === GridSlot.PUBLISH_HELP) {
      this.goto('pages/PublishHelpPage');
    } else {
      this.onSwitchTab(NavIconId.HELP);
    }
  }

  private gridPath(slot: number): string {
    if (slot === GridSlot.SCAN) {
      return LinePath.SCAN;
    }
    if (slot === GridSlot.PUBLISH_ACTIVITY) {
      return LinePath.PLUS;
    }
    if (slot === GridSlot.PUBLISH_HELP) {
      return LinePath.CHAT;
    }
    return LinePath.LIST_H;
  }

  /**
   * 宫格四色 —— 设计稿是**纯色**取值，和 icon_grad_* 的渐变起止色并不一致，
   * 所以一律走「实心底」，不要用渐变去凑。
   */
  private gridColor(slot: number): Resource {
    if (slot === GridSlot.SCAN) {
      return AppTheme.primaryGradientStart;
    }
    if (slot === GridSlot.PUBLISH_ACTIVITY) {
      return AppTheme.accent;
    }
    if (slot === GridSlot.PUBLISH_HELP) {
      return AppTheme.ringBlue;
    }
    return AppTheme.iconSolidYellow;
  }

  private gridLabel(slot: number): Resource {
    if (slot === GridSlot.SCAN) {
      return $r('app.string.home_grid_scan');
    }
    if (slot === GridSlot.PUBLISH_ACTIVITY) {
      return $r('app.string.home_grid_publish_activity');
    }
    if (slot === GridSlot.PUBLISH_HELP) {
      return $r('app.string.home_grid_publish_help');
    }
    return $r('app.string.home_grid_help_hall');
  }

  /** 今日完成度百分比（整数），蓝环中间那个数字 */
  private progressPercent(): number {
    return Math.round(this.summary.todayProgress() * 100);
  }

  /** 通知条标题：'校园马拉松赛事志愿服务 · 后天 07:00' */
  private noticeTitle(): string {
    if (!this.summary.hasNextActivity()) {
      return '';
    }
    return this.summary.nextActivityTitle + ' · ' + DateFmt.dayHm(this.summary.nextActivityStartTime);
  }

  // ==================== 局部 UI ====================

  /** 顶栏那颗圆形点击区 —— 图标只有 15vp，不加内边距实机上很难点中 */
  @Builder
  topIcon(path: string, color: Resource, url: string) {
    Row() {
      // U13 走查：15vp 偏小，提到 20（用户反馈「消息/扫码小图标太小」）
      lineIcon(path, 20, color)
    }
    .padding(7)
    .onClick(() => {
      this.goto(url);
    })
  }

  /** ① 顶栏 */
  @Builder
  topBar() {
    Row() {
      Row() {
        // ⚠️ $r() 返回的是 Resource 对象，**不能参与字符串拼接**（会拼出 "[object Object]"，
        //   而且编译期零告警）。所以数字与文案必须拆成相邻的 Span，空格写在纯字符串那一段里。
        Text() {
          Span($r('app.string.home_hours_prefix'))
          Span(' ' + this.summary.totalHours.toString())
          Span($r('app.string.common_unit_hour_short'))
        }
        .fontSize(AppTheme.fontSecondary)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.primary)
      }
      // U13 走查：primaryLight 在浅灰页面底上几乎隐形（用户：「很普通」）——
      // 换更深一档的 orangeTint 暖橙底 + 字号升一档，徽章感回来
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(AppTheme.orangeTint)
      .borderRadius(12)

      Blank()

      Row() {
        this.topIcon(LinePath.BUBBLE, AppTheme.textSecondary, 'pages/MessagesPage')
        this.topIcon(LinePath.SCAN, AppTheme.primary, 'pages/ScanSignInPage')
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 6 })
  }

  /** ③ 通知条：没有下一场活动时整条不显示，而不是留一张空卡 */
  @Builder
  noticeBar() {
    if (this.summary.hasNextActivity()) {
      Row() {
        Row()
          .width(3)
          .height(24)
          .borderRadius(2)
          .backgroundColor(AppTheme.primary)

        Column() {
          Text(this.noticeTitle())
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text($r('app.string.home_notice_sub'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
            .maxLines(1)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 8 })

        Text($r('app.string.home_notice_action'))
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textOnPrimary)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(AppTheme.primary)
          .borderRadius(11)
          .margin({ left: 6 })
          .onClick(() => {
            this.openActivity(this.summary.nextActivityId);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 10, right: 8, top: 9, bottom: 9 })
      // U13 走查：白卡放在白卡堆里没层次 → 橙浅底，与页面上其他卡拉开
      .backgroundColor(AppTheme.primaryLight)
      .borderRadius(14)
      .margin({ top: 9 })
    }
  }

  /** ④ 三个叠环 —— 蓝环压在最上层，里面写今日完成度 */
  @Builder
  rings() {
    Row() {
      Row()
        .width(34)
        .height(34)
        .borderRadius(17)
        .border({ width: 3, color: AppTheme.ringOrange })
        .backgroundColor(AppTheme.surface)

      Row()
        .width(34)
        .height(34)
        .borderRadius(17)
        .border({ width: 3, color: AppTheme.ringYellow })
        .backgroundColor(AppTheme.surface)
        .margin({ left: -9 })

      Stack() {
        // 今日完成度：达标显示 ✓（100% 文字 5 字符塞不进 28px 内径，U 阶段没考虑满格场景）
        if (this.progressPercent() >= 100) {
          Text('✓')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.ringBlue)
        } else {
          Text(this.progressPercent().toString() + '%')
            .fontSize(AppTheme.fontCaption)
            // 自适应字号：两位数 + % 在 28px 内径下自动缩到最小 9 号，不再换行溢出
            .maxFontSize(12)
            .minFontSize(9)
            .heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
            .maxLines(1)
            .textAlign(TextAlign.Center)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
        }
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .border({ width: 3, color: AppTheme.ringBlue })
      .backgroundColor(AppTheme.surface)
      .margin({ left: -9 })
    }
    .alignItems(VerticalAlign.Center)
  }

  /** ④ 数据卡 */
  @Builder
  statCard() {
    Row() {
      Column() {
        Text() {
          Span($r('app.string.home_today_volunteer'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
          Span(' ' + this.summary.todayHours.toString() + ' / ' + this.summary.todayTargetHours.toString() + ' ')
            .fontSize(AppTheme.fontSecondary)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Span($r('app.string.common_unit_hour'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
        }

        Text() {
          Span($r('app.string.home_ongoing'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
          Span(' ' + this.summary.ongoingCount.toString() + ' ')
            .fontSize(AppTheme.fontSecondary)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Span($r('app.string.common_unit_scene'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
        }
        .margin({ top: 6 })

        Text() {
          Span($r('app.string.home_pending_signin'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
          Span(' ' + this.summary.pendingSigninCount.toString() + ' ')
            .fontSize(AppTheme.fontSecondary)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
          Span($r('app.string.common_unit_scene'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
        }
        .margin({ top: 6 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.rings()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(12)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 9 })
    .onClick(() => {
      this.onSwitchTab(NavIconId.VOLUNTEER);
    })
  }

  /** ⑤ 单个宫格 */
  @Builder
  gridItem(slot: number) {
    Column() {
      GradientIcon({
        path: this.gridPath(slot),
        tone: IconTone.ORANGE,
        boxSize: 36,
        glyphSize: 17,
        radius: 12,
        useFlat: true,
        flatColor: this.gridColor(slot),
        linear: true
      })

      Text(this.gridLabel(slot))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textPrimary)
        .maxLines(2)
        .textAlign(TextAlign.Center)
        .margin({ top: 6 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onGridTap(slot);
    })
  }

  /** ⑤ 4 宫格 */
  @Builder
  gridCard() {
    Row() {
      this.gridItem(GridSlot.SCAN)
      this.gridItem(GridSlot.PUBLISH_ACTIVITY)
      this.gridItem(GridSlot.PUBLISH_HELP)
      this.gridItem(GridSlot.HELP_HALL)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 9 })
  }

  /** ⑥⑦ 通用的「一张紧凑活动行」 */
  @Builder
  feedRow(item: Activity, gapTop: number) {
    Row() {
      ActivityCard({
        activity: item,
        mode: CardMode.COMPACT,
        onTap: (id: number) => {
          this.openActivity(id);
        }
      })
    }
    .width('100%')
    .margin({ top: gapTop })
  }

  /** 页面主体（loading 结束后才构建） */
  @Builder
  content() {
    Scroll() {
      Column() {
        this.topBar()

        Row() {
          SearchBar({
            placeholder: $r('app.string.home_search_placeholder'),
            iconColor: AppTheme.primary,
            showAction: true,
            onTap: () => {
              this.onSwitchTab(NavIconId.AGENT);
            }
          })
        }
        .width('100%')
        .margin({ top: 9 })

        this.noticeBar()
        this.statCard()
        this.gridCard()

        // ---------- 本周推荐 ----------
        Row() {
          SectionHeader({
            title: $r('app.string.home_week_recommend'),
            showAction: true,
            actionText: DateFmt.todayMdWeek(),
            actionColor: AppTheme.primary,
            onAction: () => {
              this.onSwitchTab(NavIconId.VOLUNTEER);
            }
          })
        }
        .width('100%')
        .margin({ top: 10 })

        if (this.featured.id > 0) {
          this.feedRow(this.featured, 8)
        }

        // ---------- 志愿活动 ----------
        Row() {
          SectionHeader({
            title: $r('app.string.home_section_activity'),
            showAction: true,
            actionText: $r('app.string.common_see_more'),
            onAction: () => {
              this.onSwitchTab(NavIconId.VOLUNTEER);
            }
          })
        }
        .width('100%')
        .margin({ top: 12 })

        ForEach(this.feed, (item: Activity) => {
          this.feedRow(item, 8)
        }, (item: Activity) => item.id.toString())

        Row()
          .width('100%')
          .height(16)
      }
      .width('100%')
      // 水平留白只加在这一层容器上，子元素只写纵向 margin —— 避免 100% 宽 + 水平 margin 溢出
      .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingOverlay({ text: $r('app.string.common_loading') })
      } else {
        this.content()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
