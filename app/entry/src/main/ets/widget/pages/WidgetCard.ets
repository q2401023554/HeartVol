/**
 * WidgetCard —— 鸿志愿 2*4 桌面卡片（Form Kit ArkTS 卡片）
 *
 * 版式（720 设计宽度画布）：
 *   顶部：品牌「鸿志愿」+ 用户名问候
 *   中部：今日时长 / 累计时长 两列数字
 *   底部：进行中·待签到 摘要 + 下一场活动
 * 整卡可点：postCardAction 拉起 EntryAbility 进首页。
 *
 * 真机校准记录：首版数字 56/品牌 28 在 2*4 实际高度下垂直溢出（底部被裁），
 * 已整体收缩到 数字 34/品牌 22，留 Blank 弹性空间。
 * 数据来自 FormBindingData（EntryFormAbility 推快照），@LocalStorageProp 绑定。
 */
import { appMark } from '../../common/AppIcon';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct WidgetCard {
  @LocalStorageProp('userName') userName: string = '志愿者';
  @LocalStorageProp('todayHours') todayHours: string = '--';
  @LocalStorageProp('totalHours') totalHours: string = '--';
  @LocalStorageProp('ongoingCount') ongoingCount: string = '0';
  @LocalStorageProp('pendingCount') pendingCount: string = '0';
  @LocalStorageProp('nextTitle') nextTitle: string = '暂无待办活动';
  @LocalStorageProp('nextTime') nextTime: string = '';

  build() {
    Column() {
      // ① 品牌 + 用户名（品牌行带同款应用标识，与启动页/登录页同一出处 appMark）
      Row() {
        appMark(20, 6, 11)
        Text('鸿志愿')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary'))
          .margin({ left: 6 })
        Blank()
        Text('Hi, ' + this.userName)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // ② 今日 / 累计 双列数字
      Row() {
        Column() {
          Row() {
            Text(this.todayHours)
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text(' 小时')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 3, bottom: 5 })
          }
          .alignItems(VerticalAlign.Bottom)

          Text('今日志愿时长')
            .fontSize(13)
            .fontColor($r('app.color.text_hint'))
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row()
          .width(1)
          .height(44)
          .backgroundColor($r('app.color.divider'))
          .margin({ left: 14, right: 14 })

        Column() {
          Row() {
            Text(this.totalHours)
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text(' 小时')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 3, bottom: 5 })
          }
          .alignItems(VerticalAlign.Bottom)

          Text('累计志愿时长')
            .fontSize(13)
            .fontColor($r('app.color.text_hint'))
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 16 })

      Blank()

      // ③ 待办摘要 + 下一场
      Column() {
        Text('进行中 ' + this.ongoingCount + ' 场 · 待签到 ' + this.pendingCount + ' 场')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))

        if (this.nextTitle !== '' && this.nextTitle !== '暂无待办活动') {
          Row() {
            Text('下一场')
              .fontSize(13)
              .fontColor($r('app.color.primary'))
              .margin({ right: 6 })
            Text(this.nextTitle)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (this.nextTime !== '') {
              Text(this.nextTime)
                .fontSize(13)
                .fontColor($r('app.color.text_hint'))
                .margin({ left: 6 })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ top: 6 })
        }
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(28)
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(28)
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': {}
      });
    })
  }
}
