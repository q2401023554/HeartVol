/**
 * RouteParams —— 页面间传参的「契约」
 *
 * 【为什么要单独一个文件】
 *   `router.pushUrl` 的 `params` 字段类型是 `Object`（不是泛型），
 *   而 ArkTS **不允许拿对象字面量去初始化 `Object`**（会报"需显式声明 class/interface"）。
 *   所以每个需要传参的页面都在这里声明一个 interface + 一个构造方法：
 *   调用方写 `params: RouteParams.activityDetail(id)`，接收方 `getParams() as ActivityDetailParams`，
 *   两边共用同一个类型 —— 改字段名时编译器会直接把漏改的地方标红。
 *
 * 【用法】
 *   // 发送方
 *   this.getUIContext().getRouter().pushUrl({
 *     url: 'pages/ActivityDetailPage',
 *     params: RouteParams.activityDetail(item.id)
 *   });
 *   // 接收方
 *   const raw: Object = this.getUIContext().getRouter().getParams();
 *   const p: ActivityDetailParams = raw as ActivityDetailParams;
 *   const id: number = p.activityId ?? 0;
 */

/** 活动详情页入参 */
export interface ActivityDetailParams {
  activityId: number;
}

/** 求助详情页入参 */
export interface HelpDetailParams {
  helpId: number;
}

/** 聊天页入参：会话键 = (bizType, bizId)——help=求助双方；activity=用户↔活动发布者 */
export interface ChatPageParams {
  bizType: string;
  bizId: number;
  /** 对方姓名（标题栏展示；列表页进来时顺带传，省一次请求） */
  peerName: string;
  /** 对端 uid：发布者回复活动咨询时必传（同一活动多个咨询者，需定位到人）；
   *  咨询者/互助双方传 0，服务端自行算对端 */
  peerUid: number;
}

export class RouteParams {
  /** 活动详情页的入参对象 */
  static activityDetail(id: number): ActivityDetailParams {
    const params: ActivityDetailParams = { activityId: id };
    return params;
  }

  /** 求助详情页的入参对象（互助大厅 / 我的求助 / 我的接单 三处共用） */
  static helpDetail(id: number): HelpDetailParams {
    const params: HelpDetailParams = { helpId: id };
    return params;
  }

  /** 聊天页入参（求助详情「联系」/ 活动详情「联系」/ 会话列表 / 消息通知 共用） */
  static chatPage(bizType: string, bizId: number, peerName: string, peerUid: number): ChatPageParams {
    const params: ChatPageParams = { bizType: bizType, bizId: bizId, peerName: peerName, peerUid: peerUid };
    return params;
  }
}
