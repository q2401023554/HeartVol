import { AppTheme } from '../common/AppTheme';
import { appIcon, IconPath } from '../common/AppIcon';
import { BizDict } from '../common/BizDict';
import { HelpRequest } from '../model/HelpRequest';
import { PillTag } from './PillTag';

/**
 * HelpCard —— 互助求助卡片
 *
 * 结构（照设计稿 `鸿志愿_互助大厅_消息中心_我的_界面稿.png` + 两轮真机反馈）：
 *   ① 首行：标题（左，占满） + 橙色悬赏角标「30 积分」
 *   ② 次行：期望时间 + 地点 + 距离（「今天 18:00 前 · 韵苑 12 栋 · 0.3km」）
 *   ③ 末行：状态标签（待接单绿 / 进行中黄）+ 发布者「学院 · 姓名」
 *            + 尾部「我要接单」（仅待接单时显示）
 *
 * 互助大厅、「我的求助」、「我的接单」三处共用；尾部动作按钮只在 `onAction` 非空
 * 且 status === pending 时显示，其余上下文尾部留空。
 *
 * 【用法】
 *   HelpCard({ help: item, onTap: (id: number) => { this.openDetail(id) } })
 *   HelpCard({ help: item, onAction: (id: number) => { this.accept(id) },
 *              onTap: (id: number) => { this.openDetail(id) } })
 */
@Component
export struct HelpCard {
  help: HelpRequest = new HelpRequest();
  onTap: (id: number) => void = (id: number) => {
  };
  /** 尾部绿色「我要接单」动作；不传则不显示该按钮（详情页 / 我的求助里用不上） */
  onAction: (id: number) => void = (id: number) => {
  };

  /** 是否显示尾部「我要接单」：有回调 + 待接单 */
  private showAction(): boolean {
    return this.help.canAccept() && this.onAction !== undefined;
  }

  /** 发布者文案：「计算机学院 · 李同学」，两段都可能缺，逐段拼接 */
  private publisherText(): string {
    const p = this.help.publisher;
    if (p === null) {
      return '';
    }
    const college: string = p.college === '' ? '' : p.college;
    const name: string = p.name === '' ? '' : p.name;
    if (college === '') {
      return name;
    }
    if (name === '') {
      return college;
    }
    return college + ' · ' + name;
  }

  build() {
    Column() {
      // ① 标题 + 悬赏角标
      Row() {
        Text(this.help.title)
          .fontSize(AppTheme.fontTitleCard)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text() {
          Span(this.help.rewardPoint.toString() + ' ')
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
          Span($r('app.string.common_unit_point'))
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
        }
        .padding({ left: 7, right: 7, top: 2, bottom: 2 })
        .backgroundColor(AppTheme.primaryLight)
        .borderRadius(9)
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // ② 期望时间 · 地点 · 距离（距离并入本行，第三行只留状态/发布者/动作，不再拥挤）
      Text() {
        Span(this.help.expectTime)
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
        if (this.help.address !== '') {
          Span(' · ' + this.help.address)
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
        }
        if (this.help.hasDistance()) {
          Span(' · ' + this.help.distance.toFixed(1))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
          Span($r('app.string.common_unit_km'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
        }
      }
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
      .margin({ top: 6 })

      // ③ 状态 + 发布者 + 尾部动作
      Row() {
        PillTag({
          text: BizDict.helpStatusLabel(this.help.status),
          tone: BizDict.helpStatusTone(this.help.status),
          solid: true
        })

        if (this.publisherText() !== '') {
          Text(this.publisherText())
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textHint)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 6 })
        } else {
          Blank()
        }

        if (this.showAction()) {
          // 橙色实心胶囊（用户定稿）：与全 App「橙=可点动作」语言统一（立即报名/发布等），
          // 也与「待接单」绿标签拉开颜色；绿只保留给互助域的状态/入口。
          Row() {
            Text($r('app.string.help_btn_accept'))
              .fontSize(AppTheme.fontSecondary)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textOnPrimary)
          }
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(AppTheme.primary)
          .borderRadius(13)
          .margin({ left: 8 })
          .onClick(() => {
            this.onAction(this.help.id);
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(AppTheme.cardPadding)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .onClick(() => {
      this.onTap(this.help.id);
    })
  }
}
