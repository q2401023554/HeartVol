/**
 * FormStore —— 桌面卡片数据快照（Form Kit）
 *
 * 【为什么走快照而不是卡片进程发请求】
 *   FormExtensionAbility 运行在独立进程，没有登录态（token 在主进程的
 *   TokenStore 内存里），直接发请求要重新搭一套鉴权读取逻辑，还容易因为
 *   进程上下文差异踩坑。所以定稿：主进程每次成功拉取 home-summary 时，
 *   把卡片要展示的关键数字写进 preferences；卡片刷新（onAddForm /
 *   onUpdateForm）时由 FormExtensionAbility 读同一份 preferences。
 *   App 不在前台时卡片显示最近一次快照 —— 对桌面速览场景完全够用。
 *
 * 【存的是什么】
 *   存 FormSnapshot（纯字符串字段，无方法）的 JSON 串 —— 卡片进程
 *   JSON.parse 后逐字段赋回 FormSnapshot，保证 ArkTS「对象字面量必须有
 *   显式类」与「parse 结果没方法」两条硬约束都绕开。
 */
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { HomeSummary } from '../model/HomeSummary';
import { TokenStore, CTX_KEY } from './TokenStore';
import { DateFmt } from './DateFmt';

/** 与 TokenStore 共用同一份 preferences 文件，主进程写、卡片进程读 */
const PREF_NAME: string = 'hongzhiyuan';
const KEY_SNAPSHOT: string = 'form_snapshot_json';

/** 卡片展示快照（全部转成字符串，卡片 @LocalStorageProp 直接绑定） */
export class FormSnapshot {
  userName: string = '志愿者';
  todayHours: string = '--';
  totalHours: string = '--';
  ongoingCount: string = '0';
  pendingCount: string = '0';
  nextTitle: string = '暂无待办活动';
  nextTime: string = '';

  static empty(): FormSnapshot {
    return new FormSnapshot();
  }

  /** 由首页聚合结果组装（主进程调用，此时 TokenStore 里有用户） */
  static fromSummary(s: HomeSummary): FormSnapshot {
    const f: FormSnapshot = new FormSnapshot();
    const u = TokenStore.currentUser();
    if (u !== null && u.name !== '') {
      f.userName = u.name;
    }
    f.todayHours = s.todayHours.toString();
    f.totalHours = s.totalHours.toString();
    f.ongoingCount = s.ongoingCount.toString();
    f.pendingCount = s.pendingSigninCount.toString();
    if (s.nextActivityTitle !== '') {
      f.nextTitle = s.nextActivityTitle;
      const t: string = s.nextActivityStartTime;
      f.nextTime = t === '' ? '' : DateFmt.md(t) + ' ' + DateFmt.hm(t);
    }
    return f;
  }

  /** JSON 文本 → 快照（卡片进程调用；逐字段赋值，不依赖 parse 出来的对象） */
  static fromJsonText(text: string): FormSnapshot {
    const f: FormSnapshot = new FormSnapshot();
    try {
      const obj = JSON.parse(text) as FormSnapshot;
      f.userName = obj.userName ?? '志愿者';
      f.todayHours = obj.todayHours ?? '--';
      f.totalHours = obj.totalHours ?? '--';
      f.ongoingCount = obj.ongoingCount ?? '0';
      f.pendingCount = obj.pendingCount ?? '0';
      f.nextTitle = obj.nextTitle ?? '暂无待办活动';
      f.nextTime = obj.nextTime ?? '';
    } catch (err) {
      // 解析失败按空快照处理
    }
    return f;
  }
}

export class FormStore {
  /** 主进程：首页聚合成功后写入快照（失败静默，不影响主流程） */
  static async save(s: HomeSummary): Promise<void> {
    try {
      const ctx: common.Context | undefined = AppStorage.get<common.Context>(CTX_KEY);
      if (ctx === undefined) {
        return;
      }
      const store: preferences.Preferences = await preferences.getPreferences(ctx, PREF_NAME);
      await store.put(KEY_SNAPSHOT, JSON.stringify(FormSnapshot.fromSummary(s)));
      await store.flush();
    } catch (err) {
      // 快照写失败只影响卡片新鲜度
    }
  }

  /** 登出时清快照，卡片回落到默认文案 */
  static async clear(): Promise<void> {
    try {
      const ctx: common.Context | undefined = AppStorage.get<common.Context>(CTX_KEY);
      if (ctx === undefined) {
        return;
      }
      const store: preferences.Preferences = await preferences.getPreferences(ctx, PREF_NAME);
      await store.delete(KEY_SNAPSHOT);
      await store.flush();
    } catch (err) {
      // 忽略
    }
  }

  /** 卡片进程：FormExtensionAbility 用自己的 context 读快照 */
  static async load(context: common.Context): Promise<FormSnapshot> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREF_NAME);
      const text: string = await store.get(KEY_SNAPSHOT, '') as string;
      if (text === '') {
        return FormSnapshot.empty();
      }
      return FormSnapshot.fromJsonText(text);
    } catch (err) {
      return FormSnapshot.empty();
    }
  }
}
