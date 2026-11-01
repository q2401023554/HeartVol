import { AppTheme } from '../common/AppTheme';
import { agentMark, navIcon, NavIconId } from '../common/AppIcon';
import { HomeView } from '../view/HomeView';
import { VolunteerView } from '../view/VolunteerView';
import { AgentView } from '../view/AgentView';
import { HelpView } from '../view/HelpView';
import { MineView } from '../view/MineView';

/**
 * Index —— 主框架页（MainTabPage）
 *
 * 结构：`Tabs`（贴底）+ 自定义 tabBar。
 *   · 5 项**平铺**，无中间凸起球（视觉铁律 ⑥）
 *   · 高 60vp / 图标 22vp / 文字 11vp（尺寸规范）
 *   · 顶边 1vp 细分割线（设计稿是 0.5px，vp 下取 1 更贴实机）
 *   · 选中项：图标 + 文字同时变橙 `primary`；未选中 `text_hint`
 *
 * 【为什么用 Tabs 而不是 if/else 切视图】
 *   Tabs 会保留各 Tab 内部的滚动位置与状态 —— 从「志愿」翻到「我的」再翻回来，
 *   列表不会跳回顶部。if/else 每次切换都销毁重建，体验差一截。
 *   （代价：Tabs 首帧会构建 5 个 TabContent，本项目 5 个页面都很轻，可以接受。）
 *
 * 【选中态为什么能刷新】
 *   `tabItem` 里直接读了 `this.currentIndex`（@State）。@Builder 内部读到的状态变化
 *   会触发该节点重渲染 —— 这正是官方自定义 TabBar 示例的写法。
 */
@Entry
@Component
struct MainTabPage {
  @State currentIndex: number = 0;
  /**
   * 小鸿「动态图标」：整体上下浮动的位移。
   * aboutToAppear 里用 animateTo 的 iterations:-1 + Alternate 触发一次即永久往复，
   * 不需要定时器。⚠️ 该值只在 tabItem（父 Builder）里直接读取——
   * 传进嵌套 @Builder 会因按值传参不重绘（见 tabItem 内注释）。
   */
  @State agentBobY: number = 0;

  // ==================== 小鸿主动气泡（G+：停留 2s 弹出，5s 自动消失） ====================
  @State bubbleVisible: boolean = false;
  /** 每个 Tab 只弹一次的标记（下标与 5 个 Tab 对齐；小鸿页永不弹） */
  private bubbleShown: boolean[] = [false, false, false, false, false];
  private bubbleTimer: number = -1;

  aboutToAppear(): void {
    this.startAgentBob();
    this.scheduleBubble(0);
  }

  /**
   * pushUrl 二级页（消息中心等）发回的切 Tab 请求：读一次待办并清除。
   * 消息中心「志愿小鸿」入口卡 → set pendingTab + router.back() → 这里切到小鸿 Tab。
   */
  onPageShow(): void {
    const pending: number | undefined = AppStorage.get<number>('pendingTab');
    if (pending !== undefined && pending >= 0) {
      AppStorage.setOrCreate('pendingTab', -1);
      this.currentIndex = pending;
      this.scheduleBubble(pending);
    }
  }

  /**
   * 切到某 Tab 后停留 1s 弹小鸿气泡（该 Tab 未弹过且不是小鸿页本身）。
   * 弹出后**常驻**（不自动消失）；点 ✕ 关闭后该 Tab 不再弹，重启 App 才重置。
   */
  private scheduleBubble(index: number): void {
    if (this.bubbleTimer >= 0) {
      clearTimeout(this.bubbleTimer);
      this.bubbleTimer = -1;
    }
    this.bubbleVisible = false;
    if (index === NavIconId.AGENT) {
      return;
    }
    if (index < 0 || index >= this.bubbleShown.length || this.bubbleShown[index]) {
      return;
    }
    this.bubbleTimer = setTimeout(() => {
      this.bubbleTimer = -1;
      this.bubbleShown[index] = true;
      this.bubbleVisible = true;
    }, 1000);
  }

  private closeBubble(): void {
    this.bubbleVisible = false;
  }

  /** 点气泡 → 切到小鸿 Tab（气泡在 Index 内部，直接切，无需路由） */
  private openAgentFromBubble(): void {
    this.closeBubble();
    this.currentIndex = NavIconId.AGENT;
  }

  /** 首帧后启动小鸿浮动循环（animateTo 需在首帧后触发，延后一拍最稳） */
  private startAgentBob(): void {
    setTimeout(() => {
      try {
        this.getUIContext().animateTo({
          duration: 900,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        }, () => {
          this.agentBobY = -3;
        });
      } catch (err) {
        // 动画启动失败则小鸿保持静态，不影响功能
      }
    }, 100);
  }

  /**
   * 用方法取 Tab 文案，而不是 `Resource[]` 成员数组：
   *   数组初始化里的 $r() 在 struct 成员上的行为不如静态字段稳，
   *   方法里写 if 链虽然啰嗦，但零风险。
   */
  private titleOf(index: number): Resource {
    if (index === NavIconId.VOLUNTEER) {
      return $r('app.string.nav_volunteer');
    }
    if (index === NavIconId.AGENT) {
      return $r('app.string.nav_agent');
    }
    if (index === NavIconId.HELP) {
      return $r('app.string.nav_help');
    }
    if (index === NavIconId.MINE) {
      return $r('app.string.nav_mine');
    }
    return $r('app.string.nav_home');
  }

  @Builder
  tabItem(index: number) {
    Column() {
      // 🔴 图标颜色经嵌套 @Builder 按值传参，参数变化不触发子 Builder 重绘
      //（真机实锤：文字变色、图标停留首帧）→ 用 if/else 分支切换选中态：
      // 分支切换是结构性重建，必定以新颜色重新创建图标实例。
      if (index === NavIconId.AGENT) {
        // 小鸿动态图标：28 圆（比其他 22 图标大一圈，作底栏焦点）+ 上下浮动；
        // 浮动位移挂在外层 Row 上、直接读本组件 @State（父 Builder 层，可刷新）
        Row() {
          if (this.currentIndex === index) {
            navIcon(index, 28, AppTheme.primary, true)
          } else {
            navIcon(index, 28, AppTheme.textHint, false)
          }
        }
        .translate({ y: this.agentBobY })
      } else if (this.currentIndex === index) {
        navIcon(index, 22, AppTheme.primary, true)
      } else {
        navIcon(index, 22, AppTheme.textHint, false)
      }
      Text(this.titleOf(index))
        .fontSize(AppTheme.fontCaption)
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentIndex === index ? AppTheme.primary : AppTheme.textHint)
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .border({ width: { top: 1 }, color: AppTheme.divider })
  }

  build() {
    // Stack 容器：Tabs 为主体，小鸿主动气泡浮在底栏小鸿图标正上方（Bottom 对齐 + 底边距 72 = 底栏 60 + 12 间距）
    Stack({ alignContent: Alignment.Bottom }) {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        // 首页里「求助大厅」要切到互助 Tab、搜索框要切到小鸿 Tab，所以把切换能力注入进去。
        // 视图层不直接持有 Tab 的下标，避免「谁负责切 Tab」散到各个 View 里。
        HomeView({
          onSwitchTab: (index: number) => {
            this.currentIndex = index;
          }
        })
      }
      .tabBar(this.tabItem(NavIconId.HOME))

      TabContent() {
        VolunteerView()
      }
      .tabBar(this.tabItem(NavIconId.VOLUNTEER))

      TabContent() {
        AgentView()
      }
      .tabBar(this.tabItem(NavIconId.AGENT))

      TabContent() {
        HelpView()
      }
      .tabBar(this.tabItem(NavIconId.HELP))

      TabContent() {
        // 「我的」宫格里的「我的求助」要切回互助 Tab，同样注入切换能力。
        MineView({
          onSwitchTab: (index: number) => {
            this.currentIndex = index;
          }
        })
      }
      .tabBar(this.tabItem(NavIconId.MINE))
    }
    .barMode(BarMode.Fixed)
    .barHeight(AppTheme.navBarHeight)
    .barBackgroundColor(AppTheme.surface)
    .scrollable(false)
    .animationDuration(0)
    .onChange((index: number) => {
      this.currentIndex = index;
      this.scheduleBubble(index);
    })
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)

    // 小鸿主动气泡：浮在底栏小鸿图标正上方（水平居中），点主体进小鸿、右上角 ✕ 关闭
    if (this.bubbleVisible) {
      Column() {
        // 主体外包 Stack：✕ 圆钮压在气泡右上角（经典气泡关闭样式，半个圆出界）
        Stack({ alignContent: Alignment.TopEnd }) {
          Row() {
            Row() {
              agentMark(24, true)
            }
            .width(32)
            .height(32)
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(AppTheme.primary)

            Text('有什么需要我帮忙的吗')
              .fontSize(AppTheme.fontSecondary)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .margin({ left: 8 })
          }
          .padding({ left: 10, right: 18, top: 9, bottom: 9 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor(AppTheme.surface)
          .borderRadius(20)
          .border({ width: 1, color: AppTheme.divider })
          .shadow({ radius: 12, color: AppTheme.bubbleShadow, offsetY: 4 })
          .onClick(() => {
            this.openAgentFromBubble();
          })

          Row() {
            Text('✕')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textOnPrimary)
          }
          .width(20)
          .height(20)
          .borderRadius(10)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.textHint)
          .margin({ top: -6, right: -6 })
          .onClick(() => {
            this.closeBubble();
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      // ⚠️ Resource 算术禁令：底栏 60 + 间距 12 直接写 72
      .margin({ bottom: 72 })
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.OPACITY.animation({ duration: 250 })
          .combine(TransitionEffect.translate({ y: -10 })),
        TransitionEffect.OPACITY.animation({ duration: 200 })
      ))
    }
    }
  }
}
