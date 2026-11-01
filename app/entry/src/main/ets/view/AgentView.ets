import { AppTheme } from '../common/AppTheme';
import { agentMark, agentSendIcon, appIcon, IconPath } from '../common/AppIcon';
import { ChatCard, ChatCardCell, ChatCardRow, ChatMessage } from '../model/ChatMessage';
import { AgentService } from '../service/AgentService';
import { RouteParams } from '../common/RouteParams';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { EmptyState } from '../components/EmptyState';

// ==================== 一次性几何值（照 `UI界面稿.html` 小鸿屏的 px 1:1 取 vp） ====================

/** 气泡圆角：三边 12，指向说话人的那一角收成 3 —— 设计稿的 `12px 12px 3px 12px` */
const BUBBLE_RADIUS: number = 12;
const BUBBLE_TAIL: number = 3;
/** 气泡/卡片内边距（设计稿气泡 8×10，卡片 11） */
const BUBBLE_PAD_V: number = 8;
const BUBBLE_PAD_H: number = 10;
const CARD_RADIUS: number = 14;
const CARD_PADDING: number = 11;
/** 草稿卡按钮高 36 —— 设计稿画的是 28px，但 28 低于可点区域舒适下限，取 36 */
const DRAFT_BTN_HEIGHT: number = 36;
/** 发送键直径 36（设计稿 32） */
const SEND_BTN: number = 36;
/** 头部小鸿标识 32 —— 与设计稿的 32px 头像圈一致 */
const AVATAR: number = 32;
/** 模拟「小鸿正在思考」的延时（Mock 专用，D 阶段换成真实请求耗时） */
const THINKING_MS: number = 600;

/**
 * AgentView —— 志愿小鸿（Tab 3）
 *
 * 全工程唯一的小鸿入口。版式照 `UI\鸿志愿_首页_志愿大厅_志愿小鸿_界面稿.png` 第三屏：
 *   ① 头部：橙色小机器人标识 + 「志愿小鸿 / 随时帮你办事」+ 绿点「在线」——**没有返回键**，
 *      因为它是 Tab 而不是二级页
 *   ② 会话流（可滚动）：用户橙底右对齐气泡 / 小鸿白底左对齐气泡 / 结构化卡片
 *   ③ 快捷提问芯片（橙色浅底胶囊）
 *   ④ 输入条：白底胶囊 + 橙色圆形发送键
 *
 * 【小鸿和普通聊天机器人的区别就在 ② 里的「卡片」】
 *   它不只回一句话，而是回一张能点的卡片：草稿卡带「去修改 / 一键发布」，
 *   推荐卡点进去就是活动详情。所以气泡与卡片是两套渲染分支，别把卡片塞进气泡里。
 *
 * 【为什么消息是普通成员 + `tick` 版本号】
 *   `ChatMessage` 带方法（`isUser()`），加 `@State` 有丢方法的风险，所以数据用普通成员；
 *   而普通成员变更**不会触发重绘** —— 于是用一个 `@State tick` 拼进 ForEach 的 key：
 *   tick 一变，整段会话被重建并读到新消息（同 `VolunteerView` 的 `listTick`）。
 *
 * 【数据】只经 `AgentService` 拿，不认识 MockData。
 */
@Component
export struct AgentView {
  @State loading: boolean = true;
  /** 历史加载失败（区别于空会话：失败才显示「网络开小差了」重试态） */
  @State loadFailed: boolean = false;
  /** 输入框内容（@State：边打边改要回显） */
  @State inputText: string = '';
  /** 会话版本号：每次增删消息 +1，用来强制 ForEach 重建（见类注释） */
  @State tick: number = 0;
  /** 是否有一条回复在路上（防连点发送） */
  @State sending: boolean = false;

  /** 会话内容（普通成员，见类注释） */
  private messages: ChatMessage[] = [];
  /** 快捷提问芯片（后端可配） */
  private prompts: string[] = [];
  /** 本地消息 id 发号器 —— Mock 数据 id 从 901 起，本地从 900001 起，不会撞 */
  private seq: number = 0;
  private scroller: Scroller = new Scroller();
  /** 小鸿头像浮动位移（animateTo 无限往复驱动，见 startAgentBob） */
  @State agentBobY: number = 0;

  aboutToAppear(): void {
    this.load();
    this.startAgentBob();
  }

  /**
   * 小鸿头像「动态图标」：与底栏同款上下浮动。
   * ⚠️ animateTo 需在首帧后触发，延后一拍最稳；
   * 浮动位移只能挂在 header() 里**直接读本组件 @State** 的容器上——
   * 传进嵌套 agentMark 会因按值传参不重绘。
   */
  private startAgentBob(): void {
    setTimeout(() => {
      try {
        this.getUIContext().animateTo({
          duration: 900,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        }, () => {
          this.agentBobY = -2.5;
        });
      } catch (err) {
        // 动画启动失败则头像保持静态，不影响功能
      }
    }, 100);
  }

  private nextId(): number {
    this.seq = this.seq + 1;
    return 900000 + this.seq;
  }

  // ==================== 数据 ====================

  private async load(): Promise<void> {
    try {
      const history = await AgentService.conversation();
      this.loadFailed = history === null;
      this.messages = history === null ? [] : history;
      this.prompts = await AgentService.prompts();
    } catch (err) {
      this.loadFailed = true;
      this.messages = [];
    }
    this.tick = this.tick + 1;
    this.loading = false;
    this.scrollBottom();
  }

  /**
   * 滚到底。
   * `scrollEdge` 要求列表已布局完成，首次进入时 setState 还没提交，
   * 所以延后一拍再滚 —— 比 `scrollToIndex` 稳（不用关心到底有多少条）。
   */
  private scrollBottom(): void {
    setTimeout(() => {
      try {
        this.scroller.scrollEdge(Edge.Bottom);
      } catch (err) {
        // 列表还没布局（例如空会话）时忽略
      }
    }, 60);
  }

  // ==================== 发送 ====================

  private send(text: string): void {
    const content: string = text.trim();
    if (content === '' || this.sending) {
      return;
    }
    this.inputText = '';
    this.sending = true;

    const mine: ChatMessage = ChatMessage.localUserMessage(content);
    mine.id = this.nextId();
    const thinking: ChatMessage = ChatMessage.localLoadingMessage();
    thinking.id = this.nextId();
    this.messages.push(mine);
    this.messages.push(thinking);
    this.tick = this.tick + 1;
    this.scrollBottom();

    // Mock 阶段用固定延时代替「请求在路上」：先把「思考中」占位亮出来，
    // 再换成真回复。D 阶段把这两行换成 `await` 一个 /api/chat 即可。
    setTimeout(() => {
      this.finishReply(content);
    }, THINKING_MS);
  }

  private async finishReply(content: string): Promise<void> {
    let reply: ChatMessage | null = null;
    try {
      reply = await AgentService.reply(content);
    } catch (err) {
      reply = null;
    }
    this.messages.pop();
    if (reply !== null) {
      reply.id = this.nextId();
      this.messages.push(reply);
    } else {
      this.toast($r('app.string.common_net_error'));
    }
    this.tick = this.tick + 1;
    this.sending = false;
    this.scrollBottom();
  }

  // ==================== 动作 ====================

  private goto(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: url });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  private openActivity(id: number): void {
    if (id <= 0) {
      return;
    }
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ActivityDetailPage',
        params: RouteParams.activityDetail(id)
      });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  private toast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      // toast 失败不影响主流程
    }
  }

  /** 「一键发布」：把草稿卡就地改成已发布态（按钮换成绿色勾标） */
  private publishDraft(card: ChatCard): void {
    card.isDraft = false;
    this.tick = this.tick + 1;
    this.toast($r('app.string.publish_success'));
  }

  /**
   * 字段码值 → 中文标签。
   * 映射只写在这一处，卡片数据里存的是英文码（与工程「码值走英文、文案走 resources」一致）。
   */
  private fieldLabel(code: string): Resource {
    if (code === 'place') {
      return $r('app.string.agent_field_place');
    }
    if (code === 'count') {
      return $r('app.string.agent_field_count');
    }
    if (code === 'hours') {
      return $r('app.string.agent_field_hours');
    }
    if (code === 'reward') {
      return $r('app.string.agent_field_reward');
    }
    if (code === 'expect') {
      return $r('app.string.agent_field_expect');
    }
    return $r('app.string.agent_field_time');
  }

  // ==================== 局部 UI ====================

  /** ① 头部（小鸿标识 + 名字/副标题 + 在线） */
  @Builder
  header() {
    Row() {
      // 浮动位移挂在外层 Row、直接读 @State（父 Builder 层可刷新；不传进嵌套 agentMark）
      Row() {
        agentMark(AVATAR, false)
      }
      .translate({ y: this.agentBobY })

      Column() {
        Text($r('app.string.agent_name'))
          .fontSize(AppTheme.fontTitleCard)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)

        Text($r('app.string.agent_subtitle'))
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 8 })

      Row()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(AppTheme.accent)

      Text($r('app.string.agent_online'))
        .fontSize(AppTheme.fontCaption)
        .fontColor(AppTheme.accent)
        .margin({ left: 4 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12, top: 10, bottom: 8 })
  }

  /** ② 用户气泡（橙底白字，右对齐，右下角收角） */
  @Builder
  userBubble(text: string) {
    Row() {
      Text(text)
        .fontSize(AppTheme.fontBody)
        .fontColor(AppTheme.textOnPrimary)
        .lineHeight(24)
        .padding({ left: BUBBLE_PAD_H, right: BUBBLE_PAD_H, top: BUBBLE_PAD_V, bottom: BUBBLE_PAD_V })
        .backgroundColor(AppTheme.primary)
        .borderRadius({
          topLeft: BUBBLE_RADIUS,
          topRight: BUBBLE_RADIUS,
          bottomLeft: BUBBLE_RADIUS,
          bottomRight: BUBBLE_TAIL
        })
        .constraintSize({ maxWidth: '90%' })
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
  }

  /** ② 小鸿气泡（白底黑字，左对齐，左下角收角） */
  @Builder
  assistantBubble(text: string) {
    Row() {
      Text(text)
        .fontSize(AppTheme.fontBody)
        .fontColor(AppTheme.textPrimary)
        .lineHeight(24)
        .padding({ left: BUBBLE_PAD_H, right: BUBBLE_PAD_H, top: BUBBLE_PAD_V, bottom: BUBBLE_PAD_V })
        .backgroundColor(AppTheme.surface)
        .borderRadius({
          topLeft: BUBBLE_RADIUS,
          topRight: BUBBLE_RADIUS,
          bottomLeft: BUBBLE_TAIL,
          bottomRight: BUBBLE_RADIUS
        })
        .constraintSize({ maxWidth: '90%' })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** ②「小鸿正在思考…」占位气泡（灰字，形状与小鸿气泡一致，好让它原地被替换） */
  @Builder
  thinkingBubble() {
    Row() {
      Text($r('app.string.agent_thinking'))
        .fontSize(AppTheme.fontBody)
        .fontColor(AppTheme.textHint)
        .lineHeight(24)
        .padding({ left: BUBBLE_PAD_H, right: BUBBLE_PAD_H, top: BUBBLE_PAD_V, bottom: BUBBLE_PAD_V })
        .backgroundColor(AppTheme.surface)
        .borderRadius({
          topLeft: BUBBLE_RADIUS,
          topRight: BUBBLE_RADIUS,
          bottomLeft: BUBBLE_TAIL,
          bottomRight: BUBBLE_RADIUS
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** ② 结构化卡片：草稿卡（带两个按钮）/ 推荐卡（可点进详情） */
  @Builder
  chatCard(card: ChatCard) {
    Column() {
      Row() {
        Text(card.title)
          .fontSize(AppTheme.fontBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)

        if (card.tag !== '') {
          Text(card.tag)
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.primary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(AppTheme.primaryLight)
            .borderRadius(6)
            .margin({ left: 8 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (card.subtitle !== '') {
        Text(card.subtitle)
          .fontSize(AppTheme.fontCaption)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 4 })
          .width('100%')
      }

      // 字段区：一行 1~2 格。标签是 $r（Resource）不能拼字符串，
      // 所以「标签 + 值」拆成两个相邻 Span，颜色各自不同。
      ForEach(card.rows, (row: ChatCardRow, rowIndex: number) => {
        Row() {
          ForEach(row.cells, (cell: ChatCardCell, cellIndex: number) => {
            Text() {
              Span(this.fieldLabel(cell.label))
                .fontSize(AppTheme.fontCaption)
                .fontColor(AppTheme.textSecondary)
              Span(' ' + cell.value)
                .fontSize(AppTheme.fontBody)
                .fontColor(AppTheme.textPrimary)
            }
            .margin({ right: cellIndex === row.cells.length - 1 ? 0 : 14 })
          }, (cell: ChatCardCell, cellIndex: number) => 'cell-' + rowIndex.toString() + '-' +
            cellIndex.toString() + '#' + this.tick.toString())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: rowIndex === 0 ? 8 : 5 })
      }, (row: ChatCardRow, rowIndex: number) => 'row-' + rowIndex.toString() + '#' + this.tick.toString())

      if (card.isDraft) {
        Row() {
          Row() {
            Text($r('app.string.agent_draft_edit'))
              .fontSize(AppTheme.fontSecondary)
              .fontColor(AppTheme.primary)
          }
          .layoutWeight(1)
          .height(DRAFT_BTN_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.fillGray)
          .borderRadius(DRAFT_BTN_HEIGHT / 2)
          .onClick(() => {
            // D 阶段把这张草稿卡当参数传给发布页做回填，现在先只跳过去
            this.goto('pages/PublishActivityPage');
          })

          Row() {
            Text($r('app.string.agent_draft_publish'))
              .fontSize(AppTheme.fontSecondary)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textOnPrimary)
          }
          .layoutWeight(1)
          .height(DRAFT_BTN_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.primary)
          .borderRadius(DRAFT_BTN_HEIGHT / 2)
          .margin({ left: 7 })
          .onClick(() => {
            this.publishDraft(card);
          })
        }
        .width('100%')
        .margin({ top: 10 })
      } else if (card.isDraft === false && card.rows.length > 0) {
        // 发布之后的态：草稿卡（有字段、但已不是草稿）换成一行绿色勾标
        Row() {
          appIcon(IconPath.CHECK, 14, AppTheme.accent)

          Text($r('app.string.agent_published'))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.accent)
            .margin({ left: 4 })
        }
        .margin({ top: 10 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(CARD_PADDING)
    .backgroundColor(AppTheme.surface)
    .borderRadius(CARD_RADIUS)
    .onClick(() => {
      // 推荐卡（非草稿、且有目标 id）点进去就是活动详情
      if (!card.isDraft && card.targetId > 0) {
        this.openActivity(card.targetId);
      }
    })
  }

  /** ② 单条消息 */
  @Builder
  messageItem(item: ChatMessage) {
    Column() {
      if (item.loading) {
        this.thinkingBubble()
      } else {
        if (item.content !== '') {
          if (item.isUser()) {
            this.userBubble(item.content)
          } else {
            this.assistantBubble(item.content)
          }
        }
        ForEach(item.cards, (card: ChatCard, cardIndex: number) => {
          this.chatCard(card)
        }, (card: ChatCard, cardIndex: number) => 'card-' + cardIndex.toString() + '#' + this.tick.toString())
      }
    }
    .width('100%')
    .alignItems(item.isUser() ? HorizontalAlign.End : HorizontalAlign.Start)
  }

  /** ② 会话流 */
  @Builder
  conversation() {
    List({ space: 9, scroller: this.scroller }) {
      ForEach(this.messages, (item: ChatMessage) => {
        ListItem() {
          this.messageItem(item)
        }
      }, (item: ChatMessage) => item.id.toString() + '#' + this.tick.toString())
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 12, right: 12, top: 12 })
    .scrollBar(BarState.Off)
  }

  /** ③ 快捷提问芯片（设计稿两条，窄屏会自动换行） */
  @Builder
  promptRow() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.prompts, (prompt: string) => {
        Text(prompt)
          .fontSize(AppTheme.fontSecondary)
          .fontColor(AppTheme.primary)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(AppTheme.primaryLight)
          .borderRadius(12)
          .margin({ right: 6, bottom: 6 })
          .onClick(() => {
            this.send(prompt);
          })
      }, (prompt: string) => prompt)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 4 })
  }

  /** ④ 输入条 */
  @Builder
  inputBar() {
    Row() {
      TextInput({ text: this.inputText, placeholder: $r('app.string.agent_input_hint') })
        .fontSize(AppTheme.fontBody)
        .fontColor(AppTheme.textPrimary)
        .placeholderFont({ size: AppTheme.fontCaption })
        .placeholderColor(AppTheme.textHint)
        .backgroundColor(AppTheme.surface)
        .borderRadius(AppTheme.searchBarHeight)
        .height(AppTheme.searchBarHeight)
        .padding({ left: 12, right: 12 })
        .layoutWeight(1)
        .enterKeyType(EnterKeyType.Send)
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onSubmit((enterKey: EnterKeyType) => {
          this.send(this.inputText);
        })

      Row() {
        agentSendIcon(SEND_BTN, 16)
      }
      .margin({ left: 7 })
      .onClick(() => {
        this.send(this.inputText);
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12, top: 6, bottom: 10 })
  }

  build() {
    Column() {
      this.header()

      if (this.loading) {
        Column() {
          LoadingOverlay({ text: $r('app.string.common_loading') })
        }
        .layoutWeight(1)
        .width('100%')
      } else if (this.loadFailed) {
        // 真失败：网络错误 + 重试
        Column() {
          EmptyState({
            iconPath: IconPath.MESSAGE,
            title: $r('app.string.common_net_error'),
            showSubtitle: false,
            showAction: true,
            actionText: $r('app.string.common_retry'),
            onAction: () => {
              this.loading = true;
              this.load();
            }
          })
        }
        .layoutWeight(1)
      } else if (this.messages.length === 0) {
        // 空会话：欢迎语 + 快捷芯片 + 输入条（可发第一句）
        Column() {
          EmptyState({
            iconPath: IconPath.MESSAGE,
            title: $r('app.string.agent_welcome'),
            showSubtitle: false,
            showAction: false
          })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        this.promptRow()
        this.inputBar()
      } else {
        this.conversation()
        this.promptRow()
        this.inputBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
