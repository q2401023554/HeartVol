import { AppTheme } from '../common/AppTheme';
import { appMark } from '../common/AppIcon';
import { ToastUtil } from '../common/ToastUtil';
import { Certificate } from '../model/Certificate';
import { MineService } from '../service/MineService';
import { PageHeader } from '../components/PageHeader';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { thinDivider } from '../components/Divider';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';

/** 证书卡几何值 —— 设计稿一次性值 1:1 取 vp */
const CERT_TOP_BAR: number = 4;
const STAMP_SIZE: number = 48;

/**
 * CertificatePage —— 电子证书
 *
 * 版式照 `UI\鸿志愿_我的报名_时长明细_电子证书_界面稿.png`：
 *   ① 证书卡：白底 + orange_tint 细描边 + 顶部 4px 橙条；
 *      卡内「鸿志愿」品牌行（appMark 小标识）→ 居中「志愿服务时长证明」+ 英文副题 →
 *      分割线 → 姓名/学号/学院/累计时长(橙)/参与场次 五行 → 左下编号与日期 + 右下红色圆形认定章
 *   ② 底部双按钮：灰底「保存图片」（橙字）+ 橙底「分享证书」（白字）
 *
 * 【印章为什么不用图片】工程零图片资源，印章就是「红描边圆 + 两行红字」，
 *   一样能读出「公章」的视觉语义；等 B 阶段有素材了只改本文件的 stamp()。
 *   描边色用 badgeRed —— 设计稿的 #E24B4A 与现有色板最近的红，不再加孤立色。
 *
 * 【保存/分享】U 阶段演示提示；D/F 阶段接 screenshot / share kit。
 */
@Entry
@Component
struct CertificatePage {
  @State loading: boolean = true;
  private cert: Certificate = new Certificate();

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      this.cert = await MineService.certificate();
    } catch (err) {
      // 拉取失败保持空数据骨架
    }
    this.loading = false;
  }

  // ==================== 导航 ====================

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  private toast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      // toast 失败不影响主流程
    }
  }

  // ==================== 局部 UI ====================

  /** 证书信息行：左标签右值两端对齐（设计 space-between；缺 Blank 会挤成「姓名张明远」） */
  @Builder
  infoLine(label: Resource, value: string, highlight: boolean) {
    Row() {
      Text(label)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textSecondary)

      Blank()

      Text() {
        Span(value)
          .fontSize(highlight ? AppTheme.fontBody : AppTheme.fontCaption)
          .fontWeight(highlight ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(highlight ? AppTheme.primary : AppTheme.textPrimary)
        if (highlight) {
          Span(' ')
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.primary)
          Span($r('app.string.common_unit_hour'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.primary)
        }
      }
      .maxLines(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 9 })
  }

  /** 右下红色圆形认定章（两行文字都要 maxLines(1)，圆内宽度小极易折行成三行） */
  @Builder
  stamp() {
    Column() {
      Text($r('app.string.app_name'))
        .fontSize(AppTheme.fontBadge)
        .fontColor(AppTheme.badgeRed)
        .maxLines(1)
        .textAlign(TextAlign.Center)
      Text($r('app.string.cert_stamp_text'))
        .fontSize(AppTheme.fontBadge)
        .fontColor(AppTheme.badgeRed)
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .margin({ top: 2 })
    }
    .justifyContent(FlexAlign.Center)
    .width(STAMP_SIZE)
    .height(STAMP_SIZE)
    .borderRadius(STAMP_SIZE / 2)
    .border({ width: 2, color: AppTheme.badgeRed })
  }

  /** ① 证书卡 */
  @Builder
  certCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 顶部 4px 橙条
      Row()
        .width('100%')
        .height(CERT_TOP_BAR)
        .backgroundColor(AppTheme.primaryGradientStart)

      Column() {
        // 品牌行
        Row() {
          appMark(22, 8, 12)
          Text($r('app.string.agent_name'))
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
            .margin({ left: 7 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 8 })

        Text($r('app.string.cert_heading'))
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .margin({ top: 16 })

        Text($r('app.string.cert_heading_en'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textHint)
          .margin({ top: 5 })

        Row() {
          thinDivider()
        }
        .width('100%')
        .margin({ top: 14, bottom: 5 })

        this.infoLine($r('app.string.register_name'), this.cert.userName, false)
        this.infoLine($r('app.string.login_student_no'), this.cert.studentNo, false)
        this.infoLine($r('app.string.register_college'), this.cert.college, false)
        this.infoLine($r('app.string.hall_total_hours'), this.cert.totalHours.toString(), true)
        this.infoLine($r('app.string.cert_scene_count'), this.cert.activityCount.toString(), false)

        Row() {
          Column() {
            // 🔴 $r() 不能参与字符串拼接 → 编号前缀与编号拆成两个 Span
            Text() {
              Span($r('app.string.cert_serial_prefix'))
                .fontSize(AppTheme.fontCaption)
                .fontColor(AppTheme.textHint)
              Span(' ' + this.cert.serialNo)
                .fontSize(AppTheme.fontCaption)
                .fontColor(AppTheme.textHint)
            }
            Text(this.cert.issueDate)
              .fontSize(AppTheme.fontCaption)
              .fontColor(AppTheme.textHint)
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          this.stamp()
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 14 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .width('100%')
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .border({ width: 1, color: AppTheme.orangeTint })
    .clip(true)
    .id('cert_card')
    .margin({ top: 14 })
  }

  /** ② 底部双按钮 */
  @Builder
  bottomBar() {
    Row() {
      // 保存图片 = 官方安全控件 SaveButton：点击即获得 10s 临时授权写相册，
      // 免 ohos.permission.WRITE_IMAGEVIDEO（该权限属受限开放，声明即安装失败 9568289）
      // 注意：onClick 必须挂在 SaveButton 自己身上（授权绑定控件点击事件），
      // 外层 Row 只负责 layoutWeight 布局（安全控件样式白名单没有 layoutWeight）
      Row() {
        SaveButton({ text: SaveDescription.SAVE_IMAGE, buttonType: ButtonType.Capsule })
          .width('100%')
          .height(AppTheme.buttonHeight)
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.primary)
          .backgroundColor(AppTheme.fillGray)
          .borderRadius(AppTheme.pillRadius)
          .onClick((event: ClickEvent, result: SaveButtonOnClickResult) => {
            if (result !== SaveButtonOnClickResult.SUCCESS) {
              ToastUtil.show('未能获得保存授权，请重试');
              return;
            }
            this.saveImage();
          })
      }
      .layoutWeight(1)

      Row() {
        Text($r('app.string.cert_share'))
          .fontSize(AppTheme.fontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textOnPrimary)
      }
      .layoutWeight(1)
      .height(AppTheme.buttonHeight)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.primary)
      .borderRadius(AppTheme.pillRadius)
      .margin({ left: 9 })
      .onClick(() => {
        this.shareCert();
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 14 })
    .backgroundColor(AppTheme.surface)
  }

  // ==================== 证书存图 / 分享 ====================

  /** 截取证书卡为 PixelMap（组件快照，零图片资源也能拿到位图） */
  private async snapCert(): Promise<image.PixelMap | undefined> {
    try {
      const pm: image.PixelMap = await this.getUIContext()
        .getComponentSnapshot()
        .get('cert_card', { waitUntilRenderFinished: true });
      return pm;
    } catch (err) {
      return undefined;
    }
  }

  /** 把 PixelMap 打包成 JPEG 字节 */
  private async packJpeg(pm: image.PixelMap): Promise<Uint8Array> {
    const packing: image.ImagePacker = image.createImagePacker();
    try {
      const buf: ArrayBuffer = await packing.packToData(pm, {
        format: 'image/jpeg',
        quality: 100
      });
      return new Uint8Array(buf);
    } finally {
      packing.release();
    }
  }

  /** 保存图片：截证书卡 → 写进系统相册（安全控件临时授权期内完成，三段独立报错便于定位） */
  private async saveImage(): Promise<void> {
    // ① 组件快照（快，先做）
    const pm: image.PixelMap | undefined = await this.snapCert();
    if (!pm) {
      ToastUtil.show('保存失败：证书截图未生成');
      return;
    }
    // ② 相册建资产 —— 授权窗口内第一步做掉（默认命名，兼容性最好）
    let uri: string = '';
    try {
      const ctx: common.UIAbilityContext =
        AppStorage.get('abilityContext') as common.UIAbilityContext;
      const helper: photoAccessHelper.PhotoAccessHelper =
        photoAccessHelper.getPhotoAccessHelper(ctx);
      uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
    } catch (err) {
      ToastUtil.show('保存失败：相册写入未获授权，请重试');
      return;
    }
    // ③ 编码 + 写字节
    try {
      const bytes: Uint8Array = await this.packJpeg(pm);
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE);
      try {
        fileIo.writeSync(file.fd, bytes.buffer);
      } finally {
        fileIo.closeSync(file.fd);
      }
      ToastUtil.show('证书已保存到相册');
    } catch (err) {
      ToastUtil.show('保存失败：图片编码出错，请重试');
    }
  }

  /** 分享证书：截证书卡 → 落临时文件 → 走系统分享面板 */
  private async shareCert(): Promise<void> {
    const pm: image.PixelMap | undefined = await this.snapCert();
    if (!pm) {
      ToastUtil.show('证书生成失败，请重试');
      return;
    }
    try {
      const ctx: common.UIAbilityContext =
        AppStorage.get('abilityContext') as common.UIAbilityContext;
      const path: string = ctx.cacheDir + '/hz_cert_' + Date.now().toString() + '.jpg';
      const file = fileIo.openSync(
        path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      try {
        const packing: image.ImagePacker = image.createImagePacker();
        try {
          await packing.packToFile(pm, file.fd, { format: 'image/jpeg', quality: 100 });
        } finally {
          packing.release();
        }
      } finally {
        fileIo.closeSync(file.fd);
      }
      const uri: string = fileUri.getUriFromPath(path);
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.IMAGE,
        uri: uri,
        title: '鸿志愿电子证书'
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

  build() {
    Column() {
      if (this.loading) {
        LoadingOverlay({ text: $r('app.string.common_loading') })
      } else {
        Column() {
          PageHeader({
            title: $r('app.string.cert_title'),
            onBack: () => {
              this.back();
            }
          })

          Scroll() {
            Column() {
              this.certCard()
              Row()
                .width('100%')
                .height(16)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)

          this.bottomBar()
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
