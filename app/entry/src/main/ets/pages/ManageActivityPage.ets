import { AppTheme, TagTone } from '../common/AppTheme';
import { DateFmt } from '../common/DateFmt';
import { Activity } from '../model/Activity';
import { PublishActivityBody } from '../model/ActivityOps';
import { VolunteerService } from '../service/VolunteerService';
import { PageHeader } from '../components/PageHeader';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { PillTag } from '../components/PillTag';
import { RouteParams, ActivityDetailParams } from '../common/RouteParams';
import { Result } from '../model/Result';

/**
 * ManageActivityPage —— 管理活动子页（我的发布 → 管理钮进入）
 * 只能发布者进入（服务端二次校验）：改活动信息（标题/地点/时间/人数/时长/描述）+ 删除活动。
 * 删除/保存成功后发 mypubRefresh 信号，返回时列表自动刷新。
 */
@Entry
@Component
struct ManageActivityPage {
  @State loading: boolean = true;
  @State saving: boolean = false;
  @State statusText: string = '';
  @State title: string = '';
  @State place: string = '';
  @State time: string = '';
  @State quota: string = '';
  @State hours: string = '';
  @State description: string = '';

  private activity: Activity = new Activity();

  aboutToAppear(): void {
    try {
      const raw: Object | undefined = this.getUIContext().getRouter().getParams() as ActivityDetailParams;
      const p: ActivityDetailParams = raw as ActivityDetailParams;
      this.load(p.activityId ?? 0);
    } catch (err) {
      this.loading = false;
    }
  }

  private async load(id: number): Promise<void> {
    const act: Activity | null = await VolunteerService.detail(id);
    if (act === null || act.id === 0) {
      this.loading = false;
      this.toast($r('app.string.mypub_del_fail'));
      return;
    }
    this.activity = act;
    this.title = act.title;
    this.place = act.address;
    // 显示时间：'2026-09-26 08:30:00' → '09-26 周六 08:30 - 10:30'
    this.time = DateFmt.md(act.startTime) + ' ' + DateFmt.weekday(act.startTime) + ' ' +
      act.startTime.substring(11, 16) + ' - ' + act.endTime.substring(11, 16);
    this.quota = act.needCount.toString();
    this.hours = act.serviceHours.toString();
    this.description = act.description;
    this.statusText = act.status === 'signuping' ? '招募中'
      : (act.status === 'ongoing' ? '进行中' : '已结束');
    this.loading = false;
  }

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时无操作
    }
  }

  private toast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      // toast 失败不影响主流程
    }
  }

  /** 「09-26 周六 14:00 - 16:00」→ ['yyyy-MM-dd 14:00:00', 'yyyy-MM-dd 16:00:00']（同发布页规则） */
  private parseTime(display: string): string[] {
    const year: number = new Date().getFullYear();
    const parts: string[] = display.split(' ');
    let md: string = parts.length > 0 ? parts[0] : '';
    let startHm: string = '09:00';
    let endHm: string = '11:00';
    const range: string[] = display.split(' - ');
    if (range.length >= 2) {
      startHm = range[0].trim();
      endHm = range[1].trim();
      startHm = startHm.split(' ')[startHm.split(' ').length - 1];
      endHm = endHm.split(' ')[endHm.split(' ').length - 1];
    }
    const start: string = year + '-' + md + ' ' + startHm + ':00';
    const end: string = year + '-' + md + ' ' + endHm + ':00';
    return [start, end];
  }

  /** 保存修改：构造全量字段（cover/lat/lng 沿用原值），提交后返回 */
  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    if (this.title.trim() === '') {
      this.toast($r('app.string.publish_need_title'));
      return;
    }
    this.saving = true;
    const startEnd: string[] = this.parseTime(this.time);
    const body: PublishActivityBody = new PublishActivityBody(
      this.title, this.activity.category, this.description,
      this.place, this.activity.lat, this.activity.lng,
      startEnd[0], startEnd[1],
      Number(this.quota) || 0, Number(this.hours) || 0);
    // cover 沿用原值（空串=服务端跳过更新，不清掉已上传封面）
    body.cover = this.activity.cover;
    try {
      const res: Result<boolean> = await VolunteerService.updateActivity(this.activity.id, body);
      this.saving = false;
      if (res.isOk()) {
        AppStorage.setOrCreate('mypubRefresh', Date.now());
        this.toast($r('app.string.manage_saved'));
        this.back();
      } else {
        const msg: ResourceStr = res.message !== '' ? res.message : $r('app.string.manage_save_fail');
        this.toast(msg);
      }
    } catch (err) {
      this.saving = false;
      this.toast($r('app.string.manage_save_fail'));
    }
  }

  /** 删除活动：确认弹窗 → 删除 → 信号刷新 → 返回 */
  private confirmDelete(): void {
    AlertDialog.show({
      title: $r('app.string.mypub_del_confirm_title'),
      message: $r('app.string.mypub_del_confirm_msg'),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {
          // 取消
        }
      },
      secondaryButton: {
        value: $r('app.string.mypub_del_ok'),
        fontColor: AppTheme.badgeRed,
        action: () => {
          this.doDelete();
        }
      }
    });
  }

  private async doDelete(): Promise<void> {
    try {
      const res: Result<boolean> = await VolunteerService.deleteActivity(this.activity.id);
      if (res.isOk()) {
        AppStorage.setOrCreate('mypubRefresh', Date.now());
        this.toast($r('app.string.mypub_del_done'));
        this.back();
      } else {
        const msg: ResourceStr = res.message !== '' ? res.message : $r('app.string.mypub_del_fail');
        this.toast(msg);
      }
    } catch (err) {
      this.toast($r('app.string.mypub_del_fail'));
    }
  }

  @Builder
  fieldLabel(label: ResourceStr) {
    Text(label)
      .fontSize(AppTheme.fontCaption)
      .fontColor(AppTheme.textSecondary)
      .margin({ top: 14 })
  }

  @Builder
  textInput(text: string, onChange: (v: string) => void) {
    TextInput({ text: text })
      .fontSize(AppTheme.fontBody)
      .fontColor(AppTheme.textPrimary)
      .backgroundColor(AppTheme.fillGray)
      .borderRadius(9)
      .height(42)
      .padding({ left: 12, right: 12 })
      .margin({ top: 6 })
      .onChange((v: string) => {
        onChange(v);
      })
  }

  build() {
    Column() {
      PageHeader({
        title: $r('app.string.manage_title'),
        onBack: (): void => {
          this.back();
        }
      })

      if (this.loading) {
        Column() {
          LoadingOverlay({ text: $r('app.string.common_loading') })
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        Column() {
          Scroll() {
            Column() {
              // 状态行
              Row() {
                Text($r('app.string.manage_status_label'))
                  .fontSize(AppTheme.fontCaption)
                  .fontColor(AppTheme.textSecondary)
                PillTag({ text: this.statusText,
                  tone: this.statusText === '招募中' ? TagTone.ORANGE : TagTone.GRAY })
                  .margin({ left: 8 })
                Blank()
              }
              .width('100%')
              .margin({ top: 4 })

              this.fieldLabel($r('app.string.publish_label_title'))
              this.textInput(this.title, (v: string) => {
                this.title = v;
              })

              this.fieldLabel($r('app.string.publish_label_time'))
              this.textInput(this.time, (v: string) => {
                this.time = v;
              })

              this.fieldLabel($r('app.string.publish_label_place'))
              this.textInput(this.place, (v: string) => {
                this.place = v;
              })

              Row() {
                Column() {
                  this.fieldLabel($r('app.string.publish_label_quota'))
                  this.textInput(this.quota, (v: string) => {
                    this.quota = v;
                  })
                }
                .layoutWeight(1)

                Column() {
                  this.fieldLabel($r('app.string.publish_label_hours'))
                  this.textInput(this.hours, (v: string) => {
                    this.hours = v;
                  })
                }
                .layoutWeight(1)
                .margin({ left: 10 })
              }
              .width('100%')

              this.fieldLabel($r('app.string.publish_label_desc'))
              TextArea({ text: this.description })
                .fontSize(AppTheme.fontBody)
                .fontColor(AppTheme.textPrimary)
                .backgroundColor(AppTheme.fillGray)
                .borderRadius(9)
                .height(90)
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .margin({ top: 6 })
                .onChange((v: string) => {
                  this.description = v;
                })

              // 保存修改
              Text($r('app.string.manage_save'))
                .fontSize(AppTheme.fontBody)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.textOnPrimary)
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(44)
                .backgroundColor(this.saving ? AppTheme.textHint : AppTheme.primary)
                .borderRadius(22)
                .margin({ top: 24 })
                .onClick(() => {
                  this.save();
                })

              // 删除活动
              Text($r('app.string.mypub_del_entry'))
                .fontSize(AppTheme.fontCaption)
                .fontColor(AppTheme.badgeRed)
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding({ top: 14, bottom: 6 })
                .onClick(() => {
                  this.confirmDelete();
                })

              Row()
                .width('100%')
                .height(20)
            }
            .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
