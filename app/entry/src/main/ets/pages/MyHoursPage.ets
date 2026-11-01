import { AppTheme } from '../common/AppTheme';
import { DateFmt } from '../common/DateFmt';
import { HourRecord } from '../model/HourRecord';
import { MineService } from '../service/MineService';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { thinDivider } from '../components/Divider';

/** 月度柱状图：柱数 / 柱高上下限 / 柱间距 —— 设计稿一次性几何值 1:1 取 vp */
const BAR_COUNT: number = 6;
const BAR_MIN_H: number = 12;
const BAR_MAX_H: number = 40;
const BAR_AREA_H: number = 44;

/** 月度柱数据 */
class MonthBar {
  /** 月份标签，如 '09' */
  label: string = '';
  /** 当月新增时长 */
  hours: number = 0;
  /** 是否当前月（高亮橙） */
  current: boolean = false;

  constructor(label: string, hours: number, current: boolean) {
    this.label = label;
    this.hours = hours;
    this.current = current;
  }
}

/**
 * MyHoursPage —— 志愿时长（时长明细）
 *
 * 版式照 `UI\鸿志愿_我的报名_时长明细_电子证书_界面稿.png`：
 *   ① 汇总卡：累计志愿时长 24px 大数字 + 「本月新增 X 小时 · 超过 82% 的同学」
 *      + 最近 6 个月的柱状图（当前月橙色高亮，其余 orange_tint）
 *   ② 明细卡：每行「活动名 + 入账时间 + 右侧 +X.Xh」
 *   ③ 底部整宽橙色「生成电子证书」
 *
 * 【月度柱是真数据】从时长明细按 'yyyy-MM' 现算最近 6 个自然月的合计，
 *   不在假数据里另养一份月份字段；月标签取系统当月往前推。
 *
 * 【柱高怎么定】`min + (hours / maxHours) * (max - min)`，
 *   全为 0 时取最小高度，保证空月份也有一根可见的矮柱。
 */
@Entry
@Component
struct MyHoursPage {
  @State loading: boolean = true;

  private records: HourRecord[] = [];
  private totalHours: number = 0;
  private monthHours: number = 0;
  private bars: MonthBar[] = [];

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      this.records = await MineService.hours();
      this.totalHours = HourRecord.sumHours(this.records);
      this.buildBars();
    } catch (err) {
      this.records = [];
    }
    this.loading = false;
  }

  /** 最近 6 个自然月（含当月）的标签 + 当月合计 */
  private buildBars(): void {
    const now: Date = new Date();
    this.bars = [];
    for (let i = BAR_COUNT - 1; i >= 0; i--) {
      const d: Date = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const mm: string = d.getMonth() + 1 < 10 ? '0' + (d.getMonth() + 1).toString() : (d.getMonth() + 1).toString();
      const key: string = d.getFullYear().toString() + '-' + mm;
      let sum: number = 0;
      for (let j = 0; j < this.records.length; j++) {
        if (this.records[j].gainTime.substring(0, 7) === key) {
          sum = sum + this.records[j].hours;
        }
      }
      this.bars.push(new MonthBar(mm, sum, i === 0));
      if (i === 0) {
        this.monthHours = sum;
      }
    }
  }

  /** 柱高：按时长占比在 [min, max] 内取值 */
  private barHeight(hours: number): number {
    let max: number = 0;
    for (let i = 0; i < this.bars.length; i++) {
      if (this.bars[i].hours > max) {
        max = this.bars[i].hours;
      }
    }
    if (max <= 0) {
      return BAR_MIN_H;
    }
    const ratio: number = hours / max;
    return Math.round(BAR_MIN_H + ratio * (BAR_MAX_H - BAR_MIN_H));
  }

  // ==================== 导航 ====================

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  private goto(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: url });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  // ==================== 局部 UI ====================

  /** ① 单根柱 + 月份标签 */
  @Builder
  monthBar(bar: MonthBar) {
    Column() {
      Row()
        .width('100%')
        .height(this.barHeight(bar.hours))
        .borderRadius(4)
        .backgroundColor(bar.current ? AppTheme.primary : AppTheme.orangeTint)

      Text() {
        Span(bar.label)
          .fontSize(AppTheme.fontCaption)
          .fontWeight(bar.current ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(bar.current ? AppTheme.primary : AppTheme.textHint)
        Span($r('app.string.common_unit_month'))
          .fontSize(AppTheme.fontCaption)
          .fontWeight(bar.current ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(bar.current ? AppTheme.primary : AppTheme.textHint)
      }
      .margin({ top: 6 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  /** ① 汇总卡 */
  @Builder
  summaryCard() {
    Column() {
      Text($r('app.string.hours_total'))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)

      Text() {
        Span(this.totalHours.toString())
          .fontSize(AppTheme.fontNumberLg)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
        Span(' ')
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
        Span($r('app.string.common_unit_hour'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
      }
      .margin({ top: 4 })

      Text() {
        Span($r('app.string.hours_month_prefix'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.accent)
        Span(' ' + this.monthHours.toString() + ' ')
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.accent)
        Span($r('app.string.common_unit_hour'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.accent)
        Span(' · ')
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.accent)
        Span($r('app.string.hours_beat_students'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.accent)
      }
      .margin({ top: 5 })

      Row({ space: 6 }) {
        ForEach(this.bars, (bar: MonthBar) => {
          this.monthBar(bar)
        }, (bar: MonthBar) => bar.label + '-' + bar.current.toString())
      }
      .width('100%')
      .height(BAR_AREA_H)
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 14 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 12 })
  }

  /** ② 单条明细 */
  @Builder
  hourRow(item: HourRecord, showDivider: boolean) {
    Column() {
      Row() {
        Column() {
          Text(item.activityTitle)
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(DateFmt.mdhm(item.gainTime))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textHint)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text() {
          Span('+' + item.hours.toString())
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
          Span('h')
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (showDivider) {
        Row() {
          thinDivider()
        }
        .width('100%')
        .margin({ top: 11, bottom: 11 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** ② 明细卡 */
  @Builder
  detailCard() {
    Column() {
      Text($r('app.string.hours_title'))
        .fontSize(AppTheme.fontCaption)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
        .width('100%')

      Column() {
        ForEach(this.records, (item: HourRecord, index: number) => {
          this.hourRow(item, index < this.records.length - 1)
        }, (item: HourRecord) => item.id.toString())
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(13)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 10 })
  }

  /** ③ 底部「生成电子证书」 */
  @Builder
  bottomBar() {
      Column() {
        Row() {
          Text($r('app.string.hours_gen_cert'))
            .fontSize(AppTheme.fontBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textOnPrimary)
        }
      .width('100%')
      .height(AppTheme.buttonHeight)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.primary)
      .borderRadius(AppTheme.pillRadius)
      .onClick(() => {
        this.goto('pages/CertificatePage');
      })
    }
    .width('100%')
    .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 12, bottom: 14 })
    .backgroundColor(AppTheme.surface)
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingOverlay({ text: $r('app.string.common_loading') })
      } else {
        Column() {
          PageHeader({
            title: $r('app.string.home_hours_prefix'),
            onBack: () => {
              this.back();
            }
          })

          if (this.records.length === 0) {
            Column() {
              EmptyState({
                title: $r('app.string.common_empty'),
                showSubtitle: false
              })
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
          } else {
            Scroll() {
              Column() {
                this.summaryCard()
                this.detailCard()
                Row()
                  .width('100%')
                  .height(16)
              }
              .width('100%')
              .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .align(Alignment.Top)

            this.bottomBar()
          }
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
