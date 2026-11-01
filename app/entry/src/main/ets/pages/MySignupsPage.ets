import { AppTheme, TagTone } from '../common/AppTheme';
import { appIcon, IconPath, lineIcon, LinePath } from '../common/AppIcon';
import { BizDict } from '../common/BizDict';
import { DateFmt } from '../common/DateFmt';
import { RouteParams } from '../common/RouteParams';
import { Signup } from '../model/Signup';
import { HourRecord } from '../model/HourRecord';
import { MineService } from '../service/MineService';
import { PageHeader } from '../components/PageHeader';
import { PillTag } from '../components/PillTag';
import { EmptyState } from '../components/EmptyState';
import { LoadingOverlay } from '../components/LoadingOverlay';

/**
 * 筛选槽位 —— 与 segRow() 里的三个胶囊一一对应。
 * counts 与 list 由页面从 signups 现算（Mock 无持久态，服务端下发同理）。
 */
class Seg {
  static readonly ALL: number = 0;
  static readonly WAIT: number = 1;
  static readonly DONE: number = 2;
}

/**
 * MySignupsPage —— 我的报名
 *
 * 版式照 `UI\鸿志愿_我的报名_时长明细_电子证书_界面稿.png`：
 *   ① 顶栏：返回 + 标题 + 橙色「筛选」（演示版无筛选面板，点了提示）
 *   ② 三段分段器（灰底白块）：全部 N / 待参与 N / 已完成 N
 *   ③ 报名卡列表：标题 + 状态标签 / 时钟 + 时间 + 右侧时长 / 底部按钮区
 *
 * 【状态 → 卡片形态】
 *   signed_up  → 「待签到」橙标 + 整宽橙色「扫码签到」按钮（进 ScanSignInPage）
 *   checked_in → 「已签到」蓝标，无按钮
 *   completed  → 「已完成」绿标 + 绿色「已入账 X 小时」+「查看详情/评价活动」双按钮
 *   no_show    → 「未到场」红标，无按钮
 */
@Entry
@Component
struct MySignupsPage {
  @State loading: boolean = true;
  /** 当前分段下标 */
  @State segIndex: number = 0;
  /** 各分段的条数（下标与 Seg 对齐） */
  @State segCounts: number[] = [0, 0, 0];
  /** 列表版本号 */
  @State listTick: number = 0;

  private all: Signup[] = [];
  private list: Signup[] = [];
  /** completed 活动的已入账时长（activityId → hours），由时长明细联表而来 */
  private credited: Map<number, number> = new Map();

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      this.all = await MineService.signups();
      const records: HourRecord[] = await MineService.hours();
      for (let i = 0; i < records.length; i++) {
        this.credited.set(records[i].activityId, records[i].hours);
      }
      let wait: number = 0;
      let done: number = 0;
      for (let i = 0; i < this.all.length; i++) {
        const s: string = this.all[i].status;
        if (s === 'completed') {
          done = done + 1;
        } else if (s === 'signed_up' || s === 'checked_in') {
          wait = wait + 1;
        }
      }
      this.segCounts = [this.all.length, wait, done];
      this.applyFilter();
    } catch (err) {
      this.all = [];
      this.list = [];
    }
    this.loading = false;
  }

  /** 按当前分段过滤 + 重排（D4 前注释假设后端按报名时间倒序，真实接口并不保证 → 前端统一排序） */
  private applyFilter(): void {
    const out: Signup[] = [];
    for (let i = 0; i < this.all.length; i++) {
      const s: string = this.all[i].status;
      if (this.segIndex === Seg.WAIT && !(s === 'signed_up' || s === 'checked_in')) {
        continue;
      }
      if (this.segIndex === Seg.DONE && s !== 'completed') {
        continue;
      }
      out.push(this.all[i]);
    }
    this.list = this.sortSignups(out);
    this.listTick = this.listTick + 1;
  }

  /**
   * 排序规则（对齐用户直觉）：
   *   待参与（signed_up/checked_in）→ 按活动开始时间**升序**，最近要来的在最上
   *   已完成 / 未到场 → 按活动开始时间**倒序**，最近完成的在最上，且整组沉底
   * 时间串是 'yyyy-MM-dd HH:mm:ss'，字典序即时间序。
   */
  private sortSignups(list: Signup[]): Signup[] {
    const wait: Signup[] = [];
    const done: Signup[] = [];
    for (let i = 0; i < list.length; i++) {
      const s: string = list[i].status;
      if (s === 'signed_up' || s === 'checked_in') {
        wait.push(list[i]);
      } else {
        done.push(list[i]);
      }
    }
    wait.sort((a: Signup, b: Signup) => this.cmpTime(this.startTime(a), this.startTime(b)));
    done.sort((a: Signup, b: Signup) => this.cmpTime(this.startTime(b), this.startTime(a)));
    return wait.concat(done);
  }

  private startTime(item: Signup): string {
    return item.activity === null ? '' : item.activity.startTime;
  }

  private cmpTime(a: string, b: string): number {
    if (a === b) {
      return 0;
    }
    return a < b ? -1 : 1;
  }

  private switchSeg(index: number): void {
    this.segIndex = index;
    this.applyFilter();
  }

  // ==================== 导航 ====================

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  private goto(url: string, activityId: number): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: url,
        params: RouteParams.activityDetail(activityId)
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

  // ==================== 取数 ====================

  private title(item: Signup): string {
    return item.activity === null ? '' : item.activity.title;
  }

  /** 活动开始时间文案：日期块已显示「09-21 / 周一」，这里只补相对日 + 时段
   *  → '明天 07:00 - 13:00' / '14:00 - 17:00'，避免与右侧时长文字堆叠 */
  private timeText(item: Signup): string {
    if (item.activity === null) {
      return '';
    }
    const start: string = item.activity.startTime;
    const end: string = item.activity.endTime;
    const label: string = DateFmt.dayLabel(start);
    const head: string = label === '' ? '' : label + ' ';
    if (DateFmt.ymd(start) === DateFmt.ymd(end)) {
      return head + DateFmt.hm(start) + ' - ' + DateFmt.hm(end);
    }
    return head + DateFmt.hm(start);
  }

  private hours(item: Signup): number {
    return item.activity === null ? 0 : item.activity.serviceHours;
  }

  /** completed 卡的已入账文案：无记录返回 -1（不显示） */
  private creditedOf(item: Signup): number {
    // Map.get 返回 number | undefined，必须显式判空
    const v: number | undefined = this.credited.get(item.activityId);
    if (v === undefined) {
      return -1;
    }
    return v;
  }

  private statusText(item: Signup): Resource {
    // 已报名且未到签到环节 → 设计稿口径是「待签到」
    if (item.canSignIn()) {
      return $r('app.string.signup_status_wait_signin');
    }
    return BizDict.signupStatusLabel(item.status);
  }

  private statusTone(item: Signup): string {
    if (item.canSignIn()) {
      return TagTone.ORANGE;
    }
    return BizDict.signupStatusTone(item.status);
  }

  // ==================== 局部 UI ====================

  /** ② 单个分段（选中白块橙字） */
  @Builder
  segCell(index: number) {
    Text() {
      Span(this.segLabel(index))
        .fontSize(AppTheme.fontSecondary)
        .fontWeight(index === this.segIndex ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(index === this.segIndex ? AppTheme.primary : AppTheme.textSecondary)
      Span(' ' + this.segCounts[index].toString())
        .fontSize(AppTheme.fontSecondary)
        .fontWeight(index === this.segIndex ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(index === this.segIndex ? AppTheme.primary : AppTheme.textSecondary)
    }
    .textAlign(TextAlign.Center)
  }

  private segLabel(index: number): Resource {
    if (index === Seg.WAIT) {
      return $r('app.string.signup_tab_wait');
    }
    if (index === Seg.DONE) {
      return $r('app.string.signup_tab_done');
    }
    return $r('app.string.help_filter_all');
  }

  /** ② 三段分段器（设计稿：灰底 12 圆角 + 3px 内衬 + 选中白块 9 圆角） */
  @Builder
  segRow() {
    Row() {
      Row() {
        this.segCell(Seg.ALL)
      }
      .layoutWeight(1)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.segIndex === Seg.ALL ? AppTheme.surface : Color.Transparent)
      .borderRadius(9)
      .onClick(() => {
        this.switchSeg(Seg.ALL);
      })

      Row() {
        this.segCell(Seg.WAIT)
      }
      .layoutWeight(1)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.segIndex === Seg.WAIT ? AppTheme.surface : Color.Transparent)
      .borderRadius(9)
      .onClick(() => {
        this.switchSeg(Seg.WAIT);
      })

      Row() {
        this.segCell(Seg.DONE)
      }
      .layoutWeight(1)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.segIndex === Seg.DONE ? AppTheme.surface : Color.Transparent)
      .borderRadius(9)
      .onClick(() => {
        this.switchSeg(Seg.DONE);
      })
    }
    .width('100%')
    .padding(3)
    .backgroundColor(AppTheme.fillGray)
    .borderRadius(12)
    .margin({ top: 12 })
  }

  /** ③ 报名卡：左侧日期块 + 信息区（点卡片本体进详情）+ 底部独立按钮行（不冒泡） */
  @Builder
  signupCard(item: Signup) {
    Column() {
      // 信息区：日期块 + 标题/状态 + 时间/时长（整块可点进详情）
      Row() {
        // 日期块：待参与橙底突出「最近要来的」，其余灰底
        Column() {
          Text(this.dayText(item))
            .fontSize(AppTheme.fontSecondary)
            .fontWeight(FontWeight.Medium)
            .fontColor(item.canSignIn() ? AppTheme.primary : AppTheme.textSecondary)
          Text(this.weekText(item))
            .fontSize(AppTheme.fontBadge)
            .fontColor(AppTheme.textHint)
            .margin({ top: 2 })
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(item.canSignIn() ? AppTheme.orangeTint : AppTheme.fillGray)
        .borderRadius(12)

        Column() {
          Row() {
            Text(this.title(item))
              .fontSize(AppTheme.fontBody)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            PillTag({
              text: this.statusText(item),
              tone: this.statusTone(item)
            })
              .margin({ left: 8 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row() {
            lineIcon(LinePath.CLOCK, 12, AppTheme.textHint)
            // layoutWeight(1)：时间占剩余宽度、极端时省略，右侧时长永不被挤贴
            Text(this.timeText(item))
              .fontSize(AppTheme.fontSecondary)
              .fontColor(AppTheme.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ left: 6 })

            if (item.status === 'completed' && this.creditedOf(item) >= 0) {
              Text() {
                Span($r('app.string.signup_credited'))
                  .fontSize(AppTheme.fontSecondary)
                  .fontColor(AppTheme.accent)
                Span(' ' + this.creditedOf(item).toString() + ' ')
                  .fontSize(AppTheme.fontSecondary)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.accent)
                Span($r('app.string.common_unit_hour'))
                  .fontSize(AppTheme.fontSecondary)
                  .fontColor(AppTheme.accent)
              }
            } else {
              Text() {
                Span(this.hours(item).toString() + ' ')
                  .fontSize(AppTheme.fontSecondary)
                  .fontColor(item.canSignIn() ? AppTheme.primary : AppTheme.textSecondary)
                Span($r('app.string.common_unit_hour'))
                  .fontSize(AppTheme.fontSecondary)
                  .fontColor(item.canSignIn() ? AppTheme.primary : AppTheme.textSecondary)
              }
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ top: 7 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 11 })
        .onClick(() => {
          this.goto('pages/ActivityDetailPage', item.activityId);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 按钮行：与信息区平级，点击不会冒泡到「进详情」
      if (item.canSignIn()) {
        Row() {
          Blank()

          Row() {
            Text($r('app.string.detail_btn_signin'))
              .fontSize(AppTheme.fontSecondary)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textOnPrimary)
            appIcon(IconPath.CHEVRON_RIGHT, 11, AppTheme.textOnPrimary)
          }
          .height(32)
          .padding({ left: 16, right: 12 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor(AppTheme.primary)
          .borderRadius(16)
          .margin({ top: 10 })
          .onClick(() => {
            this.goto('pages/ScanSignInPage', item.activityId);
          })
        }
        .width('100%')
      } else if (item.status === 'completed') {
        Row() {
          Blank()

          Row() {
            Text($r('app.string.signup_rate'))
              .fontSize(AppTheme.fontSecondary)
              .fontColor(AppTheme.textSecondary)
            appIcon(IconPath.CHEVRON_RIGHT, 11, AppTheme.textHint)
          }
          .height(32)
          .padding({ left: 16, right: 12 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor(AppTheme.fillGray)
          .borderRadius(16)
          .margin({ top: 10 })
          .onClick(() => {
            this.goto('pages/ActivityDetailPage', item.activityId);
          })
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(13)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
  }

  /** 日期块两位：'09-26' / '周六'（活动无日期时占位） */
  private dayText(item: Signup): string {
    if (item.activity === null) {
      return '--';
    }
    return DateFmt.md(item.activity.startTime);
  }

  private weekText(item: Signup): string {
    if (item.activity === null) {
      return '';
    }
    return DateFmt.weekday(item.activity.startTime);
  }

  private listIsEmpty(): boolean {
    return this.listTick >= 0 && this.list.length === 0;
  }

  @Builder
  body() {
    Scroll() {
      Column() {
        this.segRow()

        Column() {
          if (this.listIsEmpty()) {
            EmptyState({
              iconPath: IconPath.INBOX,
              title: $r('app.string.common_empty'),
              showSubtitle: false
            })
          } else {
            ForEach(this.list, (item: Signup) => {
              Row() {
                this.signupCard(item)
              }
              .width('100%')
              .margin({ top: 10 })
            }, (item: Signup) => item.id.toString() + '#' + this.listTick.toString())
          }

          Row()
            .width('100%')
            .height(16)
        }
        .width('100%')
        .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })
      }
      .width('100%')
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingOverlay({ text: $r('app.string.common_loading') })
      } else {
        Column() {
          PageHeader({
            title: $r('app.string.mine_my_signup'),
            onBack: () => {
              this.back();
            }
          })

          this.body()
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
