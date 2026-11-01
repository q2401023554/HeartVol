/**
 * Constants —— 全局配置与业务枚举
 *
 * 🔴 D 阶段（前后端对接）只需要动两个地方：
 *    1. USE_MOCK  → false
 *    2. BASE_URL  → 服务器公网 IP
 *   其余代码零改动。
 */

// ==================== 一、运行配置 ====================

/**
 * 后端根地址。本地调试指向本机 Spring Boot 服务；部署后改成实际服务器地址。
 * ⚠️ 换服务器只改这一行；明文 HTTP 需在 module.json5 开 cleartextTraffic（已开）。
 */
export const BASE_URL: string = 'http://192.168.1.100:8080';

/** Mock 总开关：U 阶段 true（全部走本地假数据，不碰网络）；D 阶段改 false 即切真实接口 */
export const USE_MOCK: boolean = false;

/** 网络超时 15s（智能体接口较慢，用这个值兜底） */
export const HTTP_TIMEOUT_MS: number = 20000;

/** 默认分页大小 */
export const DEFAULT_PAGE_SIZE: number = 10;

/** 签到码长度（6 位数字） */
export const SIGNIN_CODE_LENGTH: number = 6;

/** 地理围栏默认半径（米），活动未单独配置时使用 */
export const DEFAULT_SIGNIN_RADIUS: number = 200;

// ==================== 二、接口路径 ====================
// 统一返回体：{ code, message, data }

export class ApiPath {
  // ---- 认证 / 用户 ----
  static readonly AUTH_REGISTER: string = '/api/auth/register';
  static readonly AUTH_LOGIN: string = '/api/auth/login';
  static readonly USER_ME: string = '/api/user/me';
  /** 我的报名（后端实现为 /api/user/signups） */
  static readonly USER_SIGNUPS: string = '/api/user/signups';
  static readonly USER_HOURS: string = '/api/user/hours';
  // 以下四个后端 B 阶段未实现 → 对应页面在 D 阶段仍走 Mock（D7 会标注残留）
  static readonly USER_PROFILE: string = '/api/user/profile';
  static readonly USER_CERTIFICATE: string = '/api/user/certificate';
  static readonly USER_POINTS: string = '/api/user/points';
  static readonly USER_HOME_SUMMARY: string = '/api/user/home-summary';

  // ---- 志愿 ----
  static readonly ACTIVITIES: string = '/api/activities';

  // ---- 互助 ----
  static readonly HELPS: string = '/api/helps';

  // ---- 消息（后端挂在 /api/user 下） ----
  static readonly MESSAGES: string = '/api/user/messages';
  static readonly MESSAGES_UNREAD: string = '/api/user/messages/unread';
  static readonly MESSAGES_READ_ALL: string = '/api/user/messages/read-all';

  // ---- 智能体（G：/api/agent；⚠️ /api/chat 已被简化版 IM 占用） ----
  static readonly AGENT_CHAT: string = '/api/agent/chat';
  static readonly AGENT_HISTORY: string = '/api/agent/history';
  static readonly AGENT_CLEAR: string = '/api/agent/clear';
  static readonly HEALTH: string = '/api/health';
  static readonly UPLOAD: string = '/api/upload';

  // ---- 带路径参数的拼接方法（ArkTS 不支持模板字符串以外的花活，用显式方法最稳） ----
  static activityDetail(id: number): string {
    return '/api/activities/' + id;
  }

  static activityDelete(id: number): string {
    return '/api/activities/' + id + '/delete';
  }

  static activityUpdate(id: number): string {
    return '/api/activities/' + id + '/update';
  }

  static activitySignup(id: number): string {
    return '/api/activities/' + id + '/signup';
  }

  static activitySignin(id: number): string {
    return '/api/activities/' + id + '/signin';
  }

  static helpDetail(id: number): string {
    return '/api/helps/' + id;
  }

  static helpAccept(id: number): string {
    return '/api/helps/' + id + '/accept';
  }

  static helpFinish(id: number): string {
    return '/api/helps/' + id + '/finish';
  }

  /** 互评：后端按**接单 id** 评价（/api/helps/orders/{orderId}/review） */
  static helpReview(orderId: number): string {
    return '/api/helps/orders/' + orderId + '/review';
  }

  static messageRead(id: number): string {
    return '/api/user/messages/' + id + '/read';
  }

  // ---- 互助/活动沟通（简化版 IM，前端 2s 轮询；⚠️ G 阶段智能体接口改走 /api/agent，勿与 /api/chat 混用） ----
  // bizType：help = 发布者↔接单者；activity = 任意用户↔活动发布者（咨询）
  static readonly CHAT_CONVERSATIONS: string = '/api/chat/list';

  static chatMessages(bizType: string, bizId: number, peerUid: number, afterId: number): string {
    return '/api/chat/' + bizType + '/' + bizId + '/messages?afterId=' + afterId + '&peerUid=' + peerUid;
  }

  static chatSend(bizType: string, bizId: number): string {
    return '/api/chat/' + bizType + '/' + bizId + '/send';
  }
}

// ==================== 二·补、请求方法 ====================
// ArkTS 里 http.RequestMethod 是枚举，Service 层直接用它；这里给一个语义化别名便于阅读。

/** 后端已实现的接口清单（B 阶段交付，D 阶段逐条对接） */
export class ApiReady {
  static readonly AUTH: boolean = true;
  static readonly ACTIVITY: boolean = true;
  static readonly SIGNUP_SIGNIN: boolean = true;
  static readonly HELP: boolean = true;
  static readonly MESSAGE: boolean = true;
  /** D4：「我的」域（profile / 报名 / 时长明细）后端已就绪 */
  static readonly MINE: boolean = true;
  /** D3：首页聚合接口已在后端补齐（含 featured + feed） */
  static readonly HOME_SUMMARY: boolean = true;
  /** 以下后端尚未实现 → 对应页面继续走 Mock，不强行切 */
  static readonly VOLUNTEER_STATS: boolean = false;
  static readonly CERTIFICATE: boolean = true;
  static readonly POINTS: boolean = false;
  /** 简化版 IM（互助沟通）后端已就绪：/api/chat/list + messages + send（2s 轮询） */
  static readonly CHAT: boolean = true;
  /** G 已实现：/api/agent/chat 走服务端代理 DeepSeek（多轮上下文存 chat_message 表）；对话请求用 60s 长超时 */
  static readonly AGENT: boolean = true;
}

// ==================== 三、业务枚举 ====================
// ⚠️ 数据库与接口一律存英文码，中文文案由前端经 string.json 映射（符合 R-2）。
//    好处：避免中文字面量散落在代码里比较，也让将来国际化不用改后端。

/** 活动状态 */
export enum ActivityStatus {
  /** 报名中 */
  SIGNUPING = 'signuping',
  /** 进行中 */
  ONGOING = 'ongoing',
  /** 已结束 */
  FINISHED = 'finished'
}

/** 报名状态 */
export enum SignupStatus {
  /** 已报名 */
  SIGNED_UP = 'signed_up',
  /** 已签到 */
  CHECKED_IN = 'checked_in',
  /** 已完成 */
  COMPLETED = 'completed',
  /** 爽约 */
  NO_SHOW = 'no_show'
}

/** 签到方式 */
export enum SignType {
  /** 扫码 */
  SCAN = 'scan',
  /** 地理围栏 */
  GEO = 'geo',
  /** 手输签到码 */
  MANUAL = 'manual'
}

/** 求助状态 */
export enum HelpStatus {
  /** 待接单 */
  PENDING = 'pending',
  /** 进行中 */
  ONGOING = 'ongoing',
  /** 已完成 */
  FINISHED = 'finished',
  /** 已取消 */
  CANCELED = 'canceled'
}

/** 接单状态 */
export enum HelpOrderStatus {
  /** 进行中 */
  ONGOING = 'ongoing',
  /** 待确认（接单人已提交，等发布者确认完成） */
  WAIT_CONFIRM = 'wait_confirm',
  /** 已完成 */
  FINISHED = 'finished'
}

/** 消息类型（决定消息中心分 Tab） */
export enum MessageType {
  /** 通知 */
  NOTICE = 'notice',
  /** 互动 */
  INTERACT = 'interact',
  /** 活动 */
  ACTIVITY = 'activity',
  /** 互助 */
  HELP = 'help'
}

/** 志愿活动分类 */
export enum ActivityCategory {
  /** 环保 */
  ENV = 'env',
  /** 支教 */
  TEACH = 'teach',
  /** 赛会 */
  GAME = 'game',
  /** 助老 */
  ELDER = 'elder',
  /** 校园服务 */
  CAMPUS = 'campus'
}

/** 互助分类 */
export enum HelpCategory {
  /** 跑腿 */
  ERRAND = 'errand',
  /** 借物 */
  BORROW = 'borrow',
  /** 问答 */
  QA = 'qa',
  /** 技能 */
  SKILL = 'skill',
  /** 搬运 */
  CARRY = 'carry'
}

/** 智能体回复卡片的类型 */
export enum ChatCardType {
  /** 活动草稿 / 推荐活动卡 */
  ACTIVITY = 'activity',
  /** 求助草稿 / 推荐求助卡 */
  HELP = 'help',
  /** 纯文本（无卡片） */
  TEXT = 'text'
}

// ==================== 四、统一返回码 ====================

export class ResultCode {
  static readonly OK: number = 200;
  /** 未登录 / token 过期 → 前端跳登录页 */
  static readonly UNAUTHORIZED: number = 401;
  /** 业务异常（如名额已满、签到码错误） */
  static readonly BIZ_ERROR: number = 500;
}
