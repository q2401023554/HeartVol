import { AppTheme, ToneColors } from '../common/AppTheme';
import { appIcon, IconPath, lineIcon, LinePath, personLineIcon } from '../common/AppIcon';
import { ParticipantRef } from '../model/Activity';
import { BizDict } from '../common/BizDict';
import { DateFmt } from '../common/DateFmt';
import { RouteParams, ActivityDetailParams } from '../common/RouteParams';
import { Activity } from '../model/Activity';
import { User } from '../model/User';
import { TokenStore } from '../common/TokenStore';
import { Result } from '../model/Result';
import { VolunteerService } from '../service/VolunteerService';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { thinDivider } from '../components/Divider';
import { call } from '@kit.TelephonyKit';
import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { map, mapCommon, MapComponent } from '@kit.MapKit';
import { ToastUtil } from '../common/ToastUtil';

/**
 * 顶部封面高度。
 * 设计稿是 120px —— 本工程对「组件内部一次性几何值」一贯按 1:1 取 vp
 * （缩略图 92/56、圆点 3、行内图标 13/14/21/34/44 都是这么来的），
 * 所以这里也写 120，而不是用 AppTheme.coverHeight（那个 180 是首页 FEATURE 大卡的规格）。
 */
const COVER_H: number = 120;
/** 封面上两颗悬浮圆钮（返回 / 分享）的直径 */
const OVERLAY_BTN: number = 28;
/** 参与者头像直径与叠放偏移 */
const AVATAR_SIZE: number = 20;
const AVATAR_OVERLAP: number = 7;

/** 封面上两颗粒钮的槽位编号 —— 与 cover() 里的调用顺序严格一致 */
class OverlaySlot {
  static readonly BACK: number = 0;
  static readonly SHARE: number = 1;
}

/**
 * ActivityDetailPage —— 活动详情
 *
 * 版式照 `UI\鸿志愿_启动页_登录页_活动详情_界面稿.png`，自上而下：
 *   ① 顶部封面（120vp）：左上返回圆钮 + 发布者胶囊，右上「联系」+ 分享圆钮
 *   ② 白卡（上圆角 16、上移 14 压住封面）：标题 / 2×2 信息格 / 分割线 /
 *      活动介绍 / 分割线 / 参与者 (n) + 叠放头像 + ›
 *   ③ 底部**固定**操作条：灰胶囊提示 + 橙色主按钮（立即报名 / 扫码签到）
 *
 * 【为什么不做封面轮播（「1/3」+ 三个圆点）】
 *   工程里一个图片资源都没有，封面统一是「分类色渐变 + 白色分类图标」
 *   （见 ActivityCard 的 coverBlock）。只有一张封面时画轮播指示器是假的，
 *   所以省掉；等 B 阶段后端能下发 cover 列表了，在 cover() 外面套一层 Swiper 即可。
 *
 * 【入参】从路由参数取 activityId，取不到就展示空状态（不再像 U5 那样写死占位）。
 *
 * 【为什么 signedUp 用 @State 而 activity 用普通成员】
 *   点「立即报名」后底部条要立刻变成「扫码签到」，所以 signedUp 必须是可观察状态；
 *   而 Activity 是「带方法的类」（要调 isFull()/remainCount()），加 @State 有丢方法风险，
 *   它只在加载完成后被读，普通成员够了。
 */
/**
 * SignInQrDialog —— 发布者专享「签到二维码」弹窗
 * 用 ArkUI 内置 QRCode 组件系统级生成（零三方库、零权限）；白底黑码保证扫得出。
 * code/titleText 用 @Link：弹窗打开前页面才把已加载的活动数据写进来。
 */
@CustomDialog
struct SignInQrDialog {
  /** 弹窗控制器：@CustomDialog 必须持有，框架打开时自动注入 */
  controller!: CustomDialogController;
  /** 6 位签到码（= 二维码内容，扫码端正则提取它） */
  @Link code: string;
  /** 活动标题（弹窗里显示用） */
  @Link titleText: string;

  build() {
    Column() {
      Text($r('app.string.detail_qr_title'))
        .fontSize(AppTheme.fontTitleSection)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
        .margin({ top: 18 })

      // QRCode 组件：内容就是签到码本身；白底黑码对比度最高，系统相机也认
      Column() {
        QRCode(this.code)
          .width(190)
          .height(190)
          .color(Color.Black)
      }
      .backgroundColor(Color.White)
      .padding(14)
      .borderRadius(14)
      .margin({ top: 14 })

      Text(this.titleText)
        .fontSize(AppTheme.fontSecondary)
        .fontColor(AppTheme.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 12, left: 24, right: 24 })

      Row() {
        Text($r('app.string.detail_qr_code_label'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
        Text(this.code)
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.primary)
          .margin({ left: 8 })
      }
      .alignItems(VerticalAlign.Center)
      .margin({ top: 8 })

      Text($r('app.string.detail_qr_hint'))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textHint)
        .textAlign(TextAlign.Center)
        .lineHeight(18)
        .margin({ top: 10, left: 24, right: 24 })

      Text($r('app.string.detail_qr_ok'))
        .fontSize(AppTheme.fontSecondary)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textOnPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(40)
        .backgroundColor(AppTheme.primary)
        .borderRadius(20)
        .margin({ top: 16 })
        .onClick(() => {
          this.controller.close();
        })
    }
    .width(320)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .padding({ bottom: 20 })
  }
}

@Entry
@Component
struct ActivityDetailPage {
  @State loading: boolean = true;
  /** 详情没取到（id 非法 / 已下架）→ 显示空状态 */
  private notFound: boolean = false;
  private activity: Activity = new Activity();
  /** 我是否已报名（决定底部主按钮是「立即报名」还是「扫码签到」） */
  @State signedUp: boolean = false;
  /** 报名中：防重复点击 */
  @State submitting: boolean = false;
  /** 签到二维码弹窗的数据（@Link 双向：open 前写入，弹窗即显最新值） */
  @State qrCode: string = '';
  @State qrActivityTitle: string = '';
  private qrCtrl: CustomDialogController = new CustomDialogController({
    builder: SignInQrDialog({ code: this.qrCode, titleText: this.qrActivityTitle }),
    autoCancel: true,
    customStyle: true
  });

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const id: number = this.readActivityId();
    if (id <= 0) {
      this.notFound = true;
      this.loading = false;
      return;
    }
    try {
      const detail: Activity | null = await VolunteerService.detail(id);
      if (detail === null) {
        this.notFound = true;
      } else {
        this.activity = detail;
        this.signedUp = detail.signedUp;
      }
    } catch (err) {
      this.notFound = true;
    }
    this.loading = false;
  }

  /**
   * 从路由参数取活动 id。
   * `getParams()` 声明返回 `Object`（不可空），但页面被直接打开时实际可能拿不到东西，
   * 所以整个取值过程包在 try 里 —— 拿不到就回落 0，由调用方走空状态，不用额外的判空分支。
   */
  private readActivityId(): number {
    try {
      const raw: Object = this.getUIContext().getRouter().getParams();
      const params: ActivityDetailParams = raw as ActivityDetailParams;
      return params.activityId ?? 0;
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

  private goto(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: url });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  /** D3：参数放宽到 ResourceStr —— 后端返回的业务文案是 string（如「名额已满」） */
  private toast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      // toast 失败不影响主流程
    }
  }

  // ==================== 取数 ====================

  /** 发布者姓名（发布者卡用） */
  private publisherName(): string {
    if (this.activity.publisher === null) {
      return '';
    }
    return this.activity.publisher.name;
  }

  /** 我是不是本活动的发布者（签到二维码入口只有发布者可见） */
  private isPublisher(): boolean {
    const u: User | null = TokenStore.currentUser();
    return u !== null && this.activity.publisherId > 0 && u.id === this.activity.publisherId;
  }

  /** 打开签到二维码弹窗（open 前写 @Link 数据，弹窗即显最新值） */
  private showQr(): void {
    this.qrActivityTitle = this.activity.title;
    this.qrCode = this.activity.signinCode;
    this.qrCtrl.open();
  }


  private publisherCollege(): string {
    if (this.activity.publisher === null) {
      return '';
    }
    return this.activity.publisher.college;
  }

  private publisherCredit(): number {
    if (this.activity.publisher === null) {
      return 0;
    }
    return this.activity.publisher.creditScore;
  }

  /** 发布者联系电话（电话钮用；D 阶段可换 call.makeCall 直接拨号） */
  private publisherPhone(): string {
    if (this.activity.publisher === null) {
      return '';
    }
    return this.activity.publisher.phone;
  }

  /** '09-26 周六 09:00' */
  private timeText(): string {
    const t: string = this.activity.startTime;
    return DateFmt.md(t) + ' ' + DateFmt.weekday(t) + ' ' + DateFmt.hm(t);
  }

  /** '24 / 28'（单位「人」由 Span 单独拼，不能塞进 $r 里） */
  private quotaText(): string {
    return this.activity.joinedCount.toString() + ' / ' + this.activity.needCount.toString();
  }

  private overlayPath(slot: number): string {
    if (slot === OverlaySlot.BACK) {
      return LinePath.CHEVRON_LEFT;
    }
    return LinePath.SHARE;
  }

  private onOverlayTap(slot: number): void {
    if (slot === OverlaySlot.BACK) {
      this.back();
    } else {
      this.shareActivity();
    }
  }

  /** 底部灰胶囊里的提示文案 */
  private bottomTip(): ResourceStr {
    if (this.signedUp) {
      return $r('app.string.detail_tip_signuped');
    }
    if (this.activity.isFull()) {
      return $r('app.string.detail_tip_full');
    }
    return $r('app.string.detail_tip_remain', this.activity.remainCount());
  }

  private bottomActionText(): Resource {
    if (this.signedUp) {
      return $r('app.string.detail_btn_signin');
    }
    return $r('app.string.detail_btn_signup');
  }

  /**
   * D3 后半：真实报名。已报名 → 进扫码签到页；未报名 → 调接口后置位。
   * 失败时用**后端返回的文案**（名额已满 / 不在报名期 / 已报名过），比通用提示有用得多。
   */
  private async onPrimaryAction(): Promise<void> {
    if (this.signedUp) {
      this.goto('pages/ScanSignInPage');
      return;
    }
    if (this.activity === null) {
      return;
    }
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    const id: number = this.activity.id;
    try {
      const res: Result<boolean> = await VolunteerService.signup(id);
      this.submitting = false;
      if (res.isOk()) {
        this.signedUp = true;
        this.toast($r('app.string.detail_signup_success'));
        return;
      }
      this.toast(res.message !== '' ? res.message : $r('app.string.signup_fail'));
    } catch (err) {
      this.submitting = false;
      this.toast($r('app.string.signup_fail'));
    }
  }

  // ==================== 真实动作：分享 / 复制 / 拨号 ====================

  /** 分享活动：把关键信息拼成文本，走系统分享面板 */
  private shareActivity(): void {
    const text: string =
      '【鸿志愿】' + this.activity.title + '\n' +
      '时间：' + this.timeText() + '\n' +
      '地点：' + this.activity.address + '\n' +
      '志愿时长：' + this.activity.serviceHours.toString() + ' 小时';
    try {
      const ctx: common.UIAbilityContext =
        AppStorage.get('abilityContext') as common.UIAbilityContext;
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        content: text,
        title: this.activity.title
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      const opts: systemShare.ShareControllerOptions = {};
      controller.show(ctx, opts).catch(() => {
        ToastUtil.show('分享失败，请稍后重试');
      });
    } catch (err) {
      ToastUtil.show('分享失败，请稍后重试');
    }
  }

  /**
   * F2：geo: 协议拉起系统地图按地点搜索/导航（Petal Maps 等地图应用注册该协议）。
   * 无地图应用（模拟器常见）→ 复制地址兜底。不走 Map Kit 内嵌：省去 AGC 证书指纹配置。
   */
  private openMap(address: string, lat: number, lng: number): void {
    const addr: string = encodeURIComponent(address);
    const geoUri: string = lat !== 0
      ? 'geo:' + lat + ',' + lng + '?q=' + addr
      : 'geo:0,0?q=' + addr;
    const ctx: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (ctx === undefined) {
      this.copyText(address, '地址已复制');
      return;
    }
    ctx.openLink(geoUri).then(() => {
      // 已拉起地图应用
    }).catch(() => {
      this.copyText(address, '未找到地图应用，地址已复制');
    });
  }

  /** ② 内嵌地图（F2：Map Kit 真地图 + 活动 marker。
   *  ⚠️ 需在 module.json5 配 AGC 的 client_id，并把签名证书指纹登记到 AGC，否则瓦片不加载） */
  @Builder
  miniMap() {
    Column() {
      MapComponent({
        mapOptions: this.buildMapOptions(),
        mapCallback: this.mapCallback
      })
    }
    .width('100%')
    .height(150)
    .borderRadius(11)
    .clip(true)
  }

  private buildMapOptions(): mapCommon.MapOptions {
    const lat: number = this.activity.lat !== 0 ? this.activity.lat : 30.5123;
    const lng: number = this.activity.lng !== 0 ? this.activity.lng : 114.4315;
    return {
      position: {
        target: { latitude: lat, longitude: lng },
        zoom: 14
      },
      zoomControlsEnabled: false
    };
  }

  private mapCallback = (err: BusinessError, controller: map.MapComponentController) => {
    if (err) {
      return;
    }
    this.mapController = controller;
    const lat: number = this.activity.lat !== 0 ? this.activity.lat : 30.5123;
    const lng: number = this.activity.lng !== 0 ? this.activity.lng : 114.4315;
    controller.addMarker({
      position: { latitude: lat, longitude: lng },
      title: this.activity.title
    });
  };

  private mapController: map.MapComponentController | null = null;

  /** 复制文本到剪贴板 */
  private copyText(text: string, okMsg: string): void {
    try {
      const paste: pasteboard.PasteData = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN,
        text
      );
      const board = pasteboard.getSystemPasteboard();
      board.setData(paste).then(() => {
        ToastUtil.show(okMsg);
      }).catch(() => {
        ToastUtil.show('复制失败，请重试');
      });
    } catch (err) {
      ToastUtil.show('复制失败，请重试');
    }
  }

  /** 拨打发布者电话（call.makeCall 跳转到拨号界面并预填号码） */
  private callPublisher(): void {
    const phone: string = this.publisherPhone();
    if (phone === '') {
      ToastUtil.show('发布者暂未留下电话');
      return;
    }
    call.makeCall(phone).then(() => {
      // 已拉起拨号界面
    }).catch(() => {
      ToastUtil.show('无法拨号，请检查电话权限');
    });
  }

  // ==================== 局部 UI ====================

  /** 颗粒钮（封面上用）：深遮罩底 + 白图标 —— 与发布者/联系胶囊同一套浮层语言 */
  @Builder
  overlayBtn(slot: number) {
    Row() {
      lineIcon(this.overlayPath(slot), 15, AppTheme.textOnPrimary)
    }
    .width(OVERLAY_BTN)
    .height(OVERLAY_BTN)
    .borderRadius(OVERLAY_BTN / 2)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.coverScrim)
    .onClick(() => {
      this.onOverlayTap(slot);
    })
  }

  /** ① 封面 —— 分类色渐变 + 白色分类图标（工程零图片，与卡片封面同一套语言） */
  @Builder
  cover() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 有上传封面 → 图片盖满（返回/分享钮仍浮在最上层）；未上传 → 原分类色渐变
      if (this.activity.coverUrl() !== '') {
        Image(this.activity.coverUrl())
          .width('100%')
          .height(COVER_H)
          .objectFit(ImageFit.Cover)
      } else {
        Row()
          .width('100%')
          .height(COVER_H)
          .linearGradient({
            angle: 135,
            colors: [
              [ToneColors.gradStart(BizDict.actTone(this.activity.category)), 0.0],
              [ToneColors.gradEnd(BizDict.actTone(this.activity.category)), 1.0]
            ]
          })

        Row() {
          appIcon(BizDict.actIcon(this.activity.category), 44, AppTheme.textOnPrimary)
        }
        .width('100%')
        .height(COVER_H)
        .justifyContent(FlexAlign.Center)
        .opacity(0.45)
      }

      Row() {
        this.overlayBtn(OverlaySlot.BACK)

        Blank()

        // 发布者与联系人已按参考 UI 移入详情卡下方的「发布者卡」；
        // 封面只留返回与分享两颗圆钮，不再挂胶囊。
        // ⚠️ @Builder 的调用是语句，后面不能链通用属性 → 外边距要包一层 Row
        Row() {
          this.overlayBtn(OverlaySlot.SHARE)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 10, right: 10, top: 10 })
    }
    .width('100%')
    .height(COVER_H)
  }

  /** ② 标题 */
  @Builder
  titleBlock() {
    Text(this.activity.title)
      .fontSize(AppTheme.fontTitleCard)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.textPrimary)
      .width('100%')
  }

  /** ② 信息格（纯文字值） */
  @Builder
  infoItemPlain(label: Resource, value: string, highlight: boolean) {
    Column() {
      Text(label)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)

      Text(value)
        .fontSize(AppTheme.fontCaption)
        .fontWeight(highlight ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(highlight ? AppTheme.primary : AppTheme.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  /** ② 信息格（值带单位，「数字 + 空格」与单位拆成两个 Span） */
  @Builder
  infoItemUnit(label: Resource, value: string, unit: Resource, highlight: boolean) {
    Column() {
      Text(label)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)

      Text() {
        Span(value + ' ')
          .fontSize(AppTheme.fontCaption)
          .fontWeight(highlight ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(highlight ? AppTheme.primary : AppTheme.textPrimary)
        Span(unit)
          .fontSize(AppTheme.fontCaption)
          .fontColor(highlight ? AppTheme.primary : AppTheme.textSecondary)
      }
      .maxLines(1)
      .margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  /** ② 信息格（值带导航图标的地址格：icon 固定尾部，预留 D/F 阶段地图导航入口） */
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
          .margin({ top: 2 })

        Row() {
          lineIcon(LinePath.NAV, 14, AppTheme.primary)
        }
        .margin({ left: 4, top: 2 })
        .onClick(() => {
          // F2：geo: 协议跳系统地图导航（Petal Maps 等）；无地图应用时复制地址兜底
          this.openMap(this.activity.address, this.activity.lat, this.activity.lng);
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
        this.infoItemPlain($r('app.string.detail_label_time'), this.timeText(), false)
        this.infoItemNav($r('app.string.detail_label_place'), this.activity.address)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row() {
        this.infoItemUnit(
          $r('app.string.detail_label_hours'),
          this.activity.serviceHours.toString(),
          $r('app.string.common_unit_hour'),
          true
        )
        this.infoItemUnit(
          $r('app.string.detail_label_quota'),
          this.quotaText(),
          $r('app.string.common_unit_person'),
          false
        )
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ top: 10 })
    }
    .width('100%')
  }

  /** ② 卡内分割线（thinDivider 是全局 @Builder，不能链属性，用 Row 包一层给外边距） */
  @Builder
  blockDivider() {
    Row() {
      thinDivider()
    }
    .width('100%')
    .margin({ top: 12, bottom: 12 })
  }

  /** ② 参与者行：真实报名者姓名首字叠圈（最多 4 个）+「+N」；无报名者给引导文案 */
  @Builder
  participants() {
    Row() {
      Text() {
        Span($r('app.string.detail_section_participants'))
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
        Span(' (' + this.activity.joinedCount.toString() + ')')
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
      }

      if (this.activity.participants.length > 0) {
        Row() {
          ForEach(this.activity.participants.slice(0, 4), (p: ParticipantRef, index: number) => {
            Row() {
              Text(p.name === '' ? '志' : p.name.substring(0, 1))
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.primary)
            }
            .width(AVATAR_SIZE)
            .height(AVATAR_SIZE)
            .borderRadius(AVATAR_SIZE / 2)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(AppTheme.primaryLight)
            .margin({ left: index === 0 ? 0 : -AVATAR_OVERLAP })
          }, (p: ParticipantRef, index: number) => 'avatar-' + index.toString() + '-' + p.name)

          if (this.activity.joinedCount > 4) {
            Row() {
              Text('+' + (this.activity.joinedCount - 4).toString())
                .fontSize(9)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.textSecondary)
            }
            .width(AVATAR_SIZE)
            .height(AVATAR_SIZE)
            .borderRadius(AVATAR_SIZE / 2)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(AppTheme.fillGray)
            .margin({ left: -AVATAR_OVERLAP })
          }
        }
        .margin({ left: 8 })
      } else {
        Text($r('app.string.detail_no_participants'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textHint)
          .margin({ left: 8 })
      }

      Blank()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  /**
   * ② 发布者卡（照参考 UI：封面不再挂发布者/联系胶囊，挪到详情卡下方的独立卡片）。
   * 行1 头像 + 名字 + 「学院 · 信用分 n · 履约正常」；行2 活动联系人 + 电话按钮。
   * 电话/导航都是 U 阶段占位 toast，D/F 阶段接拨号与 Map Kit。
   */
  @Builder
  publisherCard() {
    Column() {
      Row() {
        Row() {
          personLineIcon(17, AppTheme.ringBlue)
        }
        .width(AVATAR_SIZE)
        .height(AVATAR_SIZE)
        .borderRadius(AVATAR_SIZE / 2)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.blueLight)

        Column() {
          Text(this.publisherName())
            .fontSize(AppTheme.fontSecondary)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text() {
            Span(this.publisherCollege() === '' ? '' : this.publisherCollege() + ' · ')
              .fontSize(AppTheme.fontCaption)
              .fontColor(AppTheme.textSecondary)
            Span($r('app.string.scan_credit'))
              .fontSize(AppTheme.fontCaption)
              .fontColor(AppTheme.accent)
            Span(' ' + this.publisherCredit().toString() + ' · ')
              .fontSize(AppTheme.fontCaption)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.accent)
            Span($r('app.string.scan_credit_ok'))
              .fontSize(AppTheme.fontCaption)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.accent)
          }
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
      .alignItems(VerticalAlign.Center)

      Row() {
        Text($r('app.string.detail_contact_row'))
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

        // 「联系」= 发消息；发布者视角文案为「回复咨询」（进会话列表）。电话圆钮 = 拨号。
        Row() {
          Text(this.isPublisher() ? $r('app.string.detail_contact_pub') : $r('app.string.detail_contact'))
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
          try {
            if (this.isPublisher()) {
              // 发布者：同一活动可能有多个咨询者（各一条会话）→ 进会话列表逐个回复
              this.getUIContext().getRouter().pushUrl({ url: 'pages/ChatListPage' });
            } else {
              // 咨询者：直接与发布者开聊（服务端自行算对端）
              this.getUIContext().getRouter().pushUrl({
                url: 'pages/ChatPage',
                params: RouteParams.chatPage('activity', this.activity.id, this.publisherName(), 0)
              });
            }
          } catch (err) {
            // 跳转失败留在当前页
          }
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
          this.callPublisher();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 10 })

      // 发布者专享：签到二维码入口（码源从此在 App 里，不再依赖外部二维码工具）
      if (this.isPublisher() && this.activity.signinCode !== '') {
        Row() {
          lineIcon(LinePath.SCAN, 15, AppTheme.primary)
          Text($r('app.string.detail_qr_entry'))
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
            .margin({ left: 6 })
          Blank()
          appIcon(IconPath.CHEVRON_RIGHT, 12, AppTheme.textHint)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ top: 12 })
        .onClick(() => {
          this.showQr();
        })
      }

    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(13)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 10 })
  }

  /** ② 白卡（上移 14 压住封面，只圆上面两个角） */
  @Builder
  detailCard() {
    Column() {
      this.titleBlock()

      Row() {
        this.infoGrid()
      }
      .width('100%')
      .margin({ top: 10 })

      this.blockDivider()

      Text(this.activity.description)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)
        .lineHeight(18)
        .width('100%')

      this.blockDivider()

      this.participants()

      this.blockDivider()

      this.miniMap()

      Row()
        .width('100%')
        .height(24)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(AppTheme.surface)
    .borderRadius({
      topLeft: AppTheme.cardRadius,
      topRight: AppTheme.cardRadius,
      bottomLeft: 0,
      bottomRight: 0
    })
    .margin({ top: -14 })
  }

  /** ③ 底部固定操作条：灰胶囊提示 + 橙色主按钮 */
  @Builder
  bottomBar() {
    Row() {
      Row() {
        Text(this.bottomTip())
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .height(AppTheme.buttonHeight)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppTheme.fillGray)
      .borderRadius(AppTheme.pillRadius)

      Row() {
        Text(this.bottomActionText())
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textOnPrimary)
      }
      .height(AppTheme.buttonHeight)
      .padding({ left: 22, right: 22 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppTheme.primary)
      .borderRadius(AppTheme.pillRadius)
      .margin({ left: 8 })
      .onClick(() => {
        this.onPrimaryAction();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 8, bottom: 8 })
    .backgroundColor(AppTheme.surface)
  }

  /** 正常态页面：可滚动的封面 + 白卡，底部固定操作条 */
  @Builder
  body() {
    Column() {
      Scroll() {
        Column() {
          this.cover()
          this.detailCard()
          this.publisherCard()
        }
        .width('100%')
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
          PageHeader({
            title: $r('app.string.activity_detail_title'),
            onBack: () => {
              this.back();
            }
          })

          Column() {
            EmptyState({
              iconPath: IconPath.INBOX,
              title: $r('app.string.detail_no_activity'),
              showSubtitle: false
            })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })
        }
        .width('100%')
        .height('100%')
      } else {
        this.body()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
