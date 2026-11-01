import { AppTheme } from '../common/AppTheme';
import { BizDict } from '../common/BizDict';
import { DateFmt } from '../common/DateFmt';
import { MessageItem } from '../model/MessageItem';
import { GradientIcon } from './GradientIcon';

/**
 * MessageCell —— 消息中心一条消息
 *
 * ⚠️ 命名说明：数据模型已有一个 MessageItem（model/MessageItem.ets），
 *    组件如果也叫 MessageItem，页面里同时引两个就会撞名，所以组件叫 MessageCell。
 *
 * 设计稿里消息中心是「一条消息一张白卡」，卡片样式就放在组件内部，
 * 页面只管 ForEach 摆出来 + 加间距。
 *
 * 【用法】
 *   MessageCell({ message: item, onTap: (id: number) => { this.markRead(id) } })
 */
@Component
export struct MessageCell {
  message: MessageItem = new MessageItem();
  onTap: (id: number) => void = (id: number) => {
  };

  build() {
    Row() {
      GradientIcon({
        path: BizDict.msgIcon(this.message.type),
        tone: BizDict.msgTone(this.message.type),
        boxSize: 40,
        glyphSize: 21,
        radius: 12
      })

      Column() {
        Row() {
          Text(this.message.title)
            .fontSize(AppTheme.fontTitleCard)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(DateFmt.mdhm(this.message.createTime))
            .fontSize(AppTheme.fontCaption)
            .fontColor(AppTheme.textHint)
            .margin({ left: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.message.content)
          .fontSize(AppTheme.fontSecondary)
          .fontColor(AppTheme.textSecondary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      if (!this.message.isRead) {
        Row()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(AppTheme.badgeRed)
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 14, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.cardRadiusSmall)
    .onClick(() => {
      this.onTap(this.message.id);
    })
  }
}
