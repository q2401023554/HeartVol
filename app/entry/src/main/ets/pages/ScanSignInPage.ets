import { AppTheme } from '../common/AppTheme';
import { lineIcon, LinePath } from '../common/AppIcon';
import { DateFmt } from '../common/DateFmt';
import { Signup } from '../model/Signup';
import { User } from '../model/User';
import { Result } from '../model/Result';
import { SigninResult } from '../model/ActivityOps';
import { MineService } from '../service/MineService';
import { VolunteerService } from '../service/VolunteerService';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { thinDivider } from '../components/Divider';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common, abilityAccessCtrl } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { TokenStore, CTX_KEY } from '../common/TokenStore';

/** 取景框几何值 —— 设计稿一次性值 1:1 取 vp */
const FINDER_SIZE: number = 150;
const CORNER_LEN: number = 26;
const CORNER_WIDTH: number = 3;
const LINE_INSET: number = 8;
const CODE_BLOCK: number = 62;
/** 成功态白卡与按钮同宽（照设计稿占屏宽约 2/3） */
const SUCCESS_CARD_W: string = '66%';

/** 页面两个形态 */
class Mode {
  /** 扫码取景 */
  static readonly SCAN: number = 0;
  /** 签到成功 */
  static readonly SUCCESS: number = 1;
}

/**
 * ScanSignInPage —— 扫码签到（含签到成功态）
 *
 * 版式照 `UI\鸿志愿_扫码签到_签到成功_发布活动表单_界面稿.png`：
 *   【扫码态】深底(#1A1A1A) + 白字顶栏（‹ / 标题 / 相机）+ 中央 150 取景框
 *   （四角 3px 橙 L 形 + 橙色扫描线 + 中央二维码占位块）+ 两行提示 +
 *   底部「手输签到码 / 相册选择」双按钮。
 *   【成功态】浅底：76 绿圆白勾 → 「签到成功」→ 活动名 → 白卡
 *   （本次获得 +X.X 小时 / 累计志愿时长 / 签到时间 / 信用分·履约正常）→
 *   橙色「查看时长明细」→ 灰字「返回首页」。
 *
 * 【U 阶段怎么"扫码"】scanKit / 相册识别都要 D/F 阶段接真机能力（计划 R7：
 *   模拟器无相机，演示本来就靠手输/相册降级），本页把「手输签到码」「相册选择」
 *   「顶栏相机」三个入口都指向**模拟签到成功**——状态机与成功态 UI 先行，
 *   D 阶段只把 `simulateSuccess()` 换成真实核销回调，页面结构不动。
 *
 * 【成功态数据】取「我的报名」里第一个待签到（signed_up）的活动作为本次签到对象；
 *   签到时间用 DateFmt.nowMdHm()，累计时长 = 用户累计 + 本次入账。
 */
@Entry
@Component
struct ScanSignInPage {
  @State loading: boolean = true;
  /** 当前形态：0 扫码 / 1 成功（⚠️ 命名避开基类属性，勿用 tabIndex 之类） */
  @State mode: number = Mode.SCAN;

  /** 本次签到的活动（取待签到报名的第一个） */
  private target: Signup | null = null;
  private gainHours: number = 2;
  private userTotal: number = 0;
  private creditScore: number = 0;
  private signInTime: string = '';

  /** 手输签到码输入区是否展开（点「手输签到码」才出现，不改原版式） */
  @State showInput: boolean = false;
  @State codeInput: string = '';
  /** 核销中：防重复提交 */
  @State submitting: boolean = false;
  /** F2 软围栏：与签到点的距离提示（拒绝定位授权则恒空，不影响签到） */
  @State distanceText: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const signs: Signup[] = await MineService.signups();
      for (let i = 0; i < signs.length; i++) {
        if (signs[i].canSignIn() && signs[i].activity !== null) {
          this.target = signs[i];
          break;
        }
      }
      const u: User = await MineService.profile();
      this.userTotal = u.totalHours;
      this.creditScore = u.creditScore;
      if (this.target !== null && this.target.activity !== null) {
        this.gainHours = this.target.activity.serviceHours;
      }
    } catch (err) {
      // 拉取失败保持默认值，成功态仍可展示
    }
    this.loading = false;
  }

  /** F2：页面完全挂窗后再请求定位权限 —— aboutToAppear 时机过早，弹窗会静默失败 */
  onPageShow(): void {
    this.locateDistance();
  }

  // ==================== F2：软围栏（距离提示，非强制拦截） ====================

  /**
   * 定位 → 计算与目标签到点的直线距离 → 生成提示文案。
   * 三层兜底：未报活动不显示 / 权限被拒不显示 / 定位失败不显示 —— 只提示不拦截。
   * 距离 >2km 不报具体数（演示环境坐标可能相距甚远，避免"12000 公里"的尴尬）。
   */
  private async locateDistance(): Promise<void> {
    if (this.target === null || this.target.activity === null) {
      return;
    }
    const act = this.target.activity;
    if (act.lat === 0 && act.lng === 0) {
      return;
    }
    try {
      const ctx: common.Context | undefined = AppStorage.get<common.Context>(CTX_KEY);
      if (ctx === undefined) {
        return;
      }
      const atManager = abilityAccessCtrl.createAtManager();
      const perm = await atManager.requestPermissionsFromUser(ctx,
        ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION']);
      let granted: boolean = false;
      for (let i = 0; i < perm.authResults.length; i++) {
        if (perm.authResults[i] === 0) {
          granted = true;
        }
      }
      if (!granted) {
        return;
      }
      const loc = await geoLocationManager.getCurrentLocation();
      const dist: number = this.distanceMeters(loc.latitude, loc.longitude, act.lat, act.lng);
      if (dist < 500) {
        this.distanceText = '✓ 已在签到点附近（约 ' + Math.round(dist) + ' 米）';
      } else if (dist < 2000) {
        this.distanceText = '距签到点约 ' + (dist / 1000).toFixed(1) + ' 公里，到场后扫码签到';
      } else {
        this.distanceText = '请到场后扫码签到（' + act.address + '）';
      }
    } catch (err) {
      // 定位失败静默：不显示距离行
    }
  }

  /** 球面近似距离（米）：equirectangular 简化式，百米级演示场景足够 */
  private distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const rad: number = Math.PI / 180;
    const x: number = (lng2 - lng1) * rad * Math.cos((lat1 + lat2) / 2 * rad);
    const y: number = (lat2 - lat1) * rad;
    return Math.sqrt(x * x + y * y) * 6371000;
  }

  // ==================== 核销（D3 后半：手输签到码走真实接口） ====================

  /**
   * 没有真机 / 没有相机取景时，三个入口（手输、相册、顶栏相机）
   * 都指向**手输签到码**这条真实核销路径 —— 它与扫码走的是同一个接口，
   * 只是 signType 不同（F1 接入 Scan Kit 后，扫到码自动填进 codeInput 即可）。
   */
  private openManualInput(): void {
    this.showInput = true;
  }

  // ==================== F1：Scan Kit 相机扫码 ====================

  /**
   * 拉起**系统扫码页**（scanBarcode.startScanForResult）：
   *   · 相机权限由系统扫码页代持，本应用**无需声明任何权限**
   *   · 扫码 UI（取景/闪光灯/图库识别）全是系统自带，零自绘
   * 扫到内容后提取 6 位签到码自动填入并直接核销 —— 与手输走同一接口（F1 与手输仅入口不同）。
   * 二维码内容约定为签到码本身；组织者若用带其他文字的码，正则兜底提取连续 6 位数字。
   */
  private async startCameraScan(): Promise<void> {
    const ctx: common.Context | undefined = AppStorage.get<common.Context>(CTX_KEY);
    if (ctx === undefined) {
      this.toast('无法启动扫码，请重试');
      return;
    }
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE]
      };
      const result: scanBarcode.ScanResult = await scanBarcode.startScanForResult(ctx, options);
      const raw: string = result.originalValue;
      const match: RegExpMatchArray | null = raw.match(/\d{6}/);
      if (match === null) {
        this.toast('二维码里没有签到码，可改用手输');
        return;
      }
      this.codeInput = match[0];
      this.showInput = true;
      this.doSignin();
    } catch (err) {
      // 用户取消扫码也会走 reject：静默即可，不打断
    }
  }

  private async doSignin(): Promise<void> {
    if (this.target === null || this.target.activity === null) {
      this.toast($r('app.string.scan_no_pending'));
      return;
    }
    if (this.codeInput.length !== 6) {
      this.toast($r('app.string.scan_signin_code_hint'));
      return;
    }
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    const activityId: number = this.target.activity.id;
    try {
      const res: Result<SigninResult> = await VolunteerService.signin(activityId, this.codeInput, 'manual');
      this.submitting = false;
      if (!res.isOk() || res.data === null) {
        // 后端文案：「签到码不正确，请核对后重试」「请先报名该活动」…
        this.toast(res.message !== '' ? res.message : $r('app.string.signin_fail'));
        return;
      }
      this.gainHours = res.data.hours;
      this.userTotal = res.data.totalHours;
      this.signInTime = res.data.signinTime !== '' ? DateFmt.mdhm(res.data.signinTime) : DateFmt.nowMdHm();
      this.mode = Mode.SUCCESS;
    } catch (err) {
      this.submitting = false;
      this.toast($r('app.string.signin_fail'));
    }
  }

  // ==================== F2：定位签到（免码，围栏校验在服务端） ====================

  /**
   * 定位签到：授权定位 → 取当前位置 → signType='geo' 提交（lat/lng 必传）。
   * 服务端围栏校验：落在活动 signin_radius（默认 200 米）内才放行，
   * 超范围返回后端文案「不在签到范围内（距签到点约 X 米）」。
   * 定位失败/未授权 → 引导改用扫码或手输，绝不静默失败。
   */
  private async locationSignin(): Promise<void> {
    if (this.target === null || this.target.activity === null) {
      this.toast($r('app.string.scan_no_pending'));
      return;
    }
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    try {
      const ctx: common.Context | undefined = AppStorage.get<common.Context>(CTX_KEY);
      if (ctx === undefined) {
        this.submitting = false;
        this.toast('无法定位，请改用扫码或手输签到');
        return;
      }
      const atManager = abilityAccessCtrl.createAtManager();
      const perm = await atManager.requestPermissionsFromUser(ctx,
        ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION']);
      let granted: boolean = false;
      for (let i = 0; i < perm.authResults.length; i++) {
        if (perm.authResults[i] === 0) {
          granted = true;
        }
      }
      if (!granted) {
        this.submitting = false;
        this.toast('需要定位权限才能定位签到');
        return;
      }
      const loc = await geoLocationManager.getCurrentLocation();
      const activityId: number = this.target.activity.id;
      const res: Result<SigninResult> = await VolunteerService.signin(
        activityId, '', 'geo', loc.latitude, loc.longitude);
      this.submitting = false;
      if (!res.isOk() || res.data === null) {
        this.toast(res.message !== '' ? res.message : $r('app.string.signin_fail'));
        return;
      }
      this.gainHours = res.data.hours;
      this.userTotal = res.data.totalHours;
      this.signInTime = res.data.signinTime !== '' ? DateFmt.mdhm(res.data.signinTime) : DateFmt.nowMdHm();
      this.mode = Mode.SUCCESS;
    } catch (err) {
      this.submitting = false;
      this.toast('定位失败，请改用扫码或手输签到');
    }
  }

  private toast(msg: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (err) {
      // 提示失败不影响主流程
    }
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

  // ==================== 局部 UI：扫码态 ====================

  /** 取景框四角之一（per-corner border + radius 画出 3px 橙 L 形） */
  @Builder
  finderCorner(top: boolean, left: boolean) {
    Row()
      .width(CORNER_LEN)
      .height(CORNER_LEN)
      .border({
        width: {
          top: top ? CORNER_WIDTH : 0,
          left: left ? CORNER_WIDTH : 0,
          right: !left ? CORNER_WIDTH : 0,
          bottom: !top ? CORNER_WIDTH : 0
        },
        color: AppTheme.primary
      })
      .borderRadius({
        topLeft: top && left ? 6 : 0,
        topRight: top && !left ? 6 : 0,
        bottomLeft: !top && left ? 6 : 0,
        bottomRight: !top && !left ? 6 : 0
      })
      .position({
        x: left ? 0 : FINDER_SIZE - CORNER_LEN,
        y: top ? 0 : FINDER_SIZE - CORNER_LEN
      })
  }

  @Builder
  finder() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.finderCorner(true, true)
      this.finderCorner(true, false)
      this.finderCorner(false, true)
      this.finderCorner(false, false)

      // 扫描线
      Row()
        .height(2)
        .backgroundColor(AppTheme.primary)
        .width(FINDER_SIZE - LINE_INSET * 2)
        .position({ x: LINE_INSET, y: 74 })

      // 中央二维码占位块（无真实取景时撑住构图，U13 走查再定去留）
      Row()
        .width(CODE_BLOCK)
        .height(CODE_BLOCK)
        .borderRadius(8)
        .backgroundColor(AppTheme.scanDarkCard)
        .position({ x: (FINDER_SIZE - CODE_BLOCK) / 2, y: 44 })
    }
    .width(FINDER_SIZE)
    .height(FINDER_SIZE)
  }

  /** 扫码态顶栏（深底专用白字白图标，不用 PageHeader —— 那是浅底配色） */
  @Builder
  darkHeader() {
    Row() {
      Row() {
        lineIcon(LinePath.CHEVRON_LEFT, 20, AppTheme.textOnDark)
      }
      .width(48)
      .height(44)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.back();
      })

      Text($r('app.string.scan_title'))
        .fontSize(AppTheme.fontBody)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textOnDark)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Row() {
        lineIcon(LinePath.CAMERA, 20, AppTheme.textOnDark)
      }
      .width(48)
      .height(44)
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        // F1：Scan Kit 系统扫码页（相机权限系统代持，无需声明）
        this.startCameraScan();
      })
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  scanBody() {
    Column() {
      this.darkHeader()

      Column() {
        this.finder()

        Text($r('app.string.scan_tip'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textHint)
          .margin({ top: 20 })

        Text($r('app.string.scan_tip_sub'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 6 })

        // F2 软围栏：定位成功才显示的距离提示（不拦截签到）
        if (this.distanceText !== '') {
          Text(this.distanceText)
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.accent)
            .margin({ top: 10 })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH })

      // 手输签到码输入区：点底部任一入口才展开（无相机时的真实核销路径）
      if (this.showInput) {
        Row() {
          TextInput({ placeholder: $r('app.string.scan_signin_code_hint'), text: this.codeInput })
            .type(InputType.Number)
            .maxLength(6)
            .fontSize(AppTheme.fontSecondary)
            .fontColor(AppTheme.textPrimary)
            .placeholderColor(AppTheme.textHint)
            .backgroundColor(AppTheme.surface)
            .borderRadius(20)
            .height(AppTheme.searchBarHeight)
            .padding({ left: 14 })
            .layoutWeight(1)
            .onChange((value: string) => {
              this.codeInput = value;
            })

          Row() {
            Text(this.submitting ? $r('app.string.scan_confirming') : $r('app.string.scan_confirm'))
              .fontSize(AppTheme.fontSecondary)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textOnPrimary)
          }
          .height(AppTheme.searchBarHeight)
          .padding({ left: 16, right: 16 })
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.primary)
          .borderRadius(20)
          .margin({ left: 9 })
          .opacity(this.submitting ? 0.6 : 1)
          .onClick(() => {
            this.doSignin();
          })
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 10 })
        .alignItems(VerticalAlign.Center)
      }

      Row() {
        Row() {
          Text($r('app.string.scan_manual'))
            .fontSize(AppTheme.fontSecondary)
            .fontColor(AppTheme.primaryGradientStart)
        }
        .layoutWeight(1)
        .height(AppTheme.searchBarHeight)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.scanDarkCard)
        // ⚠️ Resource 不能做算术（searchBarHeight / 2 报错）→ 40 的一半直接写 20
        .borderRadius(20)
        .onClick(() => {
          this.openManualInput();
        })

        Row() {
          Text(this.submitting ? '定位中…' : '定位签到')
            .fontSize(AppTheme.fontSecondary)
            .fontColor(AppTheme.primaryGradientStart)
        }
        .layoutWeight(1)
        .height(AppTheme.searchBarHeight)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.scanDarkCard)
        .borderRadius(20)
        .margin({ left: 9 })
        .opacity(this.submitting ? 0.6 : 1)
        .onClick(() => {
          this.locationSignin();
        })

        Row() {
          Text($r('app.string.scan_album'))
            .fontSize(AppTheme.fontSecondary)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textOnPrimary)
        }
        .layoutWeight(1)
        .height(AppTheme.searchBarHeight)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.primary)
        .borderRadius(20)
        .margin({ left: 9 })
        .onClick(() => {
          this.startCameraScan();
        })
      }
      .width('100%')
      .padding({ left: 14, right: 14, bottom: 16 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.scanBg)
  }

  // ==================== 局部 UI：成功态 ====================

  /** 成功态白卡「标签 … 值」行（tone：0=绿 Medium 1=黑 Medium 2=常规黑；topGap 行距，防链属性） */
  @Builder
  resultLine(label: Resource, value: string, tone: number, topGap: number) {
    Row() {
      Text(label)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)
      Blank()
      Text(value)
        .fontSize(AppTheme.fontCaption)
        .fontWeight(tone === 2 ? FontWeight.Normal : FontWeight.Medium)
        .fontColor(tone === 0 ? AppTheme.accent : AppTheme.textPrimary)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: topGap })
  }

  /** 信用分行：'92 · 履约正常'（$r 不拼接，拆 Span） */
  @Builder
  creditLine() {
    Row() {
      Text($r('app.string.scan_credit'))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)
      Blank()
      Text() {
        Span(this.creditScore.toString())
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.accent)
        Span(' · ')
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.accent)
        Span($r('app.string.scan_credit_ok'))
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.accent)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 8 })
  }

  @Builder
  successBody() {
    Column() {
      Column() {
        // 绿圆白勾
        Row() {
          lineIcon(LinePath.CHECK, 36, AppTheme.textOnPrimary)
        }
        .width(76)
        .height(76)
        .borderRadius(38)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.accent)
        .margin({ top: 64 })

        Text($r('app.string.scan_success'))
          .fontSize(AppTheme.fontTitleSection)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .margin({ top: 18 })

        Text(this.target === null || this.target.activity === null ? '' : this.target.activity.title)
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 7 })

        Column() {
          Row() {
            Column() {
              Text($r('app.string.scan_gain_label'))
                .fontSize(AppTheme.fontCaption)
                .fontColor(AppTheme.textSecondary)

              Text() {
                Span('+' + this.gainHours.toFixed(1))
                  .fontSize(AppTheme.fontNumberMd)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.primary)
                Span(' ')
                  .fontSize(AppTheme.fontCaption)
                  .fontColor(AppTheme.textSecondary)
                Span($r('app.string.common_unit_hour'))
                  .fontSize(AppTheme.fontCaption)
                  .fontColor(AppTheme.textSecondary)
              }
              .margin({ top: 3 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Row() {
              lineIcon(LinePath.CLOCK, 16, AppTheme.primary)
            }
            .width(34)
            .height(34)
            .borderRadius(12)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(AppTheme.primaryLight)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row() {
            thinDivider()
          }
          .width('100%')
          .margin({ top: 12, bottom: 12 })

          this.resultLine($r('app.string.mine_total_hours'),
            (this.userTotal + this.gainHours).toFixed(1) + ' 小时', 1, 0)

          this.resultLine($r('app.string.scan_signin_time'), this.signInTime, 2, 8)

          this.creditLine()
        }
        .width(SUCCESS_CARD_W)
        .alignItems(HorizontalAlign.Start)
        .padding(14)
        .backgroundColor(AppTheme.surface)
        .borderRadius(AppTheme.cardRadius)
        .margin({ top: 22 })

        Row() {
          Text($r('app.string.scan_view_hours'))
            .fontSize(AppTheme.fontSecondary)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textOnPrimary)
        }
        .width(SUCCESS_CARD_W)
        .height(42)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.primary)
        .borderRadius(21)
        .margin({ top: 14 })
        .onClick(() => {
          this.goto('pages/MyHoursPage');
        })

        Text($r('app.string.scan_back_home'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 12 })
          .onClick(() => {
            this.back();
          })

        Row()
          .width('100%')
          .height(16)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingOverlay({ text: $r('app.string.common_loading') })
      } else if (this.mode === Mode.SCAN) {
        this.scanBody()
      } else {
        this.successBody()
      }
    }
    .width('100%')
    .height('100%')
  }
}
