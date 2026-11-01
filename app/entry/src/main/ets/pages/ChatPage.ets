import { AppTheme } from '../common/AppTheme';
import { DateFmt } from '../common/DateFmt';
import { RouteParams, ChatPageParams } from '../common/RouteParams';
import { ChatMsg, ChatMsgPage, ChatSendReply } from '../model/ChatModels';
import { Result } from '../model/Result';
import { ChatService } from '../service/ChatService';
import { PageHeader } from '../components/PageHeader';
import { LoadingOverlay } from '../components/LoadingOverlay';

/** 轮询间隔：用户定稿 2 秒（简化版 IM 用轮询替代 WebSocket，演示无感差） */
const POLL_MS: number = 2000;

/**
 * ChatPage —— 互助沟通聊天页（发布者↔接单者，会话键 = 求助 id）
 *
 *   ① 顶栏：返回 + 对方姓名
 *   ② 气泡列表：我发=橙底白字靠右，对方=白底深字靠左 + 姓名首字头像圈
 *   ③ 底部输入条：TextInput + 发送钮（发送后立即拉一次，不等下一轮询）
 *
 * 【轮询】aboutToAppear 启动 2s setInterval，afterId 增量（只拉新消息），
 *   aboutToDisappear 清定时器 —— 页面级生命周期，离开即停，不后台耗电。
 */
@Entry
@Component
struct ChatPage {
  @State loading: boolean = true;
  @State msgs: ChatMsg[] = [];
  @State input: string = '';
  @State sending: boolean = false;

  private bizType: string = 'help';
  private bizId: number = 0;
  private peerName: string = '';
  /** 对端 uid：发布者回复活动咨询时必传（路由带入），其余场景 0 */
  private peerUid: number = 0;
  /** 已见到的最大消息 id（增量拉取游标） */
  private lastId: number = 0;
  private pollTimer: number = -1;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    try {
      const raw: Object | undefined = this.getUIContext().getRouter().getParams() as ChatPageParams;
      const p: ChatPageParams = raw as ChatPageParams;
      this.bizType = p.bizType ?? 'help';
      this.bizId = p.bizId ?? 0;
      this.peerName = p.peerName ?? '';
      this.peerUid = p.peerUid ?? 0;
    } catch (err) {
      this.bizId = 0;
    }
    this.fetchAll();
  }

  aboutToDisappear(): void {
    this.stopPoll();
  }

  /** 首次全量拉取（成功后启动轮询） */
  private async fetchAll(): Promise<void> {
    const page: ChatMsgPage = await ChatService.messagesPage(this.bizType, this.bizId, this.peerUid, 0);
    this.msgs = page.list;
    if (page.peerName !== '') {
      this.peerName = page.peerName;
    }
    this.bumpLastId();
    this.loading = false;
    this.scrollBottom();
    this.startPoll();
  }

  private startPoll(): void {
    if (this.pollTimer >= 0) {
      return;
    }
    this.pollTimer = setInterval(() => {
      this.fetchNew();
    }, POLL_MS);
  }

  private stopPoll(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  /** 增量拉新消息（失败静默：下一轮询再试） */
  private async fetchNew(): Promise<void> {
    const page: ChatMsgPage = await ChatService.messagesPage(this.bizType, this.bizId, this.peerUid, this.lastId);
    if (page.peerName !== '' && this.peerName === '') {
      this.peerName = page.peerName;
    }
    const list: ChatMsg[] = page.list;
    if (list.length > 0) {
      // 拼接新消息（保持引用替换触发重绘）
      const merged: ChatMsg[] = this.msgs.slice(0);
      for (let i = 0; i < list.length; i++) {
        merged.push(list[i]);
      }
      this.msgs = merged;
      this.bumpLastId();
      this.scrollBottom();
    }
  }

  private bumpLastId(): void {
    if (this.msgs.length > 0) {
      const tail: ChatMsg = this.msgs[this.msgs.length - 1];
      if (tail.id > this.lastId) {
        this.lastId = tail.id;
      }
    }
  }

  private scrollBottom(): void {
    try {
      this.scroller.scrollEdge(Edge.Bottom);
    } catch (err) {
      // 首帧还没渲染时滚动无效，忽略
    }
  }

  /**
   * 发送：成功后用服务端返回的真实 id 追加气泡。
   * 🔴 不能用本地合成 id 乐观追加——聊天表是多会话共用的全局自增 id，
   *    本地假 id 与真实 id 对不上时，轮询会把同一条消息再拉一遍（出现重复气泡）。
   */
  private async send(): Promise<void> {
    const text: string = this.input.trim();
    if (text === '' || this.sending) {
      return;
    }
    this.sending = true;
    try {
      const res: Result<ChatSendReply> = await ChatService.send(this.bizType, this.bizId, text, this.peerUid);
      if (res.isOk() && res.data !== null) {
        const data: ChatSendReply = res.data as ChatSendReply;
        this.input = '';
        const m: ChatMsg = new ChatMsg();
        m.id = data.id;
        m.fromMine = true;
        m.content = text;
        m.createTime = this.nowMdhm();
        const merged: ChatMsg[] = this.msgs.slice(0);
        merged.push(m);
        this.msgs = merged;
        this.bumpLastId();
        this.scrollBottom();
      } else {
        this.toast(res.message);
      }
    } catch (err) {
      this.toast('发送失败，请重试');
    }
    this.sending = false;
  }

  private toast(msg: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (err) {
      // 提示失败不影响主流程
    }
  }

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  /** 本机当前时刻 'MM-DD HH:mm'（乐观追加的气泡时间戳；服务端消息走 createTime） */
  private nowMdhm(): string {
    const d: Date = new Date();
    const mo: number = d.getMonth() + 1;
    const da: number = d.getDate();
    const h: number = d.getHours();
    const mi: number = d.getMinutes();
    return (mo < 10 ? '0' : '') + mo + '-' + (da < 10 ? '0' : '') + da + ' ' +
      (h < 10 ? '0' : '') + h + ':' + (mi < 10 ? '0' : '') + mi;
  }

  /** 气泡：我发=橙底白字右对齐；对方=白底 + 头像圈左对齐 */
  @Builder
  bubble(item: ChatMsg) {
    Row() {
      if (!item.fromMine) {
        Row() {
          Text(this.peerName === '' ? '友' : this.peerName.substring(0, 1))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
        }
        .width(34)
        .height(34)
        .borderRadius(17)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.primaryLight)

        Column() {
          Text(item.content)
            .fontSize(AppTheme.fontBody)
            .fontColor(AppTheme.textPrimary)
        }
        .constraintSize({ maxWidth: 240 })
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor(AppTheme.surface)
        .borderRadius({ topLeft: 4, topRight: 14, bottomLeft: 14, bottomRight: 14 })
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 8 })
      } else {
        Column() {
          Text(item.content)
            .fontSize(AppTheme.fontBody)
            .fontColor(AppTheme.textOnPrimary)
        }
        .constraintSize({ maxWidth: 240 })
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor(AppTheme.primary)
        .borderRadius({ topLeft: 14, topRight: 4, bottomLeft: 14, bottomRight: 14 })
        .alignItems(HorizontalAlign.End)
      }
    }
    .width('100%')
    .alignItems(item.fromMine ? VerticalAlign.Top : VerticalAlign.Top)
    .justifyContent(item.fromMine ? FlexAlign.End : FlexAlign.Start)
  }

  /** 我发消息的已读回执小字（在气泡下方右侧） */
  @Builder
  readReceipt(item: ChatMsg) {
    if (item.fromMine) {
      Text(item.read ? '已读' : '未读')
        .fontSize(AppTheme.fontBadge)
        .fontColor(item.read ? AppTheme.accent : AppTheme.textHint)
        .margin({ top: 2 })
    }
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingOverlay({ text: $r('app.string.common_loading') })
      } else {
        PageHeader({
          title: this.peerName === '' ? $r('app.string.msg_title') : this.peerName,
          onBack: () => {
            this.back();
          }
        })

        Scroll(this.scroller) {
          Column() {
            if (this.msgs.length === 0) {
              Text('打个招呼，开始沟通吧～')
                .fontSize(AppTheme.fontSecondary)
                .fontColor(AppTheme.textHint)
                .margin({ top: 40 })
            }
            ForEach(this.msgs, (item: ChatMsg) => {
              Column() {
                // 相邻两条间隔 + 时间戳（每条都带，简单清晰）
                Text(DateFmt.mdhm(item.createTime))
                  .fontSize(AppTheme.fontBadge)
                  .fontColor(AppTheme.textHint)
                  .margin({ top: 10, bottom: 4 })

                this.bubble(item)
                this.readReceipt(item)
              }
              .width('100%')
              .alignItems(item.fromMine ? HorizontalAlign.End : HorizontalAlign.Start)
            }, (item: ChatMsg) => item.id.toString() + '-' + item.fromMine.toString() + '-' + item.read.toString())
          }
          .width('100%')
          .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 6, bottom: 10 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        // 底部输入条
        Row() {
          TextInput({ text: this.input, placeholder: '输入消息…' })
            .fontSize(AppTheme.fontBody)
            .fontColor(AppTheme.textPrimary)
            .placeholderColor(AppTheme.textHint)
            .backgroundColor(AppTheme.fillGray)
            .borderRadius(19)
            .height(38)
            .layoutWeight(1)
            .onChange((v: string) => {
              this.input = v;
            })
            .onSubmit(() => {
              this.send();
            })

          Row() {
            Text(this.sending ? '…' : '发送')
              .fontSize(AppTheme.fontSecondary)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textOnPrimary)
          }
          .height(38)
          .padding({ left: 18, right: 18 })
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.primary)
          .borderRadius(19)
          .margin({ left: 8 })
          .onClick(() => {
            this.send();
          })
        }
        .width('100%')
        .padding({ left: AppTheme.pagePaddingH, right: AppTheme.pagePaddingH, top: 8, bottom: 12 })
        .backgroundColor(AppTheme.surface)
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
