import { AppTheme, CardMode, TagTone, ToneColors } from '../common/AppTheme';
import { appIcon, IconPath } from '../common/AppIcon';
import { BizDict } from '../common/BizDict';
import { DateFmt } from '../common/DateFmt';
import { Activity } from '../model/Activity';
import { PillTag } from './PillTag';

/**
 * ActivityCard —— 志愿活动卡片（三种形态合一）
 *
 *   CardMode.LIST（默认） 列表横排卡：左 92 缩略图 + 右信息 —— 志愿大厅
 *   CardMode.FEATURE      通栏大卡：通栏封面 + 下方信息 —— 单独主推一场活动
 *   CardMode.COMPACT      紧凑行：56 缩略图 + 标题 + 时间/时长/距离 + 尾部动作 —— 首页活动流
 *
 * 三种形态共用封面块、时间行、底部行三个 @Builder，改一处三种形态一起变。
 *
 * 【为什么用 mode 字符串而不是 feature/compact 两个 boolean】
 *   两个布尔能组合出「既 feature 又 compact」这种不存在的状态，
 *   字符串只会取到三个合法值之一，不需要在实现里写优先级。
 *
 * 【关于封面】工程里没有任何图片资源，也不打算为比赛塞一堆占位图：
 *   封面统一画成「分类色渐变块 + 分类图标」，既好看又不会因为图片加载失败露出灰框。
 *   等 B 阶段后端能传 cover 地址了，只改本文件的 coverBlock 一处即可。
 *
 * 【用法】
 *   ActivityCard({ activity: item, onTap: (id: number) => { this.openDetail(id) } })
 *   ActivityCard({ activity: item, mode: CardMode.COMPACT,
 *                  onTap: (id: number) => { this.openDetail(id) } })
 */
@Component
export struct ActivityCard {
  /** ⚠️ 普通成员（不加 @Prop）：ArkTS 的 @Prop 对「带方法的类」会做深拷贝，容易丢方法。
   *  列表用 ForEach 重建组件，值本来就会刷新，用普通成员最稳。 */
  activity: Activity = new Activity();
  mode: string = CardMode.LIST;
  onTap: (id: number) => void = (id: number) => {
  };

  /** 封面块：分类色渐变 + 白色分类图标 */
  @Builder
  coverBlock(blockWidth: Length, blockHeight: Length, glyph: number, radius: number) {
    Stack() {
      // 已上传封面 → 图片盖满；未上传 → 分类色渐变 + 图标（原设计）
      if (this.activity.coverUrl() !== '') {
        Image(this.activity.coverUrl())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        appIcon(BizDict.actIcon(this.activity.category), glyph, AppTheme.textOnPrimary)
      }
    }
    .width(blockWidth)
    .height(blockHeight)
    .borderRadius(radius)
    .linearGradient({
      angle: 135,
      colors: [
        [ToneColors.gradStart(BizDict.actTone(this.activity.category)), 0.0],
        [ToneColors.gradEnd(BizDict.actTone(this.activity.category)), 1.0]
      ]
    })
  }

  /** 时间 · 距离（没算距离时自动只显示时间） */
  @Builder
  timeLine() {
    Row() {
      appIcon(IconPath.CLOCK, 13, AppTheme.textHint)
      Text(DateFmt.mdhm(this.activity.startTime))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)
        .margin({ left: 4 })

      if (this.activity.hasDistance()) {
        Row()
          .width(3)
          .height(3)
          .borderRadius(2)
          .backgroundColor(AppTheme.textHint)
          .margin({ left: 6, right: 6 })

        Text(this.activity.distance.toFixed(1))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
        Text($r('app.string.common_unit_km'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .margin({ left: 1 })
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  /** 底部：左「时长」胶囊，右「已报名 x/y」+ 已满标 */
  @Builder
  bottomLine() {
    Row() {
      Row() {
        Text(this.activity.serviceHours.toString())
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.primary)
        Text($r('app.string.common_unit_hour'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.primary)
          .margin({ left: 2 })
      }
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .backgroundColor(AppTheme.primaryLight)
      .borderRadius(6)

      Blank()

      Text($r('app.string.common_signed_count'))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textHint)
      Text(this.activity.joinedCount.toString() + '/' + this.activity.needCount.toString())
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)
        .margin({ left: 4 })

      if (this.activity.isFull()) {
        PillTag({ text: $r('app.string.common_full'), tone: TagTone.RED, solid: true })
          .margin({ left: 6 })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 紧凑行的第二行：'周六 09:00 · 3h · 0.8km'
   * 时间走 DateFmt.dayHm —— 三天内显示「明天 / 后天」，一周内显示星期，更远回落 'mm-dd'。
   *
   * ⚠️ `$r()` 返回 Resource 对象，**不能参与字符串拼接**（会拼出 "[object Object]" 且编译零告警），
   *   所以数字与单位拆成相邻的 Text/Span，「·」和空格写在纯字符串那一段里。
   */
  @Builder
  compactMeta() {
    Row() {
      Text() {
        Span(this.metaHead())
          .fontSize(AppTheme.fontSecondary)
          .fontColor(AppTheme.textSecondary)
        Span($r('app.string.common_unit_hour_short'))
          .fontSize(AppTheme.fontSecondary)
          .fontColor(AppTheme.textSecondary)
      }
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.activity.hasDistance()) {
        Text() {
          Span(' · ' + this.activity.distance.toFixed(1))
            .fontSize(AppTheme.fontSecondary)
            .fontColor(AppTheme.textSecondary)
          Span($r('app.string.common_unit_km'))
            .fontSize(AppTheme.fontSecondary)
            .fontColor(AppTheme.textSecondary)
        }
        .maxLines(1)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  /** '周六 09:00 · 3'（单位「h」由调用处的 Span 补上，不能拼进来） */
  private metaHead(): string {
    return DateFmt.dayHm(this.activity.startTime) + ' · ' + this.activity.serviceHours.toString();
  }

  /** 首页大卡：通栏封面（feature 用） */
  @Builder
  featureBody() {
    this.coverBlock('100%', 132, 44, 0)

    Column() {
      Row() {
        Text(this.activity.title)
          .fontSize(AppTheme.fontTitleCard)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        PillTag({
          text: BizDict.actStatusLabel(this.activity.status),
          tone: BizDict.actStatusTone(this.activity.status),
          solid: true
        })
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row() {
        PillTag({
          text: BizDict.actLabel(this.activity.category),
          tone: BizDict.actTone(this.activity.category)
        })
      }
      .margin({ top: 8 })

      Row() {
        this.timeLine()
      }
      .width('100%')
      .margin({ top: 8 })

      Row() {
        this.bottomLine()
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 14 })
    .alignItems(HorizontalAlign.Start)
  }

  /** 列表横排卡（list 用） */
  @Builder
  listBody() {
    Row() {
      this.coverBlock(92, 92, 34, 12)

      Column() {
        Text(this.activity.title)
          .fontSize(AppTheme.fontTitleCard)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row() {
          PillTag({
            text: BizDict.actLabel(this.activity.category),
            tone: BizDict.actTone(this.activity.category)
          })
          PillTag({
            text: BizDict.actStatusLabel(this.activity.status),
            tone: BizDict.actStatusTone(this.activity.status)
          })
            .margin({ left: 6 })
        }
        .margin({ top: 6 })

        Row() {
          this.timeLine()
        }
        .width('100%')
        .margin({ top: 6 })

        Row() {
          this.bottomLine()
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding(AppTheme.cardPadding)
  }

  /** 紧凑行（compact 用）—— 首页「本周推荐 / 志愿活动」列表 */
  @Builder
  compactBody() {
    Row() {
      this.coverBlock(56, 56, 24, 12)

      Column() {
        Text(this.activity.title)
          .fontSize(AppTheme.fontTitleCard)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row() {
          this.compactMeta()
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)

      // 已报名的活动不再显示橙色「报名」，避免用户以为还能再点一次
      Text(this.activity.signedUp
        ? $r('app.string.signup_status_signed_up')
        : $r('app.string.common_signup_action'))
        .fontSize(AppTheme.fontSecondary)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.activity.signedUp ? AppTheme.textHint : AppTheme.primary)
        .margin({ left: 10 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 14, top: 12, bottom: 12 })
  }

  build() {
    Column() {
      if (this.mode === CardMode.FEATURE) {
        this.featureBody()
      } else if (this.mode === CardMode.COMPACT) {
        this.compactBody()
      } else {
        this.listBody()
      }
    }
    .width('100%')
    .backgroundColor(AppTheme.surface)
    .borderRadius(this.mode === CardMode.COMPACT ? AppTheme.cardRadiusSmall : AppTheme.cardRadius)
    .clip(true)
    .onClick(() => {
      this.onTap(this.activity.id);
    })
  }
}
