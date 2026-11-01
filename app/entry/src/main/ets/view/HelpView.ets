import { AppTheme } from '../common/AppTheme';
import { appIcon, IconPath, lineIcon, LinePath } from '../common/AppIcon';
import { RouteParams } from '../common/RouteParams';
import { HelpRequest } from '../model/HelpRequest';
import { HelpService } from '../service/HelpService';
import { Result } from '../model/Result';
import { SearchBar } from '../components/SearchBar';
import { SegmentedTabs } from '../components/SegmentedTabs';
import { SectionHeader } from '../components/SectionHeader';
import { HelpCard } from '../components/HelpCard';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { EmptyState } from '../components/EmptyState';

/**
 * 筛选码数组 —— 与 SegmentedTabs 的胶囊顺序**一一对应**（下标即胶囊下标）。
 * 'all' 是伪分类（不过滤），其余是 HelpCategory 的码值。
 */
const FILTER_CODES: string[] = ['all', 'errand', 'borrow', 'qa', 'skill', 'carry'];

/** 数据卡右侧的 › 与区块头的角标常量 */
const CHEVRON: number = 14;

/**
 * 三个快捷圆按钮的槽位编号 —— 与 circleAction() 里的调用顺序严格一致
 */
class CircleSlot {
  static readonly MY_REQUEST: number = 0;
  static readonly PUBLISH: number = 1;
  static readonly MY_ORDER: number = 2;
}

/**
 * HelpView —— 互助大厅（Tab 4）
 *
 * 版式照 `UI\鸿志愿_互助大厅_消息中心_我的_界面稿.png`，自上而下：
 *   ① 白底胶囊搜索框（灰色线性放大镜 + 橙色「搜索」）
 *   ② 分类筛选胶囊：全部（选中橙底）/ 跑腿 / 借物 / 问答 / 技能 / 搬运
 *   ③ 数据卡：我发布的（N 条）｜ 我接单的（N 单）+ 绿色 ›
 *   ④ 三圆快捷行：我的求助(40 灰) / 发布求助(52 绿) / 我的接单(40 灰)
 *   ⑤ 「求助大厅 · 按距离排序 ›」区块头
 *   ⑥ 求助卡列表（悬赏角标 + 状态标签 + 尾部「我要接单」）
 *
 * 【列表用 listTick 换 key】同 VolunteerView：数据是带方法的普通成员，
 *   用 @State listTick 拼进 ForEach key，tick 一变整段重建。
 *
 * 【数据】只经 `HelpService` 拿，不认识 MockData。
 */
@Component
export struct HelpView {
  @State loading: boolean = true;
  /** 当前选中的筛选胶囊下标 */
  @State filterIndex: number = 0;
  /** 搜索关键词 */
  @State keyword: string = '';
  /** 列表版本号：每次重取列表 +1，强制 ForEach 重建 */
  @State listTick: number = 0;
  /** 列表请求失败（区别于「真的没有求助」） */
  @State loadFailed: boolean = false;

  private list: HelpRequest[] = [];
  private publishedCount: number = 0;
  private acceptedCount: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const l: HelpRequest[] | null = await HelpService.list(FILTER_CODES[this.filterIndex], this.keyword);
      const c: number[] = await HelpService.counts();
      this.loadFailed = l === null;
      this.list = l === null ? [] : l;
      this.publishedCount = c[0];
      this.acceptedCount = c[1];
    } catch (err) {
      this.loadFailed = true;
    }
    this.loading = false;
  }

  private async reloadList(): Promise<void> {
    try {
      const l: HelpRequest[] | null = await HelpService.list(FILTER_CODES[this.filterIndex], this.keyword);
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

  private openDetail(id: number): void {
    if (id <= 0) {
      return;
    }
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/HelpDetailPage',
        params: RouteParams.helpDetail(id)
      });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  private toast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      // toast 失败不影响主流程
    }
  }

  /** 接单：真实调后端，成功后刷新大厅列表 */
  private async acceptHelp(id: number): Promise<void> {
    const res: Result<boolean> = await HelpService.accept(id);
    if (res.isOk()) {
      this.toast($r('app.string.help_accept_success'));
      await this.reloadList();
    } else {
      this.toast(res.message);
    }
  }

  // ==================== 胶囊 / 圆按钮的映射 ====================

  private filterLabel(index: number): Resource {
    if (index === 1) {
      return $r('app.string.help_cat_errand');
    }
    if (index === 2) {
      return $r('app.string.help_cat_borrow');
    }
    if (index === 3) {
      return $r('app.string.help_cat_qa');
    }
    if (index === 4) {
      return $r('app.string.help_cat_skill');
    }
    if (index === 5) {
      return $r('app.string.help_cat_carry');
    }
    return $r('app.string.help_filter_all');
  }

  private filterItems(): Resource[] {
    const out: Resource[] = [];
    for (let i = 0; i < FILTER_CODES.length; i++) {
      out.push(this.filterLabel(i));
    }
    return out;
  }

  /** 中间那颗「发布求助」是绿色实心大圆，另外两颗是灰色小圆 */
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
    if (slot === CircleSlot.MY_ORDER) {
      return LinePath.BUBBLE;
    }
    return LinePath.LIST_H;
  }

  private circleLabel(slot: number): Resource {
    if (slot === CircleSlot.PUBLISH) {
      return $r('app.string.help_publish');
    }
    if (slot === CircleSlot.MY_ORDER) {
      return $r('app.string.help_my_order');
    }
    return $r('app.string.help_my_request');
  }

  private onCircleTap(slot: number): void {
    if (slot === CircleSlot.PUBLISH) {
      this.goto('pages/PublishHelpPage');
    } else {
      // 「我的求助」「我的接单」都进同一个详情列表（详情的身份字段区分底部按钮）
      this.toast('我的订单列表功能即将上线');
    }
  }

  // ==================== 局部 UI ====================

  /** ① 搜索框 */
  @Builder
  searchRow() {
    Row() {
      SearchBar({
        placeholder: $r('app.string.help_search_placeholder'),
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

  /** ② 筛选胶囊条（SegmentedTabs 自带水平留白，不能再套 padding） */
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

      Text() {
        // U13 统一「数值=数据焦点」：互助域数值点亮 accent 绿（绿=互助域状态与身份）
        Span(value + ' ')
          .fontSize(AppTheme.fontTitleSection)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.accent)
        Span(unit)
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
      }
      .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
  }

  /** ③ 数据卡：我发布的 N 条 ｜ 我接单的 N 单 ｜ › */
  @Builder
  statCard() {
    Row() {
      this.statCell(
        $r('app.string.help_mine_published'),
        this.publishedCount.toString(),
        $r('app.string.help_unit_item')
      )

      Row()
        .width(1)
        .height(30)
        .backgroundColor(AppTheme.divider)
        .margin({ left: 14, right: 14 })

      this.statCell(
        $r('app.string.help_mine_taken'),
        this.acceptedCount.toString(),
        $r('app.string.help_unit_order')
      )

      Blank()

      appIcon(IconPath.CHEVRON_RIGHT, CHEVRON, AppTheme.accent)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(12)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 10 })
    .onClick(() => {
      this.toast('我的互助记录功能即将上线');
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
      .backgroundColor(this.circleFilled(slot) ? AppTheme.accent : AppTheme.fillGray)

      Text(this.circleLabel(slot))
        .fontSize(AppTheme.fontCaption)
        .fontWeight(this.circleFilled(slot) ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.circleFilled(slot) ? AppTheme.accent : AppTheme.textSecondary)
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
      this.circleAction(CircleSlot.MY_REQUEST)
      this.circleAction(CircleSlot.PUBLISH)
      this.circleAction(CircleSlot.MY_ORDER)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 10 })
  }

  /** 列表是否为空（读 listTick 保证能刷新） */
  private listIsEmpty(): boolean {
    return !this.loadFailed && this.listTick >= 0 && this.list.length === 0;
  }

  /** ⑥ 求助卡列表（空则换空状态） */
  @Builder
  helpList() {
    Column() {
      if (this.loadFailed) {
        // 请求失败：明确提示 + 重试（别显示成「没有求助」）
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
          title: $r('app.string.help_empty'),
          showSubtitle: false
        })
      } else {
        ForEach(this.list, (item: HelpRequest) => {
          Row() {
            HelpCard({
              help: item,
              onTap: (id: number) => {
                this.openDetail(id);
              },
              onAction: (id: number) => {
                this.acceptHelp(id);
              }
            })
          }
          .width('100%')
          .margin({ top: 8 })
        }, (item: HelpRequest) => item.id.toString() + '#' + this.listTick.toString())
      }
    }
    .width('100%')
  }

  /** 页面主体 */
  @Builder
  content() {
    Scroll() {
      Column() {
        Column() {
          this.searchRow()
        }
        .width('100%')
        .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })

        this.filterRow()

        Column() {
          this.statCard()
          this.circleCard()

          Row() {
            SectionHeader({
              title: $r('app.string.help_hall_title'),
              barColor: AppTheme.accent,
              showAction: true,
              actionText: $r('app.string.help_sort_distance'),
              actionColor: AppTheme.accent
            })
          }
          .width('100%')
          .margin({ top: 12 })

          this.helpList()

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
