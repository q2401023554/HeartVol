import { AppTheme, TagTone } from '../common/AppTheme';
import { appIcon, IconPath, lineIcon, LinePath } from '../common/AppIcon';
import { DateFmt } from '../common/DateFmt';
import { Activity } from '../model/Activity';
import { HelpRequest } from '../model/HelpRequest';
import { VolunteerService } from '../service/VolunteerService';
import { HelpService } from '../service/HelpService';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { PillTag } from '../components/PillTag';
import { RouteParams } from '../common/RouteParams';
import { Result } from '../model/Result';

/** 发布列表分段 */
class PubTab {
  static readonly ACTIVITY: number = 0;
  static readonly HELP: number = 1;
}

/**
 * MyPublishPage —— 我的发布（发布者管理入口）
 * 两段式：我发布的活动（可看报名数/签到二维码）/ 我发布的求助。
 * 点任意一行进对应详情页 —— 详情页里已有发布者专享的签到二维码入口与会话。
 */
@Entry
@Component
struct MyPublishPage {
  @State loading: boolean = true;
  @State segIndex: number = PubTab.ACTIVITY;
  @State listTick: number = 0;
  private activities: Activity[] = [];
  private helps: HelpRequest[] = [];

  /** 删除活动后由详情页发信号 → 重拉列表 */
  @StorageProp('mypubRefresh') @Watch('onPubRefresh') pubRefresh: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  onPubRefresh(): void {
    if (this.pubRefresh > 0) {
      this.load();
    }
  }

  private async load(): Promise<void> {
    try {
      this.activities = await VolunteerService.myPublished();
      this.helps = await HelpService.myPublished();
    } catch (err) {
      // 拉取失败保持空数组 → 空态
    }
    this.loading = false;
    this.listTick = this.listTick + 1;
  }

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  private openActivity(id: number): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ActivityDetailPage',
        params: RouteParams.activityDetail(id)
      });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  private openHelp(id: number): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/HelpDetailPage',
        params: RouteParams.helpDetail(id)
      });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  /** 进管理活动子页 */
  private openManage(id: number): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ManageActivityPage',
        params: RouteParams.activityDetail(id)
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


  /** 活动状态文案 */
  private actStatus(item: Activity): string {
    if (item.status === 'signuping') {
      return '招募中';
    }
    if (item.status === 'ongoing') {
      return '进行中';
    }
    if (item.status === 'finished') {
      return '已结束';
    }
    return item.status;
  }

  /** 求助状态文案 */
  private helpStatus(item: HelpRequest): string {
    const s: string = item.status;
    if (s === 'pending') {
      return '待接单';
    }
    if (s === 'accepted') {
      return '进行中';
    }
    if (s === 'finished') {
      return '已完成';
    }
    return s;
  }

  @Builder
  segBar() {
    Row() {
      Row() {
        Text('我的活动')
          .fontSize(AppTheme.fontSecondary)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.segIndex === PubTab.ACTIVITY ? AppTheme.textOnPrimary : AppTheme.textSecondary)
      }
      .layoutWeight(1)
      .height(34)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.segIndex === PubTab.ACTIVITY ? AppTheme.primary : Color.Transparent)
      .borderRadius(17)
      .onClick(() => {
        this.segIndex = PubTab.ACTIVITY;
      })

      Row() {
        Text('我的求助')
          .fontSize(AppTheme.fontSecondary)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.segIndex === PubTab.HELP ? AppTheme.textOnPrimary : AppTheme.textSecondary)
      }
      .layoutWeight(1)
      .height(34)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.segIndex === PubTab.HELP ? AppTheme.primary : Color.Transparent)
      .borderRadius(17)
      .onClick(() => {
        this.segIndex = PubTab.HELP;
      })
    }
    .width('100%')
    .padding(3)
    .backgroundColor(AppTheme.fillGray)
    .borderRadius(20)
  }

  /** 活动行：标题 + 时间 + 状态/报名数 */
  @Builder
  activityRow(item: Activity, index: number) {
    Row() {
      Column() {
        Text(item.title)
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(DateFmt.md(item.startTime) + ' ' + DateFmt.weekday(item.startTime) + ' · 报名 ' +
          item.joinedCount.toString() + '/' + item.needCount.toString())
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      PillTag({ text: this.actStatus(item), tone: item.status === 'signuping' ? TagTone.ORANGE : TagTone.GRAY })
        .margin({ left: 8 })

      // 管理钮：进管理活动子页（改信息 / 删除）
      Text($r('app.string.mypub_manage'))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.primary)
        .padding({ left: 9, right: 5, top: 5, bottom: 5 })
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          this.openManage(item.id);
        })

      appIcon(IconPath.CHEVRON_RIGHT, 12, AppTheme.textHint)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(13)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .onClick(() => {
      this.openActivity(item.id);
    })
  }

  /** 求助行：标题 + 悬赏 + 状态 */
  @Builder
  helpRow(item: HelpRequest, index: number) {
    Row() {
      Column() {
        Text(item.title)
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text('悬赏 ' + item.rewardPoint.toString() + ' 积分 · ' + DateFmt.md(item.createTime))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      PillTag({ text: this.helpStatus(item), tone: item.status === 'pending' ? TagTone.ORANGE : TagTone.GRAY })
        .margin({ left: 8 })

      appIcon(IconPath.CHEVRON_RIGHT, 12, AppTheme.textHint)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(13)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .onClick(() => {
      this.openHelp(item.id);
    })
  }

  build() {
    Column() {
      PageHeader({
        title: $r('app.string.mypub_title'),
        onBack: (): void => {
          this.back();
        }
      })

      Column() {
        this.segBar()

        if (this.loading) {
          LoadingOverlay({ text: $r('app.string.common_loading') })
        } else if (this.segIndex === PubTab.ACTIVITY) {
          if (this.activities.length === 0) {
            Column() {
              EmptyState({
                title: $r('app.string.mypub_empty_act'),
                showSubtitle: false
              })
            }
            .margin({ top: 60 })
          } else {
            Column() {
              ForEach(this.activities, (item: Activity, index: number) => {
                Column() {
                  this.activityRow(item, index)
                }
                .width('100%')
                .margin({ top: 9 })
              }, (item: Activity, index: number) => 'act-' + item.id.toString() + '-' + this.listTick.toString())
            }
            .width('100%')
            .margin({ top: 9 })
          }
        } else {
          if (this.helps.length === 0) {
            Column() {
              EmptyState({
                title: $r('app.string.mypub_empty_help'),
                showSubtitle: false
              })
            }
            .margin({ top: 60 })
          } else {
            Column() {
              ForEach(this.helps, (item: HelpRequest, index: number) => {
                Column() {
                  this.helpRow(item, index)
                }
                .width('100%')
                .margin({ top: 9 })
              }, (item: HelpRequest, index: number) => 'help-' + item.id.toString() + '-' + this.listTick.toString())
            }
            .width('100%')
            .margin({ top: 9 })
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 10 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
