import { AppTheme } from '../common/AppTheme';
import { lineIcon, LinePath } from '../common/AppIcon';
import { TokenStore } from '../common/TokenStore';
import { BASE_URL } from '../common/Constants';
import { Result } from '../model/Result';
import { User } from '../model/User';
import { PublishActivityBody, PublishResult } from '../model/ActivityOps';
import { HttpUtil } from '../common/HttpUtil';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { VolunteerService } from '../service/VolunteerService';
import { PageHeader } from '../components/PageHeader';

/** 表单控件几何值 —— 设计稿一次性值 1:1 取 vp */
const INPUT_H: number = 38;
const INPUT_RADIUS: number = 11;
const DRAFT_TIP_SIZE: number = 26;

/** 分类胶囊槽位 —— 顺序与 ActivityCategory 对齐，选中态默认「校园服务」（照设计稿草稿） */
class ActCat {
  static readonly CAMPUS: number = 0;
  static readonly ENV: number = 1;
  static readonly TEACH: number = 2;
  static readonly ELDER: number = 3;
  static readonly GAME: number = 4;
}

/**
 * PublishActivityPage —— 发布活动
 *
 * 版式照 `UI\鸿志愿_扫码签到_签到成功_发布活动表单_界面稿.png`：
 *   ① 顶栏：返回 + 「发布活动」+ 右上「存草稿」
 *   ② 小鸿提示条（橙浅底）：「鸿」圆标 + 「已按你刚才那句话填好草稿」+ 橙色「查看对话记录 ›」
 *   ③ 表单卡：活动标题（**橙描边高亮 —— 表示由小鸿填好**）/ 分类胶囊 / 活动时间 /
 *      集合地点 / 招募人数·志愿时长（双列）/ 活动描述
 *   ④ 底部橙色「发布活动」
 *
 * 【标题框为什么高亮】设计稿里标题框是 FFF8F4 底 + 橙描边，其余输入框是灰底 ——
 *   这是「小鸿已填好」的视觉语言，与提示条文案呼应；用户改过标题后不再高亮
 *   （@State titleEdited 置位即回落灰底，草稿感消失、变成普通编辑态）。
 *
 * 【预填值】U 阶段直接填演示草稿（标题/时间/地点/人数/时长），
 *   G2 阶段由 AgentView 的「去修改/一键发布」带参回填，本页结构不变。
 */
@Entry
@Component
struct PublishActivityPage {
  /** 选中的分类下标 */
  @State categoryIndex: number = ActCat.CAMPUS;
  /** 用户是否手动改过标题（改过就不再显示「草稿高亮」描边） */
  @State titleEdited: boolean = false;

  /** 已上传的封面 URL（BASE_URL 全址，空=未上传） */
  @State coverUrl: string = '';
  @State uploading: boolean = false;
  /** 草稿预填值（@State：输入框要双向显示） */
  @State title: string = '图书馆图书整理志愿服务';
  @State time: string = '09-26 周六 14:00 - 16:00';
  @State place: string = '南湖图书馆 3 楼';
  @State quota: string = '10';
  @State hours: string = '2';
  @State description: string = '';
  /** 发布中：防重复提交 */
  @State submitting: boolean = false;

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  /** D3：放宽到 ResourceStr，便于展示后端返回的业务文案 */
  private toast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      // toast 失败不影响主流程
    }
  }

  /**
   * D3 后半：真实发布。
   * 页面 `time` 是展示串（如「09-26 周六 14:00 - 16:00」），后端要 yyyy-MM-dd HH:mm:ss，
   * 所以这里做一次解析；地点暂用当前用户坐标（地图选点是占位，F2 接入定位后替换）。
   */
  private async onPublish(): Promise<void> {
    if (this.title === '') {
      this.toast($r('app.string.publish_need_title'));
      return;
    }
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    const startEnd: string[] = PublishActivityPage.parseTime(this.time);
    const me: User | null = TokenStore.currentUser();
    const body: PublishActivityBody = new PublishActivityBody(
      this.title, PublishActivityPage.categoryCode(this.categoryIndex), this.description,
      this.place, me !== null ? me.lat : 0, me !== null ? me.lng : 0,
      startEnd[0], startEnd[1],
      PublishActivityPage.toInt(this.quota, 10), PublishActivityPage.toInt(this.hours, 2));
    // 封面相对路径（/uploads/x.jpg）：展示端用 coverUrl() 拼 BASE_URL
    if (this.coverUrl !== '') {
      body.cover = this.coverUrl.replace(BASE_URL, '');
    }

    try {
      const res: Result<PublishResult> = await VolunteerService.publish(body);
      this.submitting = false;
      if (!res.isOk()) {
        this.toast($r('app.string.publish_fail'));
        return;
      }
      // 通知志愿大厅重拉列表（Tab 组件不重建，靠信号刷新）
      AppStorage.setOrCreate('pubRefresh', Date.now());
      this.toast($r('app.string.publish_success'));
      this.back();
    } catch (err) {
      this.submitting = false;
      this.toast($r('app.string.publish_fail'));
    }
  }

  /** 分类序号 → 后端分类码（与 ActCat 顺序一致） */
  private static categoryCode(index: number): string {
    if (index === ActCat.ENV) {
      return 'env';
    }
    if (index === ActCat.TEACH) {
      return 'teach';
    }
    if (index === ActCat.ELDER) {
      return 'elder';
    }
    if (index === ActCat.GAME) {
      return 'game';
    }
    return 'campus';
  }

  /** 「09-26 周六 14:00 - 16:00」→ ['2026-09-26 14:00:00', '2026-09-26 16:00:00'] */
  private static parseTime(display: string): string[] {
    const year: number = new Date().getFullYear();
    let md: string = '';
    let startHm: string = '09:00';
    let endHm: string = '11:00';
    // 形如 "09-26 周六 14:00 - 16:00"：先按空格切，取日期段与时间区间
    const parts: string[] = display.split(' ');
    if (parts.length > 0) {
      md = parts[0];
    }
    const joined: string = display.replace('-', '-');
    const range: string[] = joined.split(' - ');
    if (range.length >= 2) {
      startHm = range[0].trim();
      endHm = range[1].trim();
      // 起点可能带日期前缀（"09-26 周六 14:00"）→ 只取最后的 HH:mm
      const sParts: string[] = startHm.split(' ');
      startHm = sParts[sParts.length - 1];
      const eParts: string[] = endHm.split(' ');
      endHm = eParts[eParts.length - 1];
    }
    const date: string = year + '-' + md;
    return [date + ' ' + startHm + ':00', date + ' ' + endHm + ':00'];
  }

  private static toInt(text: string, fallback: number): number {
    const n: number = parseInt(text);
    return isNaN(n) ? fallback : n;
  }

  // ==================== 局部 UI ====================

  /** ② 小鸿提示条（与 PublishHelpPage 的区别：这里是「已填好草稿」+ 查看对话记录） */
  @Builder
  agentTipCard() {
    Row() {
      Row() {
        Text($r('app.string.agent_badge'))
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textOnPrimary)
      }
      .width(DRAFT_TIP_SIZE)
      .height(DRAFT_TIP_SIZE)
      .borderRadius(DRAFT_TIP_SIZE / 2)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.primaryGradientStart)

      Column() {
        Text($r('app.string.publish_agent_tip'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textPrimary)
          .lineHeight(18)
          .width('100%')

        Row() {
          Text($r('app.string.publish_agent_link'))
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
          Text(' ›')
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
        }
        .margin({ top: 5 })
        .onClick(() => {
          this.toast('封面图上传功能即将上线');
        })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 9 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding(11)
    .backgroundColor(AppTheme.primaryLight)
    .borderRadius(14)
    .margin({ top: 12 })
  }

  /** ③ 字段标签（topGap 防链属性） */
  @Builder
  fieldLabel(text: Resource, topGap: number) {
    Text(text)
      .fontSize(AppTheme.fontCaption)
      .fontColor(AppTheme.textSecondary)
      .width('100%')
      .margin({ top: topGap })
  }

  /** ③ 灰底已填输入框（onChange 用回调收值，@Builder 形参一次定对） */
  @Builder
  filledInput(text: string, onChange: (v: string) => void) {
    TextInput({ text: text })
      .height(INPUT_H)
      .width('100%')
      .padding({ left: 11, right: 11 })
      .backgroundColor(AppTheme.fillGray)
      .borderRadius(INPUT_RADIUS)
      .fontSize(AppTheme.fontSecondary)
      .fontColor(AppTheme.textPrimary)
      .caretColor(AppTheme.primary)
      .margin({ top: 6 })
      .onChange((v: string) => {
        onChange(v);
      })
  }

  /** 选封面：PhotoViewPicker 免权限 → 上传 /api/upload → 记录全址 URL */
  private async pickCover(): Promise<void> {
    if (this.uploading) {
      return;
    }
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const opts: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      const sel: photoAccessHelper.PhotoSelectResult = await picker.select(opts);
      if (sel.photoUris.length === 0) {
        return;
      }
      this.uploading = true;
      const res: Result<string> = await HttpUtil.uploadImage(sel.photoUris[0]);
      this.uploading = false;
      if (!res.isOk() || res.data === '') {
        this.toast(res.message !== '' ? res.message : '上传失败，请重试');
        return;
      }
      this.coverUrl = res.data ?? '';
      this.toast($r('app.string.publish_cover_ok'));
    } catch (err) {
      this.uploading = false;
      // 选图/上传链路任何异常都给出反馈（不再静默——之前用户看不到任何提示）
      this.toast('选择图片失败，请重试');
    }
  }

  /** ③ 封面上传块：已上传显示图片预览（可重选），未上传显示加号占位 */
  @Builder
  coverUpload() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.coverUrl !== '') {
        Image(this.coverUrl)
          .width('100%')
          .height('100%')
          .borderRadius(11)
          .objectFit(ImageFit.Cover)
          .onClick(() => {
            this.pickCover();
          })
      } else {
        Row() {
          Column() {
            lineIcon(LinePath.PLUS, 20, AppTheme.textHint)
            Text($r('app.string.publish_cover_add'))
              .fontSize(AppTheme.fontCaption)
              .fontColor(AppTheme.textHint)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.fillGray)
        .onClick(() => {
          this.pickCover();
        })
      }

      if (this.uploading) {
        Text($r('app.string.publish_cover_uploading'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textOnPrimary)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(AppTheme.primary)
          .borderRadius(11)
          .margin(8)
      }
    }
    .width('100%')
    .height(96)
    .borderRadius(11)
    .margin({ top: 6 })
  }

  /** ③ 地点行：输入框 + 右侧「地图选点」图钉按钮（详情页地址尾部是导航箭头，发布侧是选点，闭环）。
   *  U 阶段点击仅提示；D/F 阶段接 Map Kit 选点页，回填地址与 lat/lng。 */
  @Builder
  placeInput(text: string, onChange: (v: string) => void) {
    Row() {
      TextInput({ text: text })
        .layoutWeight(1)
        .height('100%')
        .padding(0)
        .backgroundColor(Color.Transparent)
        .fontSize(AppTheme.fontSecondary)
        .fontColor(AppTheme.textPrimary)
        .caretColor(AppTheme.primary)
        .onChange((v: string) => {
          onChange(v);
        })

      Row() {
        lineIcon(LinePath.PIN, 14, AppTheme.primary)
      }
      .width(28)
      .height(28)
      .borderRadius(14)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.surface)
      .margin({ left: 6 })
      .onClick(() => {
        this.toast('地图选点功能即将上线');
      })
    }
    .width('100%')
    .height(38)
    .padding({ left: 11, right: 5 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.fillGray)
    .borderRadius(11)
    .margin({ top: 6 })
  }

  /** ③ 标题框：未改动时用「草稿高亮」（橙浅底 + 橙描边），改过回落灰底 */
  @Builder
  titleInput() {
    TextInput({ text: this.title })
      .height(INPUT_H + 12)
      .width('100%')
      .padding({ left: 11, right: 11 })
      .backgroundColor(this.titleEdited ? AppTheme.fillGray : AppTheme.primaryLight)
      .borderRadius(INPUT_RADIUS)
      .border({
        width: this.titleEdited ? 0 : 1,
        color: AppTheme.primary
      })
      .fontSize(AppTheme.fontSecondary)
      .fontColor(AppTheme.textPrimary)
      .caretColor(AppTheme.primary)
      .margin({ top: 6 })
      .onChange((v: string) => {
        this.title = v;
        this.titleEdited = true;
      })
  }

  /** ③ 分类胶囊 */
  @Builder
  categoryChips() {
    Row() {
      this.chip(ActCat.CAMPUS, $r('app.string.filter_campus'))
      this.chip(ActCat.ENV, $r('app.string.filter_env'))
      this.chip(ActCat.TEACH, $r('app.string.filter_teach'))
      this.chip(ActCat.ELDER, $r('app.string.filter_elder'))
      this.chip(ActCat.GAME, $r('app.string.filter_game'))
    }
    .width('100%')
    .margin({ top: 6 })
  }

  @Builder
  chip(slot: number, label: Resource) {
    Text(label)
      .fontSize(AppTheme.fontCaption)
      .fontColor(slot === this.categoryIndex ? AppTheme.textOnPrimary : AppTheme.textSecondary)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(slot === this.categoryIndex ? AppTheme.primary : AppTheme.fillGray)
      .borderRadius(11)
      .margin({ right: 6 })
      .onClick(() => {
        this.categoryIndex = slot;
      })
  }

  build() {
    Column() {
      PageHeader({
        title: $r('app.string.publish_activity_title'),
        showAction: true,
        actionText: $r('app.string.common_save_draft'),
        actionColor: AppTheme.textSecondary,
        onBack: () => {
          this.back();
        },
        onAction: () => {
          this.toast('草稿保存功能即将上线');
        }
      })

      Scroll() {
        Column() {
          this.agentTipCard()

          Column() {
            this.fieldLabel($r('app.string.publish_label_cover'), 0)
            this.coverUpload()

            this.fieldLabel($r('app.string.publish_label_title'), 12)
            this.titleInput()

            this.fieldLabel($r('app.string.publish_label_category'), 12)
            this.categoryChips()

            this.fieldLabel($r('app.string.publish_label_time'), 12)
            this.filledInput(this.time, (v: string) => {
              this.time = v;
            })

            this.fieldLabel($r('app.string.publish_label_gather'), 12)
            this.placeInput(this.place, (v: string) => {
              this.place = v;
            })

            Row() {
              Column() {
                this.fieldLabel($r('app.string.publish_label_quota'), 0)
                this.filledInput(this.quota, (v: string) => {
                  this.quota = v;
                })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Column() {
                this.fieldLabel($r('app.string.publish_label_hours'), 0)
                this.filledInput(this.hours, (v: string) => {
                  this.hours = v;
                })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 9 })
            }
            .width('100%')
            .margin({ top: 12 })

            this.fieldLabel($r('app.string.publish_label_desc'), 12)
            TextArea({ placeholder: $r('app.string.publish_label_desc'), text: this.description })
              .height(72)
              .width('100%')
              .padding({ left: 11, right: 11, top: 9, bottom: 9 })
              .backgroundColor(AppTheme.fillGray)
              .borderRadius(INPUT_RADIUS)
              .fontSize(AppTheme.fontSecondary)
              .fontColor(AppTheme.textPrimary)
              .placeholderColor(AppTheme.textHint)
              .caretColor(AppTheme.primary)
              .margin({ top: 6 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .backgroundColor(AppTheme.surface)
          .borderRadius(AppTheme.cardRadius)
          .margin({ top: 12 })

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

      Column() {
        Row() {
          Text($r('app.string.publish_activity_title'))
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
          this.onPublish();
        })
      }
      .width('100%')
      .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 12, bottom: 14 })
      .backgroundColor(AppTheme.surface)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
