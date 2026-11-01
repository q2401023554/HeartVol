import { AppTheme } from '../common/AppTheme';
import { IconPath, appIcon } from '../common/AppIcon';
import { AuthService } from '../service/AuthService';
import { PageHeader } from '../components/PageHeader';
import { User } from '../model/User';

/**
 * SettingsPage —— 设置页
 *
 * 自上而下：
 *   ① 个人资料卡：头像圈（姓名首字）+ 姓名 + 学号；下方学院 / 电话两行
 *      点「编辑资料」→ 卡片切内嵌编辑态（三个输入框 + 保存/取消），保存走
 *      PUT /api/user/profile（D 后端新接口），成功后用返回的最新 me 刷新
 *   ② 退出登录（红字警示；原「我的」页底部的重复入口已统一挪到这里）
 *   ③ 关于鸿志愿（版本信息 toast）
 *
 * 【为什么内嵌编辑而不用弹窗】@CustomDialog 的初始值传递与状态回写要绕
 *   controller 生命周期，页面内嵌 @State 切换最直白、零弹窗风险。
 */
@Entry
@Component
struct SettingsPage {
  @State loading: boolean = true;
  @State user: User = new User();
  /** 是否处于编辑态 */
  @State editing: boolean = false;
  /** 编辑态表单 */
  @State name: string = '';
  @State phone: string = '';
  @State college: string = '';
  @State saving: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const res = await AuthService.me();
      if (res.isOk() && res.data !== null) {
        this.user = User.fromJson(res.data as User);
      }
    } catch (err) {
      // 拉取失败显示空资料
    }
    this.loading = false;
  }

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  /** 进入编辑态：把当前资料填进表单 */
  private startEdit(): void {
    this.name = this.user.name;
    this.phone = this.user.phone;
    this.college = this.user.college;
    this.editing = true;
  }

  private cancelEdit(): void {
    this.editing = false;
  }

  private toast(msg: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (err) {
      // 提示失败不影响主流程
    }
  }

  /** 保存资料（成功后用后端返回的最新 me 刷新展示） */
  private async saveProfile(): Promise<void> {
    if (this.name.trim() === '') {
      this.toast('姓名不能为空');
      return;
    }
    if (this.phone.trim() !== '' && !/^1\d{10}$/.test(this.phone.trim())) {
      this.toast('手机号格式不正确');
      return;
    }
    this.saving = true;
    try {
      const res = await AuthService.updateProfile(this.name, this.phone, this.college);
      if (res.isOk() && res.data !== null) {
        this.user = User.fromJson(res.data as User);
        this.editing = false;
        // 通知「我的」Tab 重拉用户（Tab 组件无 onPageShow，只能信号刷新）
        AppStorage.setOrCreate('userProfileTick', Date.now());
        this.toast($r('app.string.settings_profile_saved'));
      } else {
        this.toast(res.message);
      }
    } catch (err) {
      this.toast('保存失败，请重试');
    }
    this.saving = false;
  }

  /** 退出登录：清 token + 回登录页（清栈，避免主页在返回栈里） */
  private async doLogout(): Promise<void> {
    try {
      await AuthService.logout();
    } catch (err) {
      // 即使清 token 失败也继续跳转，不让用户卡在已登录态
    }
    try {
      const router = this.getUIContext().getRouter();
      router.replaceUrl({ url: 'pages/LoginPage' });
      router.clear();
    } catch (err) {
      // 跳转失败保持当前页
    }
  }

  /** 头像圈：姓名首字（与互助卡头像同一套语言） */
  @Builder
  avatarCircle() {
    Row() {
      Text(this.user.name === '' ? '志' : this.user.nameInitial())
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.primary)
    }
    .width(52)
    .height(52)
    .borderRadius(26)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.primaryLight)
  }

  /** 资料只读行：label + value（value 可为 Resource 占位或 string 实值） */
  @Builder
  infoRow(label: Resource, value: ResourceStr, valueColor: ResourceColor) {
    Row() {
      Text(label)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textHint)
        .width(52)
      Text(value === '' ? $r('app.string.settings_not_filled') : value)
        .fontSize(AppTheme.fontSecondary)
        .fontColor(value === '' ? AppTheme.textHint : valueColor)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 10 })
  }

  /** 编辑态输入行 */
  @Builder
  inputRow(label: Resource, text: string, placeholder: Resource, onChange: (v: string) => void) {
    Row() {
      Text(label)
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textHint)
        .width(52)
      TextInput({ text: text, placeholder: placeholder })
        .fontSize(AppTheme.fontSecondary)
        .fontColor(AppTheme.textPrimary)
        .placeholderColor(AppTheme.textHint)
        .backgroundColor(Color.Transparent)
        .padding(0)
        .layoutWeight(1)
        .onChange(onChange)
    }
    .width('100%')
    .height(40)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.fillGray)
    .borderRadius(10)
    .padding({ left: 10, right: 10 })
    .margin({ top: 8 })
  }

  /** ① 个人资料卡 */
  @Builder
  profileCard() {
    Column() {
      Row() {
        this.avatarCircle()

        Column() {
          Text(this.user.name === '' ? '-' : this.user.name)
            .fontSize(AppTheme.fontTitleCard)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Text(this.user.studentNo)
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textSecondary)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (!this.editing) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(AppTheme.divider)
          .margin({ top: 14, bottom: 2 })

        this.infoRow($r('app.string.settings_label_studentno'), this.user.studentNo, AppTheme.textPrimary)
        this.infoRow($r('app.string.settings_label_college'), this.user.college, AppTheme.textPrimary)
        this.infoRow($r('app.string.settings_label_phone'), this.user.phone, AppTheme.textPrimary)

        // 编辑入口
        Row() {
          Text($r('app.string.settings_edit_profile'))
            .fontSize(AppTheme.fontSecondary)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
          Blank()
          appIcon(IconPath.CHEVRON_RIGHT, 12, AppTheme.textHint)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 12 })
        .onClick(() => {
          this.startEdit();
        })
      } else {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(AppTheme.divider)
          .margin({ top: 14 })

        this.inputRow($r('app.string.settings_label_name'), this.name, $r('app.string.settings_name_ph'),
          (v: string) => {
            this.name = v;
          })
        this.inputRow($r('app.string.settings_label_phone'), this.phone, $r('app.string.settings_phone_ph'),
          (v: string) => {
            this.phone = v;
          })
        this.inputRow($r('app.string.settings_label_college'), this.college, $r('app.string.settings_college_ph'),
          (v: string) => {
            this.college = v;
          })

        Row() {
          Row() {
            Text($r('app.string.common_cancel'))
              .fontSize(AppTheme.fontSecondary)
              .fontColor(AppTheme.textSecondary)
          }
          .layoutWeight(1)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.fillGray)
          .borderRadius(18)
          .onClick(() => {
            this.cancelEdit();
          })

          Row() {
            Text(this.saving ? $r('app.string.common_loading') : $r('app.string.settings_save_profile'))
              .fontSize(AppTheme.fontSecondary)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textOnPrimary)
          }
          .layoutWeight(1)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.primary)
          .borderRadius(18)
          .margin({ left: 10 })
          .onClick(() => {
            if (!this.saving) {
              this.saveProfile();
            }
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 14 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 12 })
  }

  /** 通用列表行：左标题 + 右 chevron */
  @Builder
  row(title: Resource, color: ResourceColor, onClick: () => void, topGap: number = 0) {
    Row() {
      Text(title)
        .fontSize(AppTheme.fontSecondary)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
        .layoutWeight(1)
      appIcon(IconPath.CHEVRON_RIGHT, 12, AppTheme.textHint)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(14)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: topGap })
    .onClick(onClick)
  }

  build() {
    Column() {
      PageHeader({
        title: $r('app.string.settings_title'),
        onBack: () => {
          this.back();
        }
      })

      Scroll() {
        Column() {
          if (!this.loading) {
            this.profileCard()
          }

          this.row($r('app.string.mine_logout'), AppTheme.badgeRed, () => {
            this.doLogout();
          }, 12)

          this.row($r('app.string.settings_about'), AppTheme.textPrimary, () => {
            try {
              this.getUIContext().getPromptAction().showToast({ message: $r('app.string.settings_version') });
            } catch (err) {
              // 提示失败不影响主流程
            }
          })

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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
