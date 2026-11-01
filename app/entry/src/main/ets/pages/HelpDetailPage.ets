import { AppTheme } from '../common/AppTheme';
import { appIcon, IconPath, lineIcon, LinePath } from '../common/AppIcon';
import { BizDict } from '../common/BizDict';
import { DateFmt } from '../common/DateFmt';
import { HelpDetailParams, RouteParams } from '../common/RouteParams';
import { HelpRequest } from '../model/HelpRequest';
import { HelpReview } from '../model/HelpReview';
import { HelpService } from '../service/HelpService';
import { TokenStore, CTX_KEY } from '../common/TokenStore';
import { common } from '@kit.AbilityKit';
import { Result } from '../model/Result';
import { PillTag } from '../components/PillTag';
import { EmptyState } from '../components/EmptyState';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { thinDivider } from '../components/Divider';

/** 发布者头像直径与互评星尺寸 */
const AVATAR_SIZE: number = 34;
const STAR_SIZE: number = 13;
/** 评价弹窗星尺寸 */
const DIALOG_STAR_SIZE: number = 28;

/**
 * ReviewDialog —— 互助互评弹窗（D5）
 * 选 1~5 星 + 短评，提交后回调 onSubmit(score, content)。
 */
@CustomDialog
struct ReviewDialog {
  /** 弹窗控制器：@CustomDialog 必须持有 CustomDialogController 类型字段，
   *  框架会在打开时自动注入真实 reviewCtrl（无需在 builder 里传参） */
  controller!: CustomDialogController;
  /** 当前选择的星级（默认 5） */
  score: number = 5;
  /** 短评内容 */
  content: string = '';
  /** 提交回调（由宿主页注入） */
  onSubmit: (score: number, content: string) => void = (score: number, content: string) => {
  };

  private starList(): boolean[] {
    const out: boolean[] = [];
    for (let i = 0; i < 5; i++) {
      out.push(i < this.score);
    }
    return out;
  }

  build() {
    Column() {
      Text($r('app.string.help_review_title'))
        .fontSize(AppTheme.fontTitleSection)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
        .margin({ top: 16, bottom: 12 })

      // 星条（点哪颗星，其及之前全亮）
      Row() {
        ForEach(this.starList(), (on: boolean, idx: number) => {
          Row() {
            appIcon(IconPath.STAR, DIALOG_STAR_SIZE, on ? AppTheme.ringYellow : AppTheme.textHint)
          }
          .margin({ left: idx === 0 ? 0 : 10 })
          .onClick(() => {
            this.score = idx + 1;
          })
        }, (on: boolean, idx: number) => 'd-star-' + idx.toString())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 12 })

      TextArea({ placeholder: $r('app.string.help_review_hint'), text: this.content })
        .height(64)
        .width('100%')
        .padding({ left: 11, right: 11, top: 9, bottom: 9 })
        .backgroundColor(AppTheme.fillGray)
        .borderRadius(11)
        .fontSize(AppTheme.fontSecondary)
        .fontColor(AppTheme.textPrimary)
        .placeholderColor(AppTheme.textHint)
        .caretColor(AppTheme.primary)
        .onChange((v: string) => {
          this.content = v;
        })
        .margin({ bottom: 14 })

      Row() {
        Row() {
          Text($r('app.string.common_cancel'))
            .fontSize(AppTheme.fontBody)
            .fontColor(AppTheme.textSecondary)
        }
        .layoutWeight(1)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.fillGray)
        .borderRadius(12)
        .onClick(() => {
          this.controller.close();
        })

        Row() {
          Text($r('app.string.help_btn_review'))
            .fontSize(AppTheme.fontBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textOnPrimary)
        }
        .layoutWeight(1)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.primary)
        .borderRadius(12)
        .margin({ left: 10 })
        .onClick(() => {
          this.onSubmit(this.score, this.content);
        })
      }
      .width('100%')
      .margin({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.surface)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }
}

/**
 * HelpDetailPage —— 求助详情
 *
 * 版式照 `UI\鸿志愿_求助详情_发布求助_注册页_界面稿.png`：
 *   ① 顶栏（44vp）：返回 ‹ + 发布者头像 + 发布者名 + 右上「联系」
 *   ② 求助信息卡：标题 + 橙色悬赏角标 / 分类 + 状态标签 / 2×2 信息格
 *      （期望完成 / 求助地点 / 发布时间 / 距离）/ 求助描述
 *   ③ 发布者卡：信用分 + 头像 + 名字·学院 + 已发布 N 条 · 完成 N 单
 *   ④ 双方互评（仅已完成且有评价时）：每人一行「名字 + 星条 + 短评」
 *   ⑤ 底部固定操作条：灰色提示胶囊 + 绿色主按钮
 *
 * 【底部按钮态】由 detail 的 isPublisher / isHelper / status / reviewedByMe 决定（D5 接真实后端）：
 *   · 待接单 + 非发布者        → 「我要接单」（POST /api/helps/{id}/accept）
 *   · 进行中 + 发布者           → 「确认完成」（POST /api/helps/{id}/finish）
 *   · 进行中 + 接单人           → 无主按钮，提示「等待发布者确认」
 *   · 已完成 + 未评价           → 「评价对方」（弹 ReviewDialog → POST /api/helps/orders/{orderId}/review）
 *   · 已完成 + 已评价 / 已取消   → 无主按钮，展示互评
 */
@Entry
@Component
struct HelpDetailPage {
  @State loading: boolean = true;
  private notFound: boolean = false;
  private detail: HelpRequest = new HelpRequest();
  /** 评价弹窗控制器（D5） */
  private reviewCtrl: CustomDialogController = new CustomDialogController({
    builder: ReviewDialog({
      onSubmit: (score: number, content: string) => {
        this.submitReview(score, content);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -20 }
  });

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const id: number = this.readHelpId();
    if (id <= 0) {
      this.notFound = true;
      this.loading = false;
      return;
    }
    try {
      const detail: HelpRequest | null = await HelpService.detail(id);
      if (detail === null) {
        this.notFound = true;
      } else {
        this.detail = detail;
      }
    } catch (err) {
      this.notFound = true;
    }
    this.loading = false;
  }

  /** 接单 / 完成 / 评价后重新拉详情，刷新 isHelper / status / reviewedByMe / order / reviews */
  private async reloadDetail(): Promise<void> {
    const id: number = this.detail.id;
    if (id <= 0) {
      return;
    }
    try {
      const d: HelpRequest | null = await HelpService.detail(id);
      if (d !== null) {
        this.detail = d;
      }
    } catch (err) {
      // 刷新失败不阻塞，保留旧数据
    }
  }

  private readHelpId(): number {
    try {
      const raw: Object = this.getUIContext().getRouter().getParams();
      const params: HelpDetailParams = raw as HelpDetailParams;
      return params.helpId ?? 0;
    } catch (err) {
      return 0;
    }
  }

  // ==================== 导航 / 提示 ====================

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  private toast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      // toast 失败不影响主流程
    }
  }

  // ==================== 取数 ====================

  private publisherName(): string {
    const p = this.detail.publisher;
    return p === null ? '' : p.name;
  }

  private publisherCollege(): string {
    const p = this.detail.publisher;
    return p === null ? '' : p.college;
  }

  private publisherCredit(): number {
    const p = this.detail.publisher;
    return p === null ? 0 : p.creditScore;
  }

  /** F2：geo: 协议拉起系统地图；失败提示地址本身 */
  private openMap(address: string, lat: number, lng: number): void {
    const addr: string = encodeURIComponent(address);
    const geoUri: string = lat !== 0
      ? 'geo:' + lat + ',' + lng + '?q=' + addr
      : 'geo:0,0?q=' + addr;
    const ctx: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (ctx === undefined) {
      this.toast('求助地址：' + address);
      return;
    }
    ctx.openLink(geoUri).then(() => {
      // 已拉起地图应用
    }).catch(() => {
      this.toast('未找到地图应用。求助地址：' + address);
    });
  }

  /** 打开与对方的聊天（简化版 IM）：我是发布者→找接单者聊；我是接单者→找发布者聊 */
  private openChat(): void {
    const me = TokenStore.currentUser();
    const myId: number = me === null ? 0 : me.id;
    const isPub: boolean = this.detail.isPublisher;
    const order = this.detail.order;
    const helperId: number = order === null ? 0 : order.helperId;
    if (!isPub && helperId !== myId) {
      this.toast('接单后方可与发布者沟通');
      return;
    }
    // 对方姓名：接单者看到发布者名（页面已有）；发布者的对方姓名由聊天页接口补
    const peer: string = isPub ? '' : this.publisherName();
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ChatPage',
        params: RouteParams.chatPage('help', this.detail.id, peer, 0)
      });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  private publisherInitial(): string {    const p = this.detail.publisher;
    return p === null ? '?' : p.nameInitial();
  }

  /** 已发布 / 完成 的描述行：「已发布 2 条求助 · 完成 5 单」。用静态演示值占位。 */
  private publisherMeta(): string {
    return '已发布 2 条求助 · 完成 5 单';
  }

  private distanceText(): string {
    if (!this.detail.hasDistance()) {
      return '';
    }
    return this.detail.distance.toFixed(1) + ' km';
  }

  private createTimeText(): string {
    return DateFmt.mdhm(this.detail.createTime);
  }

  // ==================== 底部按钮判定 ====================

  /** 是否显示主按钮 */
  private showPrimary(): boolean {
    const status: string = this.detail.status;
    // 已评价：不再显示主按钮
    if (this.detail.reviewedByMe) {
      return false;
    }
    // 已完成：显示「评价对方」
    if (status === 'finished') {
      return true;
    }
    // 进行中 + 发布者：显示「确认完成」
    if (status === 'ongoing' && this.detail.isPublisher) {
      return true;
    }
    // 待接单 + 非发布者：显示「我要接单」
    if (status === 'pending' && !this.detail.isPublisher) {
      return true;
    }
    return false;
  }

  private primaryText(): Resource {
    const status: string = this.detail.status;
    if (status === 'finished') {
      return $r('app.string.help_btn_review');
    }
    if (status === 'ongoing') {
      return $r('app.string.help_btn_finish');
    }
    return $r('app.string.help_btn_accept');
  }

  private tipText(): ResourceStr {
    const status: string = this.detail.status;
    if (status === 'finished') {
      return $r('app.string.help_tip_done');
    }
    if (this.detail.isPublisher) {
      return status === 'ongoing' ? $r('app.string.help_tip_doing') : $r('app.string.help_tip_waiting');
    }
    if (this.detail.isHelper) {
      return $r('app.string.help_tip_helper_doing');
    }
    return $r('app.string.help_accept_success');
  }

  private async onPrimaryAction(): Promise<void> {
    const status: string = this.detail.status;
    if (this.detail.reviewedByMe) {
      this.toast($r('app.string.help_btn_reviewed'));
      return;
    }
    // 已完成 → 打开评价弹窗
    if (status === 'finished') {
      this.reviewCtrl.open();
      return;
    }
    // 进行中 + 发布者 → 确认完成
    if (status === 'ongoing' && this.detail.isPublisher) {
      const res: Result<boolean> = await HelpService.finish(this.detail.id);
      if (res.isOk()) {
        this.toast($r('app.string.help_finish_success'));
        await this.reloadDetail();
      } else {
        this.toast(res.message);
      }
      return;
    }
    // 待接单 + 非发布者 → 接单
    if (status === 'pending' && !this.detail.isPublisher) {
      const res: Result<boolean> = await HelpService.accept(this.detail.id);
      if (res.isOk()) {
        this.toast($r('app.string.help_accept_success'));
        await this.reloadDetail();
      } else {
        this.toast(res.message);
      }
      return;
    }
    this.toast('当前状态下无法接单');
  }

  /** 评价提交（由 ReviewDialog 回调） */
  private async submitReview(score: number, content: string): Promise<void> {
    const orderId: number = this.detail.order === null ? 0 : this.detail.order.id;
    if (orderId <= 0) {
      this.toast('暂无可评价的订单');
      return;
    }
    const res: Result<boolean> = await HelpService.review(orderId, score, content);
    if (res.isOk()) {
      this.reviewCtrl.close();
      this.toast($r('app.string.help_review_done'));
      await this.reloadDetail();
    } else {
      this.toast(res.message);
    }
  }

  // ==================== 局部 UI ====================

  /** ① 顶栏 */
  @Builder
  header() {
    Row() {
      Row() {
        lineIcon(LinePath.CHEVRON_LEFT, 20, AppTheme.textPrimary)
      }
      .width(48)
      .height(44)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.back();
      })

      Row()
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor(AppTheme.blueLight)

      Text(this.publisherName())
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 7 })

      Blank()
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
  }

  /** ② 信息格（纯文字值） */
  @Builder
  infoCell(label: Resource, value: string, highlight: boolean) {
    Column() {
      Text(label)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)
      Text(value)
        .fontSize(AppTheme.fontCaption)
        .fontWeight(highlight ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(highlight ? AppTheme.accent : AppTheme.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 3 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  /** ② 信息格（地址带导航图标：与活动详情同款，预留 D/F 阶段地图导航入口） */
  @Builder
  infoItemNav(label: Resource, value: string) {
    Column() {
      Text(label)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)

      Row() {
        Text(value)
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ top: 3 })

        Row() {
          lineIcon(LinePath.NAV, 14, AppTheme.primary)
        }
        .margin({ left: 4, top: 3 })
        .onClick(() => {
          // F2：geo: 跳系统地图；无地图应用时提示地址
          this.openMap(this.detail.address, this.detail.lat, this.detail.lng);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  /** ② 2×2 信息格 */
  @Builder
  infoGrid() {
    Column() {
      Row() {
        this.infoCell($r('app.string.help_label_expect'), this.detail.expectTime, false)
        this.infoItemNav($r('app.string.help_label_place'), this.detail.address)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row() {
        this.infoCell($r('app.string.help_label_publish_time'), this.createTimeText(), false)
        this.infoCell($r('app.string.help_label_distance'), this.distanceText(), true)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ top: 10 })
    }
    .width('100%')
  }

  /** 卡内分割线 */
  @Builder
  blockDivider() {
    Row() {
      thinDivider()
    }
    .width('100%')
    .margin({ top: 12, bottom: 12 })
  }

  /** ② 求助信息卡 */
  @Builder
  infoCard() {
    Column() {
      Row() {
        Text(this.detail.title)
          .fontSize(AppTheme.fontTitleCard)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .lineHeight(20)
          .layoutWeight(1)

        Text() {
          Span(this.detail.rewardPoint.toString() + ' ')
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
          Span($r('app.string.common_unit_point'))
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
        }
        .padding({ left: 9, right: 9, top: 3, bottom: 3 })
        .backgroundColor(AppTheme.primaryLight)
        .borderRadius(10)
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row() {
        PillTag({
          text: BizDict.helpLabel(this.detail.category),
          tone: BizDict.helpTone(this.detail.category)
        })
        PillTag({
          text: BizDict.helpStatusLabel(this.detail.status),
          tone: BizDict.helpStatusTone(this.detail.status),
          solid: true
        })
          .margin({ left: 7 })
      }
      .width('100%')
      .margin({ top: 9 })

      this.blockDivider()

      this.infoGrid()

      this.blockDivider()

      Text(this.detail.description)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)
        .lineHeight(19)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 12 })
  }

  /** ③ 发布者卡（联系=发消息、电话=拨号，均 D 阶段占位） */
  @Builder
  publisherCard() {
    Column() {
      Row() {
        Text($r('app.string.help_publisher'))
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)

        Blank()

        Text() {
          Span($r('app.string.help_credit_prefix'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.accent)
          Span(' ' + this.publisherCredit().toString())
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.accent)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Row() {
          Text(this.publisherInitial())
            .fontSize(AppTheme.fontBody)
            .fontColor(AppTheme.textPrimary)
        }
        .width(AVATAR_SIZE)
        .height(AVATAR_SIZE)
        .borderRadius(AVATAR_SIZE / 2)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.blueLight)

        Column() {
          Text(this.publisherName() + ' · ' + this.publisherCollege())
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.publisherMeta())
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textHint)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 9 })
      }
      .width('100%')
      .margin({ top: 10 })

      Row() {
        Text($r('app.string.help_contact_row'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)

        Text(this.publisherName())
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 6 })

        Blank()

        Row() {
          Text($r('app.string.detail_contact'))
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textOnPrimary)
        }
        .height(30)
        .padding({ left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(AppTheme.primary)
        .borderRadius(15)
        .margin({ right: 8 })
        .onClick(() => {
          this.openChat();
        })

        Row() {
          lineIcon(LinePath.PHONE, 15, AppTheme.primary)
        }
        .width(30)
        .height(30)
        .borderRadius(15)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.fillGray)
        .onClick(() => {
          const p = this.detail.publisher;
          this.toast(p === null || p.phone === '' ? '发布者暂未留下电话' : '发布者电话：' + p.phone);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 10 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(13)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 10 })
  }

  /** ④ 一条互评：名字 + 星条 + 短评 */
  @Builder
  reviewRow(r: HelpReview) {
    Column() {
      Row() {
        Text(r.fromUserName)
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)

        Row() {
          ForEach(this.starList(r.score), (on: boolean, idx: number) => {
            Row() {
              appIcon(IconPath.STAR, STAR_SIZE, on ? AppTheme.ringYellow : AppTheme.textHint)
            }
            .margin({ left: idx === 0 ? 0 : 1 })
          }, (on: boolean, idx: number) => 'star-' + idx.toString())
        }
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(r.content)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)
        .lineHeight(18)
        .width('100%')
        .margin({ top: 5 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 9, bottom: 9 })
  }

  /** 星条：前 score 颗亮、其余灰 */
  private starList(score: number): boolean[] {
    const out: boolean[] = [];
    for (let i = 0; i < 5; i++) {
      out.push(i < score);
    }
    return out;
  }

  /** ④ 双方互评卡（仅已完成且有评价时整卡显示） */
  @Builder
  reviewCard() {
    Column() {
      Text($r('app.string.help_review_title'))
        .fontSize(AppTheme.fontCaption)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
        .width('100%')

      ForEach(this.detail.reviews, (r: HelpReview) => {
        this.reviewRow(r)
      }, (r: HelpReview) => 'review-' + r.id.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(13)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 10 })
  }

  private hasReviews(): boolean {
    return this.detail.reviews.length > 0;
  }

  /** ⑤ 底部固定操作条 */
  @Builder
  bottomBar() {
    Row() {
      Row() {
        Text(this.tipText())
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .height(38)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppTheme.fillGray)
      .borderRadius(19)

      if (this.showPrimary()) {
        Row() {
          Text(this.primaryText())
            .fontSize(AppTheme.fontBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textOnPrimary)
        }
        .height(38)
        .padding({ left: 18, right: 18 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(AppTheme.primary)
        .borderRadius(19)
        .margin({ left: 8 })
        .onClick(() => {
          this.onPrimaryAction();
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 12, bottom: 14 })
    .backgroundColor(AppTheme.surface)
  }

  /** 正常态页面 */
  @Builder
  body() {
    Column() {
      Scroll() {
        Column() {
          this.infoCard()
          this.publisherCard()
          if (this.hasReviews()) {
            this.reviewCard()
          }
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
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingOverlay({ text: $r('app.string.common_loading') })
      } else if (this.notFound) {
        Column() {
          this.header()
          Column() {
            EmptyState({
              iconPath: IconPath.INBOX,
              title: $r('app.string.help_no_request'),
              showSubtitle: false
            })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height('100%')
      } else {
        Column() {
          this.header()
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
