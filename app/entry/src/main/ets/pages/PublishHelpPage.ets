import { AppTheme } from '../common/AppTheme';
import { appIcon, IconPath, lineIcon, LinePath } from '../common/AppIcon';
import { PageHeader } from '../components/PageHeader';
import { HelpService } from '../service/HelpService';
import { PublishHelpBody, PublishHelpResult } from '../model/HelpOps';
import { Result } from '../model/Result';

/**
 * PublishHelpPage —— 发布求助
 *
 * 版式照 `UI\鸿志愿_求助详情_发布求助_注册页_界面稿.png`：
 *   ① 顶栏：返回 ‹ + 「发布求助」标题 + 右上「存草稿」
 *   ② 小鸿提示卡（橙浅底）：「鸿」圆标 + 一句话提示 + 输入框
 *   ③ 表单卡：求助标题 / 求助分类（5 胶囊）/ 详细描述 / 期望完成时间 / 悬赏积分
 *   ④ 底部绿色「发布求助」主按钮
 *
 * 【分类胶囊】走 SegmentedTabs 同款的横向胶囊思路，但这里是**静态填在表单里**，
 *   用一组选一（单 category），复用 HelpCategory 码值 + BizDict.helpLabel 查文案。
 *
 * 【发布】U 阶段 Mock 下点击直接 toast 提示并返回大厅；D 阶段换成
 *   await HelpService.publish(...) 再置位。
 */
@Entry
@Component
struct PublishHelpPage {
  /** 选中的分类下标，与 CATEGORIES 顺序一致 */
  @State categoryIndex: number = 0;
  /** 表单标题 / 描述 / 期望时间 / 地点 */
  private title: string = '';
  private description: string = '';
  private expectTime: string = '';
  private place: string = '';
  /** 悬赏积分（默认 30） */
  private rewardPoint: number = 30;

  aboutToAppear(): void {
    // 无异步数据，占位保留生命周期一致性
  }

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

  private categoryLabel(index: number): Resource {
    if (index === 1) {
      return $r('app.string.help_cat_borrow');
    }
    if (index === 2) {
      return $r('app.string.help_cat_qa');
    }
    if (index === 3) {
      return $r('app.string.help_cat_skill');
    }
    if (index === 4) {
      return $r('app.string.help_cat_carry');
    }
    return $r('app.string.help_cat_errand');
  }

  private async onPublish(): Promise<void> {
    if (this.title.trim() === '') {
      this.toast($r('app.string.help_title_hint'));
      return;
    }
    const cats: string[] = ['errand', 'borrow', 'qa', 'skill', 'carry'];
    const body: PublishHelpBody = new PublishHelpBody(
      this.title, cats[this.categoryIndex], this.description, this.rewardPoint,
      this.expectTime, this.place, 0, 0);
    const res: Result<PublishHelpResult> = await HelpService.publish(body);
    if (res.isOk()) {
      this.toast($r('app.string.publish_success'));
      this.back();
    } else {
      this.toast(res.message);
    }
  }

  // ==================== 局部 UI ====================

  /** ② 小鸿提示卡 */
  @Builder
  agentTipCard() {
    Column() {
      Row() {
        Row() {
          Text($r('app.string.agent_badge'))
            .fontSize(AppTheme.fontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textOnPrimary)
        }
        .width(26)
        .height(26)
        .borderRadius(13)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.primaryGradientStart)

        Text($r('app.string.help_agent_tip'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textPrimary)
          .lineHeight(18)
          .layoutWeight(1)
          .margin({ left: 9 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row() {
        Text($r('app.string.help_agent_hint'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textHint)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(30)
      .padding({ left: 10, right: 10 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppTheme.surface)
      .borderRadius(11)
      .margin({ top: 9 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(11)
    .backgroundColor(AppTheme.primaryLight)
    .borderRadius(14)
    .margin({ top: 12 })
  }

  /** ③ 表单字段标签。topGap 是「与上一项的间距」，避免调用处对 @Builder 链属性。 */
  @Builder
  fieldLabel(text: Resource, topGap: number) {
    Text(text)
      .fontSize(AppTheme.fontCaption)
      .fontColor(AppTheme.textSecondary)
      .width('100%')
      .margin({ top: topGap })
  }

  /** ③ 单行输入框（标题 / 期望时间 / 悬赏积分） */
  @Builder
  inputRow(placeholder: Resource, value: string) {
    TextInput({ placeholder: placeholder, text: value })
      .height(38)
      .width('100%')
      .padding({ left: 11, right: 11 })
      .backgroundColor(AppTheme.fillGray)
      .borderRadius(11)
      .fontSize(AppTheme.fontSecondary)
      .fontColor(AppTheme.textPrimary)
      .placeholderColor(AppTheme.textHint)
      .caretColor(AppTheme.primary)
      .margin({ top: 6 })
  }

  /**
   * ③ 地点行：输入框 + 右侧「地图选点」图钉按钮（与发布活动页同款）。
   * 求助详情展示「求助地点 + 导航图标」且模型带 lat/lng —— 发布侧必须能产出一个点。
   * U 阶段点击仅提示；D/F 阶段接 Map Kit 选点页回填地址与坐标。
   */
  @Builder
  placeInput(text: string, onChange: (v: string) => void) {
    Row() {
      TextInput({ placeholder: $r('app.string.help_expect_hint'), text: text })
        .layoutWeight(1)
        .height('100%')
        .padding(0)
        .backgroundColor(Color.Transparent)
        .fontSize(AppTheme.fontSecondary)
        .fontColor(AppTheme.textPrimary)
        .placeholderColor(AppTheme.textHint)
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

  /** ③ 分类胶囊（单行横向，5 个） */
  @Builder
  categoryChips() {
    Row() {
      ForEach(this.categoryItems(), (label: Resource, index: number) => {
        Text(label)
          .fontSize(AppTheme.fontCaption)
          .fontColor(index === this.categoryIndex ? AppTheme.textOnPrimary : AppTheme.textSecondary)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(index === this.categoryIndex ? AppTheme.primary : AppTheme.fillGray)
          .borderRadius(11)
          .margin({ right: 6 })
          .onClick(() => {
            this.categoryIndex = index;
          })
      }, (label: Resource, index: number) => 'cat-' + index.toString())
    }
    .width('100%')
    .margin({ top: 6 })
  }

  private categoryItems(): Resource[] {
    const out: Resource[] = [];
    for (let i = 0; i < 5; i++) {
      out.push(this.categoryLabel(i));
    }
    return out;
  }

  /** ③ 悬赏积分行：数字 + 可用积分 */
  @Builder
  rewardRow() {
    Row() {
      Text() {
        Span(this.rewardPoint.toString() + ' ')
          .fontSize(AppTheme.fontSecondary)
          .fontColor(AppTheme.textPrimary)
        Span($r('app.string.common_unit_point'))
          .fontSize(AppTheme.fontSecondary)
          .fontColor(AppTheme.textPrimary)
      }
      .layoutWeight(1)

      Text() {
        Span($r('app.string.help_reward_available', 320))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textHint)
      }
    }
    .width('100%')
    .height(38)
    .padding({ left: 11, right: 11 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.fillGray)
    .borderRadius(11)
    .margin({ top: 6 })
  }

  /** ③ 表单卡 */
  @Builder
  formCard() {
    Column() {
      this.fieldLabel($r('app.string.publish_label_title'), 0)
      this.inputRow($r('app.string.help_title_hint'), this.title)

      this.fieldLabel($r('app.string.publish_label_category'), 12)
      this.categoryChips()

      this.fieldLabel($r('app.string.publish_label_desc'), 12)
      TextArea({ placeholder: $r('app.string.publish_label_desc'), text: this.description })
        .height(72)
        .width('100%')
        .padding({ left: 11, right: 11, top: 9, bottom: 9 })
        .backgroundColor(AppTheme.fillGray)
        .borderRadius(11)
        .fontSize(AppTheme.fontSecondary)
        .fontColor(AppTheme.textPrimary)
        .placeholderColor(AppTheme.textHint)
        .caretColor(AppTheme.primary)
        .margin({ top: 6 })

      this.fieldLabel($r('app.string.publish_label_expect_time'), 12)
      this.inputRow($r('app.string.help_expect_hint'), this.expectTime)

      this.fieldLabel($r('app.string.help_label_place'), 12)
      this.placeInput(this.place, (v: string) => {
        this.place = v;
      })

      this.fieldLabel($r('app.string.publish_label_reward'), 12)
      this.rewardRow()

      Text($r('app.string.help_reward_hint'))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.textHint)
        .width('100%')
        .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .margin({ top: 12 })
  }

  /** ④ 底部绿色发布按钮 */
  @Builder
  bottomBar() {
    Column() {
      Row() {
        Text($r('app.string.help_publish'))
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textOnPrimary)
      }
      .width('100%')
      .height(AppTheme.buttonHeight)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.accent)
      .borderRadius(AppTheme.pillRadius)
      .onClick(() => {
        this.onPublish();
      })
    }
    .width('100%')
    .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 12, bottom: 14 })
    .backgroundColor(AppTheme.surface)
  }

  build() {
    Column() {
      PageHeader({
        title: $r('app.string.publish_help_title'),
        showAction: true,
        actionText: $r('app.string.help_draft'),
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
          this.formCard()
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
    .backgroundColor(AppTheme.pageBackground)
  }
}
