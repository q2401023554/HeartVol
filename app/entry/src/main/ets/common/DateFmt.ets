/**
 * DateFmt —— 时间字符串格式化
 *
 * 后端时间统一是 'yyyy-MM-dd HH:mm:ss'。这里用**字符串切片**而不是 new Date()：
 *   ① 不用管时区 / 夏令时，切出来就是服务器给的字面值；
 *   ② 'yyyy-MM-dd'（没有时分秒）这种短格式也不会解析失败；
 *   ③ 没有对象分配，列表里几百条一起格式化也不心疼。
 *
 * 时间永远只负责"显示"，排序 / 比较请交给后端或字符串比较（同格式字符串比较等价于时间比较）。
 */
export class DateFmt {

  /** '2026-09-24 08:30:00' → '2026-09-24' */
  static ymd(t: string): string {
    if (t.length < 10) {
      return t;
    }
    return t.substring(0, 10);
  }

  /** → '09-24' */
  static md(t: string): string {
    if (t.length < 10) {
      return t;
    }
    return t.substring(5, 10);
  }

  /** → '08:30' */
  static hm(t: string): string {
    if (t.length < 16) {
      return '';
    }
    return t.substring(11, 16);
  }

  /** → '09-24 08:30' */
  static mdhm(t: string): string {
    if (t.length < 16) {
      return DateFmt.md(t);
    }
    return t.substring(5, 10) + ' ' + t.substring(11, 16);
  }

  /** 起止时间 → '09-24 08:30 ~ 11:30' */
  static range(start: string, end: string): string {
    return DateFmt.mdhm(start) + ' ~ ' + DateFmt.hm(end);
  }

  // ==================== 相对日 / 星期 ====================
  //
  // 【为什么不用 new Date(t) 解析后端时间】
  //   'yyyy-MM-dd HH:mm:ss' 在部分运行时里会被当成本地时间、部分当成 UTC，
  //   差 8 小时就能把「明天」算成「今天」。这里改用**纯整数历法**：
  //   把 y/m/d 从字符串切出来，用 Howard Hinnant 的 days_from_civil 换算成天序号，
  //   全程整数运算，不碰时区，结果与设备时区无关。
  //
  // 【唯一一次 new Date()】只是为了拿「今天」是几号（第 4 行 getTodayNo）。
  //   这是取当前日期，不是解析后端字符串，没有时区歧义。

  /** yyyy-MM-dd 的**天序号**（1970-01-01 = 0）。同一天的任意时刻天序号相同。 */
  private static dayNo(y: number, m: number, d: number): number {
    const yy: number = m <= 2 ? y - 1 : y;
    const era: number = Math.floor(yy / 400);
    const yoe: number = yy - era * 400;
    const mp: number = m > 2 ? m - 3 : m + 9;
    const doy: number = Math.floor((153 * mp + 2) / 5) + d - 1;
    const doe: number = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
    return era * 146097 + doe - 719468;
  }

  /** 从 'yyyy-MM-dd ...' 取天序号；字符串不合法返回 NaN */
  private static dayNoOf(t: string): number {
    if (t.length < 10) {
      return Number.NaN;
    }
    const y: number = parseInt(t.substring(0, 4));
    const m: number = parseInt(t.substring(5, 7));
    const d: number = parseInt(t.substring(8, 10));
    return DateFmt.dayNo(y, m, d);
  }

  /** 今天的天序号 */
  private static getTodayNo(): number {
    const now: Date = new Date();
    return DateFmt.dayNo(now.getFullYear(), now.getMonth() + 1, now.getDate());
  }

  /**
   * 星期几：'2026-09-27 14:00:00' → '周日'
   * 与今天的距离超过 6 天也照常返回星期（调用方自己决定要不要用）。
   */
  static weekday(t: string): string {
    const no: number = DateFmt.dayNoOf(t);
    if (Number.isNaN(no)) {
      return '';
    }
    // 1970-01-01 是周四 → 天序号 0 对应周四，偏移 4 后 0=周日
    const idx: number = ((no + 4) % 7 + 7) % 7;
    if (idx === 0) {
      return '周日';
    }
    if (idx === 1) {
      return '周一';
    }
    if (idx === 2) {
      return '周二';
    }
    if (idx === 3) {
      return '周三';
    }
    if (idx === 4) {
      return '周四';
    }
    if (idx === 5) {
      return '周五';
    }
    return '周六';
  }

  /**
   * 日期的人话标签：-1/0/1/2 天 → '昨天'/'今天'/'明天'/'后天'；
   * 3~6 天内 → 星期（'周六'）；更远或已过去更久 → 空串（调用方回落到 'mm-dd'）。
   */
  static dayLabel(t: string): string {
    const no: number = DateFmt.dayNoOf(t);
    if (Number.isNaN(no)) {
      return '';
    }
    const diff: number = no - DateFmt.getTodayNo();
    if (diff === -1) {
      return '昨天';
    }
    if (diff === 0) {
      return '今天';
    }
    if (diff === 1) {
      return '明天';
    }
    if (diff === 2) {
      return '后天';
    }
    if (diff > 2 && diff <= 6) {
      return DateFmt.weekday(t);
    }
    return '';
  }

  /**
   * 「人话 + 时刻」，列表里显示活动时间用：
   *   '2026-09-25 07:00:00' → '后天 07:00'
   *   '2026-09-27 14:00:00' → '周日 14:00'
   *   '2026-11-01 09:00:00' → '11-01 09:00'
   */
  static dayHm(t: string): string {
    const label: string = DateFmt.dayLabel(t);
    const hm: string = DateFmt.hm(t);
    if (label === '') {
      return DateFmt.md(t) + ' ' + hm;
    }
    return label + ' ' + hm;
  }

  /** 今天 → '09-23 周三'（首页「本周推荐」右侧的日期锚点） */
  static todayMdWeek(): string {
    const now: Date = new Date();
    const y: number = now.getFullYear();
    const m: number = now.getMonth() + 1;
    const d: number = now.getDate();
    const mm: string = m < 10 ? '0' + m.toString() : m.toString();
    const dd: string = d < 10 ? '0' + d.toString() : d.toString();
    const stamp: string = y.toString() + '-' + mm + '-' + dd + ' 00:00:00';
    return mm + '-' + dd + ' ' + DateFmt.weekday(stamp);
  }

  /**
   * 当前时刻 → '09-26 14:02'（签到成功态的「签到时间」）。
   * 取当前系统时刻**格式化输出**（不是解析字符串），没有时区歧义；
   * 时/分补零后手工拼接，不用 toISOString（那是 UTC，会差 8 小时）。
   */
  static nowMdHm(): string {
    const now: Date = new Date();
    const p = (n: number): string => {
      return n < 10 ? '0' + n.toString() : n.toString();
    };
    return p(now.getMonth() + 1) + '-' + p(now.getDate()) + ' ' + p(now.getHours()) + ':' + p(now.getMinutes());
  }
}
