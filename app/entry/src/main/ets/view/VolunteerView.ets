import { AppTheme, CardMode } from '../common/AppTheme';
import { appIcon, IconPath, lineIcon, LinePath } from '../common/AppIcon';
import { RouteParams } from '../common/RouteParams';
import { ToastUtil } from '../common/ToastUtil';
import { Activity } from '../model/Activity';
import { VolunteerStats } from '../model/VolunteerStats';
import { VolunteerService } from '../service/VolunteerService';
import { SearchBar } from '../components/SearchBar';
import { SegmentedTabs } from '../components/SegmentedTabs';
import { SectionHeader } from '../components/SectionHeader';
import { ActivityCard } from '../components/ActivityCard';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { EmptyState } from '../components/EmptyState';

/**
 * 筛选码数组 —— 与 SegmentedTabs 的胶囊顺序**一一对应**（下标即胶囊下标）。
 * 'recommend' / 'nearby' 是伪分类（后端不按分类过滤），其余是 ActivityCategory 的码值。
 * 这里刻意用「码数组 + 下标」而不是 [[码, 文案], …]：
 * 文案走 filterLabel(index) 的 if 链查 $r，避免把 Resource 塞进数组初始化里。
 */
const FILTER_CODES: string[] = ['recommend', 'nearby', 'env', 'teach', 'game', 'elder'];

/** 排行榜取前几名 */
const RANK_SIZE: number = 3;

/** 三个快捷圆按钮的槽位编号 —— 与 circleCard() 里的调用顺序严格一致 */
class CircleSlot {
  static readonly MY_SIGNUP: number = 0;
  static readonly PUBLISH: number = 1;
  static readonly SIGNIN: number = 2;
}

/**
 * VolunteerView —— 志愿大厅（Tab 2）
 *
 * 版式照 `UI\鸿志愿_首页_志愿大厅_志愿小鸿_界面稿.png`，自上而下：
 *   ① 白底胶囊搜索框（灰色线性放大镜 + 橙色「搜索」）
 *   ② 筛选胶囊条：推荐（选中橙底）/ 附近 / 环保 / 支教 / 赛会 / 助老
 *   ③ 数据卡：累计时长 · 参与次数 + 橙色 ›
 *   ④ 三圆快捷行：我的报名(40 灰) / 发布活动(52 橙) / 签到(40 灰)
 *   ⑤ 活动排行榜卡：1/2/3 名奖牌 + 「N 人报名 · Xh」
 *   ⑥ 「志愿活动」+ 活动列表（横向卡，可滚动）
 *
 * 【为什么去掉顶部「志愿大厅」标题行】
 *   设计稿这一屏**没有页面标题**，搜索框直接从页顶开始（首页同理）。
 *   Tab 栏上的「志愿」已经承担了标题职能，再加一行只会挤掉内容。
 *
 * 【为什么列表用 listTick 换 key 而不是给 Activity 加 @State】
 *   ArkUI 对「带方法的类」做 @State/@Prop 代理时有丢方法的风险
 *   （ActivityCard 里要调 isFull()/hasDistance()），所以数据一律普通成员。
 *   但普通成员变更不会触发重绘 —— 于是用一个 `@State listTick`，
 *   把它拼进 ForEach 的 key：tick 一变，所有行的 key 都变，整段列表被**重建**并读到新数据。
 *   （只改 filterIndex 是不够的：换筛选后可能返回同 id 的活动，key 不变就不会刷新。）
 *
 * 【数据】只经 `VolunteerService` 拿，不认识 MockData。
 */
@Component
export struct VolunteerView {
  @State loading: boolean = true;
  /** 当前选中的筛选胶囊下标 */
  @State filterIndex: number = 0;
  /** 搜索关键词（@State：打字要触发列表刷新） */
  @State keyword: string = '';
  /** 列表版本号：每次重取列表 +1，用来强制 ForEach 重建（见类注释） */
  @State listTick: number = 0;
  /** 列表请求失败（区别于「真的没有活动」）——失败时显示重试而非空态 */
  @State loadFailed: boolean = false;

  private stats: VolunteerStats = new VolunteerStats();
  private rank: Activity[] = [];
  private list: Activity[] = [];

  /** 发布成功信号（PublishActivityPage set）：时间戳变化即重拉列表 */
  @StorageProp('pubRefresh') @Watch('onPubRefresh') pubRefresh: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  /** 发布页回来 → 重拉列表（新活动立即可见） */
  onPubRefresh(): void {
    if (this.pubRefresh > 0) {
      this.load();
    }
  }

  /** 首次加载：三份数据串行取，一起就绪后才撤掉 loading */
  private async load(): Promise<void> {
    try {
      const s: VolunteerStats = await VolunteerService.stats();
      const r: Activity[] = await VolunteerService.rank(RANK_SIZE);
      const l: Activity[] | null = await VolunteerService.activities(FILTER_CODES[this.filterIndex], this.keyword);
      this.stats = s;
      this.rank = r;
      this.loadFailed = l === null;
      this.list = l === null ? [] : l;
    } catch (err) {
      this.loadFailed = true;
    }
    this.loading = false;
  }

  /** 只重取活动列表（切胶囊 / 打字时用），统计卡与排行榜不动 */
  private async reloadList(): Promise<void> {
    try {
      const l: Activity[] | null = await VolunteerService.activities(FILTER_CODES[this.filterIndex], this.keyword);
      this.loadFailed = l === null;
      this.list = l === null ? [] : l;
    } catch (err) {
      this.loadFailed = true;
      this.list = [];
    }
    this.listTick = this.listTick + 1;
  }

  // ==================== 导航 ====================

  private goto(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: url });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  /** 进活动详情 —— 必须带 activityId，详情页靠它拉数据 */
  private openActivity(id: number): void {
    if (id <= 0) {
      return;
    }
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ActivityDetailPage',
        params: RouteParams.activityDetail(id)
      });
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

  // ==================== 胶囊 / 圆按钮的映射（查表只写一处） ====================

  /** 胶囊文案（下标 → 资源） */
  private filterLabel(index: number): Resource {
    if (index === 1) {
      return $r('app.string.filter_nearby');
    }
    if (index === 2) {
      return $r('app.string.filter_env');
    }
    if (index === 3) {
      return $r('app.string.filter_teach');
    }
    if (index === 4) {
      return $r('app.string.filter_game');
    }
    if (index === 5) {
      return $r('app.string.filter_elder');
    }
    return $r('app.string.filter_recommend');
  }

  private filterItems(): Resource[] {
    const out: Resource[] = [];
    for (let i = 0; i < FILTER_CODES.length; i++) {
      out.push(this.filterLabel(i));
    }
    return out;
  }

  /** 中间那颗「发布活动」是橙色实心大圆，另外两颗是灰色小圆 */
  private circleFilled(slot: number): boolean {
    return slot === CircleSlot.PUBLISH;
  }

  private circleSize(slot: number): number {
    return this.circleFilled(slot) ? 52 : 40;
  }

  private circlePath(slot: number): string {
    if (slot === CircleSlot.PUBLISH) {
      return LinePath.PLUS;
    }
    if (slot === CircleSlot.SIGNIN) {
      return LinePath.SCAN;
    }
    return LinePath.LIST_H;
  }

  private circleLabel(slot: number): Resource {
    if (slot === CircleSlot.PUBLISH) {
      return $r('app.string.hall_publish_activity');
    }
    if (slot === CircleSlot.SIGNIN) {
      return $r('app.string.hall_signin');
    }
    return $r('app.string.hall_my_signup');
  }

  private onCircleTap(slot: number): void {
    if (slot === CircleSlot.PUBLISH) {
      this.goto('pages/PublishActivityPage');
    } else if (slot === CircleSlot.SIGNIN) {
      this.goto('pages/ScanSignInPage');
    } else {
      this.goto('pages/MySignupsPage');
    }
  }

  /** 奖牌底色：1 橙浅 2 绿浅 3 蓝浅，4 名开外灰底 */
  private rankBg(rank: number): Resource {
    if (rank === 1) {
      return AppTheme.orangeTint;
    }
    if (rank === 2) {
      return AppTheme.accentLight;
    }
    if (rank === 3) {
      return AppTheme.blueLight;
    }
    return AppTheme.fillGray;
  }

  private rankColor(rank: number): Resource {
    if (rank === 1) {
      return AppTheme.primary;
    }
    if (rank === 2) {
      return AppTheme.accent;
    }
    if (rank === 3) {
      return AppTheme.ringBlue;
    }
    return AppTheme.textSecondary;
  }

  // ==================== 局部 UI ====================

  /** ① 搜索框 —— 大厅是真输入框（editable），放大镜走灰色 */
  @Builder
  searchRow() {
    Row() {
      SearchBar({
        placeholder: $r('app.string.hall_search_placeholder'),
        editable: true,
        iconColor: AppTheme.textHint,
        showAction: true,
        onKeywordChange: (kw: string) => {
          this.keyword = kw;
          this.reloadList();
        }
      })
    }
    .width('100%')
    .margin({ top: 10 })
  }

  /**
   * ② 筛选胶囊条。
   * ⚠️ SegmentedTabs **自带左右 pagePaddingH**，所以它必须放在没有水平 padding 的容器里，
   *   否则会双倍留白（外层再加一层 padding 也会连带把胶囊挤窄）。
   */
  @Builder
  filterRow() {
    Row() {
      SegmentedTabs({
        items: this.filterItems(),
        selectedIndex: this.filterIndex,
        onSelect: (index: number) => {
          this.filterIndex = index;
          this.reloadList();
        }
      })
    }
    .width('100%')
    .margin({ top: 10 })
  }

  /** ③ 单个数字格 */
  @Builder
  statCell(label: Resource, value: string, unit: Resource) {
    Column() {
      Text(label)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)

      // ⚠️ $r() 返回 Resource 对象，不能参与字符串拼接（会渲染成 [object Object]），
      //   所以「数字 + 空格」放纯字符串 Span，单位单独一个 Span。
      // U13 统一「数值=数据焦点」：志愿域数值点亮 primary 橙（首页环/我的深卡同语言）。
      Text() {
        Span(value + ' ')
          .fontSize(AppTheme.fontTitleSection)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.primary)
        Span(unit)
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
      }
      .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
  }

  /** ③ 数据卡：累计时长 ｜ 参与次数 ｜ › */
  @Builder
  statCard() {
    Row() {
      this.statCell(
        $r('app.string.hall_total_hours'),
        this.stats.totalHours.toString(),
        $r('app.string.common_unit_hour')
      )

      Row()
        .width(1)
        .height(30)
        .backgroundColor(AppTheme.divider)
        .margin({ left: 14, right: 14 })

      this.statCell(
        $r('app.string.hall_join_count'),
        this.stats.joinCount.toString(),
        $r('app.string.common_unit_count')
      )

      Blank()

      appIcon(IconPath.CHEVRON_RIGHT, 14, AppTheme.primary)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(12)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 10 })
    .onClick(() => {
      this.goto('pages/MyHoursPage');
    })
  }

  /** ④ 单个圆按钮 */
  @Builder
  circleAction(slot: number) {
    Column() {
      Row() {
        if (this.circleFilled(slot)) {
          lineIcon(this.circlePath(slot), 20, AppTheme.textOnPrimary)
        } else {
          lineIcon(this.circlePath(slot), 17, AppTheme.textSecondary)
        }
      }
      .width(this.circleSize(slot))
      .height(this.circleSize(slot))
      .borderRadius(this.circleSize(slot) / 2)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.circleFilled(slot) ? AppTheme.primary : AppTheme.fillGray)

      Text(this.circleLabel(slot))
        .fontSize(AppTheme.fontCaption)
        .fontWeight(this.circleFilled(slot) ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.circleFilled(slot) ? AppTheme.primary : AppTheme.textSecondary)
        .margin({ top: 5 })
    }
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onCircleTap(slot);
    })
  }

  /** ④ 三圆快捷行 */
  @Builder
  circleCard() {
    Row() {
      this.circleAction(CircleSlot.MY_SIGNUP)
      this.circleAction(CircleSlot.PUBLISH)
      this.circleAction(CircleSlot.SIGNIN)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 10 })
  }

  /** ⑤ 单条榜单 */
  @Builder
  rankRow(item: Activity, rank: number) {
    Row() {
      Stack() {
        Text(rank.toString())
          .fontSize(AppTheme.fontSecondary)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.rankColor(rank))
      }
      .width(34)
      .height(34)
      .borderRadius(11)
      .backgroundColor(this.rankBg(rank))

      Column() {
        Text(item.title)
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text() {
          Span(item.joinedCount.toString() + ' ')
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
          Span($r('app.string.hall_rank_joined'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
          Span(' · ' + item.serviceHours.toString())
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
          Span($r('app.string.common_unit_hour_short'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
        }
        .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 9 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 9 })
    .onClick(() => {
      this.openActivity(item.id);
    })
  }

  /** ⑤ 活动排行榜卡 */
  @Builder
  rankCard() {
    Column() {
      Row() {
        Text($r('app.string.hall_rank'))
          .fontSize(AppTheme.fontSecondary)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)

        Text($r('app.string.hall_rank_week'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textHint)
          .margin({ left: 6 })

        Blank()

        Text($r('app.string.common_more'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.primary)
          .onClick(() => {
            ToastUtil.show('查看更多功能即将上线');
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(this.rank, (item: Activity, index: number) => {
        this.rankRow(item, index + 1)
      }, (item: Activity, index: number) => 'rank-' + index.toString() + '-' + item.id.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(11)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 10 })
  }

  /**
   * 列表是否为空。
   * ⚠️ 这里**必须读一下 `listTick`**：`list` 是普通成员，自己不会触发重绘。
   *   「切筛选胶囊」有 `filterIndex` 兜底（它是 @State 且被 build 读到），
   *   但「搜索无结果」这条路只有 tick 会变 —— 不读它就永远刷不出空状态。
   */
  private listIsEmpty(): boolean {
    return !this.loadFailed && this.listTick >= 0 && this.list.length === 0;
  }

  /** ⑥ 活动列表（横向卡；空则整段换成空状态） */
  @Builder
  activityList() {
    Column() {
      if (this.loadFailed) {
        // 请求失败：明确提示 + 重试（不能显示成「没有活动」——会让人以为数据丢了）
        EmptyState({
          iconPath: IconPath.SEARCH,
          title: $r('app.string.hall_load_fail'),
          showSubtitle: false,
          showAction: true,
          actionText: $r('app.string.common_retry'),
          onAction: () => {
            this.reloadList();
          }
        })
      } else if (this.listIsEmpty()) {
        EmptyState({
          iconPath: IconPath.SEARCH,
          title: $r('app.string.hall_empty'),
          showSubtitle: false
        })
      } else {
        ForEach(this.list, (item: Activity) => {
          Row() {
            ActivityCard({
              activity: item,
              mode: CardMode.LIST,
              onTap: (id: number) => {
                this.openActivity(id);
              }
            })
          }
          .width('100%')
          .margin({ top: 8 })
        }, (item: Activity) => item.id.toString() + '#' + this.listTick.toString())
      }
    }
    .width('100%')
  }

  /** 页面主体（loading 结束后才构建） */
  @Builder
  content() {
    Scroll() {
      Column() {
        // ① 搜索框（要跟卡片同宽 → 单独包一层带水平留白的容器）
        Column() {
          this.searchRow()
        }
        .width('100%')
        .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })

        // ② 胶囊条自带水平留白，不能再套 padding
        this.filterRow()

        Column() {
          this.statCard()
          this.circleCard()
          this.rankCard()

          Row() {
            SectionHeader({ title: $r('app.string.home_section_activity') })
          }
          .width('100%')
          .margin({ top: 12 })

          this.activityList()

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
