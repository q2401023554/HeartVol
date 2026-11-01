import { ApiPath, ApiReady, MessageType, USE_MOCK } from '../common/Constants';
import { HttpUtil } from '../common/HttpUtil';
import { TokenStore } from '../common/TokenStore';
import { Result } from '../model/Result';
import { AuthService } from './AuthService';
import { User } from '../model/User';
import { MessageItem, MessagePage, UnreadCount } from '../model/MessageItem';
import { Signup } from '../model/Signup';
import { HourRecord } from '../model/HourRecord';
import { Certificate } from '../model/Certificate';
import { MockData } from '../model/MockData';

/**
 * MineService —— 「我的」Tab 与四个二级页的数据入口（Mock / Real 双轨，D4）
 *
 * 【契约同 HomeService / VolunteerService / HelpService】
 *   · 页面只认识本层的 `Promise` 签名，不认识 `MockData`
 *   · 逐模块开关：`USE_MOCK` 是总闸，`ApiReady.MINE` 是分闸
 *
 * 【D4 接入范围】profile / signups / hours（后端 B5 已交付）；
 *   messages / unread 属消息中心（D5），certificate 后端无接口（D7 标注残留）。
 *
 * 【口径】
 *   · `messages(type)`：type 传空串返回全部，否则按 MessageType 码值过滤
 *   · `unread(type)`：某类型的未读数（消息中心 Tab 角标）；type 为空串是全部未读
 *   · `creditedHours(activityId)`：某活动已入账的志愿时长；没有记录返回 -1
 */
export class MineService {

  /** 本模块是否走真实接口：`USE_MOCK` 总闸 + `ApiReady.MINE` 分闸 */
  private static useReal(): boolean {
    return !USE_MOCK || ApiReady.MINE;
  }

  /** 消息模块是否走真实接口：`USE_MOCK` 总闸 + `ApiReady.MESSAGE` 分闸 */
  private static useRealMsg(): boolean {
    return !USE_MOCK || ApiReady.MESSAGE;
  }

  /** 当前登录用户（「我的」资料行 + 深色数据卡） */
  static async profile(): Promise<User> {
    if (!MineService.useReal()) {
      return MockData.currentUser();
    }
    // 走 /api/user/me（AuthService.me 会顺手刷新落盘缓存，401 已自动清登录）
    const res = await AuthService.me();
    if (res.isOk() && res.data !== null) {
      return res.data;
    }
    // 网络失败兜底：用登录时落盘的用户；最差给空壳，页面不至于崩
    const cached: User | null = TokenStore.currentUser();
    if (cached !== null) {
      return cached;
    }
    return new User();
  }

  /** 消息列表（type 为空串 = 全部）—— 真实走 /api/user/messages?type=&page=&size= */
  static async messages(type: string): Promise<MessageItem[]> {
    if (!MineService.useRealMsg()) {
      if (type === '') {
        return MockData.messages();
      }
      return MockData.messagesByType(type);
    }
    try {
      let q: string = ApiPath.MESSAGES + '?page=1&size=50';
      if (type !== '') {
        q = q + '&type=' + type;
      }
      const res: Result<MessagePage> = await HttpUtil.getWithRetry<MessagePage>(q);
      if (!res.isOk() || res.data === null) {
        return [];
      }
      return MessageItem.fromJsonList(res.data.list);
    } catch (err) {
      return [];
    }
  }

  /** 未读数（type 为空串 = 全部未读）—— 真实走 /api/user/messages/unread */
  static async unread(type: string): Promise<number> {
    if (!MineService.useRealMsg()) {
      const list: MessageItem[] = type === '' ? MockData.messages() : MockData.messagesByType(type);
      return MessageItem.countUnread(list);
    }
    try {
      const res: Result<UnreadCount> = await HttpUtil.getWithRetry<UnreadCount>(ApiPath.MESSAGES_UNREAD);
      if (!res.isOk() || res.data === null) {
        return 0;
      }
      if (type === '') {
        return res.data.total;
      }
      if (type === MessageType.NOTICE) {
        return res.data.notice;
      }
      if (type === MessageType.INTERACT) {
        return res.data.interact;
      }
      if (type === MessageType.ACTIVITY) {
        return res.data.activity;
      }
      if (type === MessageType.HELP) {
        return res.data.help;
      }
      return 0;
    } catch (err) {
      return 0;
    }
  }

  /** 全部已读（type 可空=全部）—— 真实走 POST /api/user/messages/read-all */
  static async markAllRead(type: string): Promise<boolean> {
    if (!MineService.useRealMsg()) {
      return true;
    }
    try {
      let q: string = ApiPath.MESSAGES_READ_ALL;
      if (type !== '') {
        q = q + '?type=' + type;
      }
      const res: Result<object> = await HttpUtil.post<object>(q, null);
      return res.isOk();
    } catch (err) {
      return false;
    }
  }

  /** 单条已读 —— 真实走 POST /api/user/messages/{id}/read */
  static async markRead(id: number): Promise<boolean> {
    if (!MineService.useRealMsg()) {
      return true;
    }
    try {
      const res: Result<object> = await HttpUtil.post<object>(ApiPath.messageRead(id), null);
      return res.isOk();
    } catch (err) {
      return false;
    }
  }

  /** 我的报名（联表带活动详情） */
  static async signups(): Promise<Signup[]> {
    if (!MineService.useReal()) {
      return MockData.mySignups();
    }
    try {
      const res: Result<Signup[]> = await HttpUtil.getWithRetry<Signup[]>(ApiPath.USER_SIGNUPS);
      if (!res.isOk() || res.data === null) {
        return [];
      }
      return Signup.fromJsonList(res.data);
    } catch (err) {
      return [];
    }
  }

  /** 志愿时长明细 */
  static async hours(): Promise<HourRecord[]> {
    if (!MineService.useReal()) {
      return MockData.hourRecords();
    }
    try {
      const res: Result<HourRecord[]> = await HttpUtil.getWithRetry<HourRecord[]>(ApiPath.USER_HOURS);
      if (!res.isOk() || res.data === null) {
        return [];
      }
      return HourRecord.fromJsonList(res.data);
    } catch (err) {
      return [];
    }
  }

  /** 某活动已入账的时长；没有入账记录返回 -1 */
  static async creditedHours(activityId: number): Promise<number> {
    if (!MineService.useReal()) {
      const list: HourRecord[] = MockData.hourRecords();
      for (let i = 0; i < list.length; i++) {
        if (list[i].activityId === activityId) {
          return list[i].hours;
        }
      }
      return -1;
    }
    try {
      const list: HourRecord[] = await MineService.hours();
      for (let i = 0; i < list.length; i++) {
        if (list[i].activityId === activityId) {
          return list[i].hours;
        }
      }
      return -1;
    } catch (err) {
      return -1;
    }
  }

  /** 电子证书数据 —— 后端无接口（ApiReady.CERTIFICATE=false），D7 收口时继续走 Mock 兜底 */
  static async certificate(): Promise<Certificate> {
    if (!USE_MOCK && ApiReady.CERTIFICATE) {
      // 云同步：后端按登录用户实时聚合（资料/累计时长/完成场次/证书编号）
      try {
        const res: Result<Certificate> =
          await HttpUtil.getWithRetry<Certificate>(ApiPath.USER_CERTIFICATE);
        if (res.isOk() && res.data !== null) {
          return Certificate.fromJson(res.data as Certificate);
        }
      } catch (err) {
        // 网络失败走下方 Mock 兜底
      }
    }
    const cert: Certificate = MockData.certificate();
    // Mock 兜底的姓名跟当前登录用户走 —— 避免设置页改名后证书页还显示旧名
    const u: User | null = TokenStore.currentUser();
    if (u !== null && u.name !== '') {
      cert.userName = u.name;
    }
    return cert;
  }
}
