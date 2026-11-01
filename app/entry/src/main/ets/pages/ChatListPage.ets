import { AppTheme } from '../common/AppTheme';
import { DateFmt } from '../common/DateFmt';
import { RouteParams } from '../common/RouteParams';
import { ChatConversation } from '../model/ChatModels';
import { ChatService } from '../service/ChatService';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { LoadingOverlay } from '../components/LoadingOverlay';

/**
 * ChatListPage —— 互助沟通会话列表（消息中心「互助沟通」入口进来）
 *
 * 每行：对方头像圈（首字）+ 求助标题 + 最新一条预览 + 时间 + 未读徽章。
 * 点击进 ChatPage（带对方姓名，聊天页标题栏直接可显示）。
 * 返回时 onShow 语义由 aboutToAppear 承担（本页每次进都重拉）。
 */
@Entry
@Component
struct ChatListPage {
  @State loading: boolean = true;
  @State list: ChatConversation[] = [];
  /** 列表版本号（返回本页刷新用） */
  @State tick: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    // 从聊天页返回时刷新未读/最新一条
    if (!this.loading) {
      this.load();
    }
  }

  private async load(): Promise<void> {
    this.list = await ChatService.conversations();
    this.tick = this.tick + 1;
    this.loading = false;
  }

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 路由栈为空时 back() 无操作
    }
  }

  private openChat(item: ChatConversation): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ChatPage',
        params: RouteParams.chatPage(item.bizType, item.bizId, item.peerName, item.peerId)
      });
    } catch (err) {
      // 跳转失败留在当前页
    }
  }

  /** 单条会话 */
  @Builder
  conversationRow(item: ChatConversation) {
    Row() {
      // 对方头像圈（首字）
      Row() {
        Text(item.peerName === '' ? '友' : item.peerName.substring(0, 1))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.primary)
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.primaryLight)

      Column() {
        Row() {
          Text(item.bizTitle)
            .fontSize(AppTheme.fontBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(DateFmt.mdhm(item.lastTime))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textHint)
            .margin({ left: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Text(item.peerName + '：' + item.lastContent)
            .fontSize(AppTheme.fontSecondary)
            .fontColor(AppTheme.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (item.unread > 0) {
            Text(item.unread.toString())
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
      .margin({ left: 11 })
    }
    .width('100%')
    .padding(12)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadius)
    .onClick(() => {
      this.openChat(item);
    })
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingOverlay({ text: $r('app.string.common_loading') })
      } else {
        PageHeader({
          title: $r('app.string.chat_list_title'),
          onBack: () => {
            this.back();
          }
        })

        Scroll() {
          Column() {
            if (this.list.length === 0) {
              Column() {
                EmptyState({
                  title: $r('app.string.chat_list_empty'),
                  showSubtitle: false
                })
              }
              .margin({ top: 40 })
            } else {
              ForEach(this.list, (item: ChatConversation) => {
                Column() {
                  this.conversationRow(item)
                }
                .width('100%')
                .margin({ top: 10 })
              }, (item: ChatConversation) => item.bizType + '-' + item.bizId.toString() + '#' + item.unread.toString() + '#' + this.tick.toString())
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground)
  }
}
