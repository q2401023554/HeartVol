import { AppTheme } from '../common/AppTheme';
import { MessageType } from '../common/Constants';
import { BizDict } from '../common/BizDict';
import { DateFmt } from '../common/DateFmt';
import { MessageItem } from '../model/MessageItem';
import { MineService } from '../service/MineService';
import { PageHeader } from '../components/PageHeader';
import { MessageCell } from '../components/MessageCell';
import { EmptyState } from '../components/EmptyState';
import { RouteParams } from '../common/RouteParams';
import { LoadingOverlay } from '../components/LoadingOverlay';
import { GradientIcon } from '../components/GradientIcon';
import { appIcon, agentMark, IconPath, navIcon, NavIconId } from '../common/AppIcon';

/**
 * 消息中心四个会话的类型码 —— 与 slot 顺序严格一致。
 */
const TAB_TYPES: string[] = [MessageType.NOTICE, MessageType.INTERACT, MessageType.ACTIVITY, MessageType.HELP];

/**
 * MessagesPage —— 消息中心（会话式，参照常见 IM 双层结构）
 *
 *   会话列表态（viewPos = -1）：
 *     ① 顶栏：返回 + 「消息」 + 右侧「全部已读」
 *     ② 四条会话卡：彩色圆图标 + 类型名 + 最新一条预览 + 时间 + 未读数徽章
 *   分类列表态（viewPos = 0~3）：
 *     ③ 顶栏返回变「回到会话列表」+ 标题为类型名，下面是该类消息完整列表
 *
 * 【为什么页内切换而不是新路由】会话 ↔ 列表是同一份数据的两种聚合视图，
 *   页内 @State 切换不用重新登录态/重拉全量，返回手势语义也更自然。
 * 【预览数据】一次拉全量（size=50）按 type 分组：每组取 createTime 最新一条做
 *   预览 + countUnread 做角标；进入分类态时再按类精确拉取完整列表。
 */
@Entry
@Component
struct MessagesPage {
  @State loading: boolean = true;
  /** -1 = 会话列表；0~3 = 对应类型的消息列表 */
  @State viewPos: number = -1;
  /** 每个 Tab 的未读数（下标与 TAB_TYPES 对齐） */
  @State unreadList: number[] = [0, 0, 0, 0];
  /** 列表版本号：就地置已读后 +1，强制 ForEach 重建 */
  @State listTick: number = 0;

  /** 全量消息缓存（会话态的预览/角标数据源） */
  private all: MessageItem[] = [];
  /** 当前分类态展示的列表 */
  private list: MessageItem[] = [];

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      this.all = await MineService.messages('');
      this.recountUnread();
    } catch (err) {
      this.all = [];
    }
    this.loading = false;
  }

  /** 由全量缓存重算四类角标 */
  private recountUnread(): void {
    for (let i = 0; i < TAB_TYPES.length; i++) {
      this.unreadList[i] = MessageItem.countUnread(MessageItem.filterByType(this.all, TAB_TYPES[i]));
    }
    this.listTick = this.listTick + 1;
  }

  /** 某类型里 createTime 最新的一条（时间串字典序即时间序） */
  private latestOf(type: string): MessageItem | null {
    const arr: MessageItem[] = MessageItem.filterByType(this.all, type);
    let out: MessageItem | null = null;
    for (let i = 0; i < arr.length; i++) {
      if (out === null || arr[i].createTime > out.createTime) {
        out = arr[i];
      }
    }
    return out;
  }

  private async openConversation(index: number): Promise<void> {
    this.viewPos = index;
    try {
      this.list = await MineService.messages(TAB_TYPES[index]);
    } catch (err) {
      this.list = [];
    }
    this.listTick = this.listTick + 1;
  }

  /** 从分类列表回到会话列表（顺带刷新角标：单条已读已乐观改过 all） */
  private backToConversations(): void {
    this.viewPos = -1;
    this.recountUnread();
  }

  /** 全部已读：乐观置位 + 角标清零，再后台调真实接口 */
  private async markAllRead(): Promise<void> {
    let changed: boolean = false;
    for (let i = 0; i < this.all.length; i++) {
      if (!this.all[i].isRead) {
        this.all[i].isRead = true;
        changed = true;
      }
    }
    for (let i = 0; i < this.list.length; i++) {
      if (!this.list[i].isRead) {
        this.list[i].isRead = true;
        changed = true;
      }
    }
    for (let i = 0; i < this.unreadList.length; i++) {
      this.unreadList[i] = 0;
    }
    if (changed) {
      this.listTick = this.listTick + 1;
    }
    await MineService.markAllRead('');
  }

  /** 单条已读：乐观置位 + 角标 -1，再后台调真实接口 */
  /**
   * 点通知：聊天通知直达对话（fromUid=发送者，精确到人，发布者直接回复咨询）；
   * 系统通知（无发送者）落对应详情页；notice/interact 仅标已读。
   */
  private openFromMessage(item: MessageItem): void {
    this.markItemRead(item.id);
    try {
      const isChatNotice: boolean =
        item.title.indexOf('发来消息') >= 0 || item.title.indexOf('聊天') >= 0;
      if (item.relatedId > 0 && isChatNotice && item.fromUid > 0) {
        // 聊天通知：进与发送者的会话（help=互助双方 / activity=发布者回复该咨询者）
        this.getUIContext().getRouter().pushUrl({
          url: 'pages/ChatPage',
          params: RouteParams.chatPage(item.type, item.relatedId, '', item.fromUid)
        });
        return;
      }
      if (item.relatedId > 0 && isChatNotice) {
        // 聊天通知但发送者缺失（极旧数据兜底）→ 会话列表（按对方逐条进）
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ChatListPage' });
        return;
      }
      if (item.type === 'help' && item.relatedId > 0) {
        // 互助系统通知（接单/完成/评价）→ 求助详情
        this.getUIContext().getRouter().pushUrl({
          url: 'pages/HelpDetailPage',
          params: RouteParams.helpDetail(item.relatedId)
        });
        return;
      }
      if (item.type === 'activity' && item.relatedId > 0) {
        // 活动系统通知（报名成功/时长到账）→ 活动详情
        this.getUIContext().getRouter().pushUrl({
          url: 'pages/ActivityDetailPage',
          params: RouteParams.activityDetail(item.relatedId)
        });
      }
    } catch (err) {
      // 跳转失败保持当前页（已读已生效）
    }
  }

  private markItemRead(id: number): void {
    let changed: boolean = false;
    for (let i = 0; i < this.list.length; i++) {
      if (this.list[i].id === id && !this.list[i].isRead) {
        this.list[i].isRead = true;
        // 同步改全量缓存，回会话列表时角标一致
        for (let j = 0; j < this.all.length; j++) {
          if (this.all[j].id === id) {
            this.all[j].isRead = true;
          }
        }
        const idx: number = this.viewPos;
        if (idx >= 0 && idx < this.unreadList.length) {
          this.unreadList[idx] = Math.max(0, this.unreadList[idx] - 1);
        }
        changed = true;
      }
    }
    if (changed) {
      this.listTick = this.listTick + 1;
      MineService.markRead(id);
    }
  }

  // ==================== 导航 ====================

  private back(): void {
    // 分类态的返回先回会话列表，会话列表态的返回才是出页面
    if (this.viewPos >= 0) {
      this.backToConversations();
      return;
    }
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  private title(): Resource {
    if (this.viewPos === 1) {
      return $r('app.string.msg_tab_interact');
    }
    if (this.viewPos === 2) {
      return $r('app.string.msg_tab_activity');
    }
    if (this.viewPos === 3) {
      return $r('app.string.msg_tab_help');
    }
    if (this.viewPos === 0) {
      return $r('app.string.msg_tab_notice');
    }
    return $r('app.string.msg_title');
  }

  private tabLabel(index: number): Resource {
    if (index === 1) {
      return $r('app.string.msg_tab_interact');
    }
    if (index === 2) {
      return $r('app.string.msg_tab_activity');
    }
    if (index === 3) {
      return $r('app.string.msg_tab_help');
    }
    return $r('app.string.msg_tab_notice');
  }

  // ==================== 局部 UI：会话列表态 ====================

  /** ② 单条会话（彩色圆图标 + 类型名 + 最新预览 + 时间 + 未读徽章） */
  @Builder
  conversationRow(index: number) {
    Row() {
      GradientIcon({
        path: BizDict.msgIcon(TAB_TYPES[index]),
        tone: BizDict.msgTone(TAB_TYPES[index]),
        boxSize: 44,
        glyphSize: 22,
        radius: 13
      })

      Column() {
        Row() {
          Text(this.tabLabel(index))
            .fontSize(AppTheme.fontBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Blank()
          Text(this.previewTime(index))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textHint)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Text(this.previewText(index))
            .fontSize(AppTheme.fontSecondary)
            .fontColor(AppTheme.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (this.unreadList[index] > 0) {
            Text(this.unreadList[index].toString())
              .fontSize(AppTheme.fontBadge)
              .fontColor(AppTheme.textOnPrimary)
              .textAlign(TextAlign.Center)
              .constraintSize({ minWidth: 16 })
              .height(16)
              .borderRadius(8)
              .backgroundColor(AppTheme.badgeRed)
              .padding({ left: 4, right: 4 })
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .onClick(() => {
      this.openConversation(index);
    })
  }

  /** 会话预览：最新一条的内容；该类无消息显示占位 */
  private previewText(index: number): ResourceStr {
    const m: MessageItem | null = this.latestOf(TAB_TYPES[index]);
    if (m === null) {
      return $r('app.string.msg_empty');
    }
    return m.content;
  }

  private previewTime(index: number): string {
    const m: MessageItem | null = this.latestOf(TAB_TYPES[index]);
    if (m === null) {
      return '';
    }
    return DateFmt.mdhm(m.createTime);
  }

  @Builder
  conversationList() {
    Column() {
      // 志愿小鸿入口（G：AI 助手对话在「小鸿」Tab，这里发信号切 Tab）
      Row() {
        // 小鸿圆头图标（与底栏小鸿同款）
        Row() {
          agentMark(26, true)
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.primary)

        Column() {
          Text('志愿小鸿 · AI 助手')
            .fontSize(AppTheme.fontBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Text('问活动、问时长、问怎么报名')
            .fontSize(AppTheme.fontSecondary)
            .fontColor(AppTheme.textSecondary)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })

        appIcon(IconPath.CHEVRON_RIGHT, 14, AppTheme.textHint)
      }
      .width('100%')
      .padding(12)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppTheme.surface)
      .borderRadius(AppTheme.cardRadius)
      .margin({ top: 10 })
      .onClick(() => {
        try {
          AppStorage.setOrCreate('pendingTab', NavIconId.AGENT);
          this.getUIContext().getRouter().back();
        } catch (err) {
          // 返回失败留在当前页
        }
      })

      // 互助沟通入口（简化版 IM：发布者↔接单者的聊天会话列表）
      Row() {
        GradientIcon({
          path: BizDict.msgIcon(TAB_TYPES[3]),
          tone: BizDict.msgTone(TAB_TYPES[3]),
          boxSize: 44,
          glyphSize: 22,
          radius: 13
        })

        Column() {
          Text($r('app.string.chat_list_title'))
            .fontSize(AppTheme.fontBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Text($r('app.string.chat_entry_sub'))
            .fontSize(AppTheme.fontSecondary)
            .fontColor(AppTheme.textSecondary)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })

        appIcon(IconPath.CHEVRON_RIGHT, 14, AppTheme.textHint)
      }
      .width('100%')
      .padding(12)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppTheme.surface)
      .borderRadius(AppTheme.cardRadius)
      .margin({ top: 10 })
      .onClick(() => {
        try {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/ChatListPage' });
        } catch (err) {
          // 跳转失败留在当前页
        }
      })

      ForEach(TAB_TYPES, (type: string, index: number) => {
        Column() {
          this.conversationRow(index)
        }
        .width('100%')
        .margin({ top: 10 })
      }, (type: string, index: number) => 'conv-' + index.toString() + '-' + this.unreadList[index].toString() + '-' + this.listTick.toString())
    }
    .width('100%')
  }

  // ==================== 局部 UI：分类列表态 ====================

  private listIsEmpty(): boolean {
    return this.listTick >= 0 && this.list.length === 0;
  }

  @Builder
  messageList() {
    Column() {
      if (this.listIsEmpty()) {
        EmptyState({
          title: $r('app.string.msg_empty'),
          showSubtitle: false
        })
      } else {
        ForEach(this.list, (item: MessageItem) => {
          Row() {
            MessageCell({
              message: item,
              onTap: (id: number) => {
                this.openFromMessage(item);
              }
            })
          }
          .width('100%')
          .margin({ top: 8 })
        }, (item: MessageItem) => item.id.toString() + '-' + item.isRead.toString() + '#' + this.listTick.toString())
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingOverlay({ text: $r('app.string.common_loading') })
      } else {
        Column() {
          PageHeader({
            title: this.title(),
            showAction: this.viewPos < 0,
            actionText: $r('app.string.msg_mark_all_read'),
            actionColor: AppTheme.primary,
            onBack: () => {
              this.back();
            },
            onAction: () => {
              this.markAllRead();
            }
          })

          Scroll() {
            Column() {
              if (this.viewPos < 0) {
                this.conversationList()
              } else {
                this.messageList()
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
