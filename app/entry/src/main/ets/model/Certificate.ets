/**
 * Certificate —— 电子证书（对应接口 GET /api/user/certificate）
 * 由「我的 → 时长明细 → 生成证书」触发，前端负责把它渲染成可截图/分享的证书图。
 */
export class Certificate {
  userName: string = '';
  studentNo: string = '';
  college: string = '';
  major: string = '';
  /** 累计志愿时长（小时） */
  totalHours: number = 0;
  /** 参与活动场次 */
  activityCount: number = 0;
  /** 证书编号，如 HZY-2026-0001 */
  serialNo: string = '';
  /** 颁发机构 */
  issueOrg: string = '';
  /** 颁发日期 yyyy-MM-dd */
  issueDate: string = '';

  static fromJson(json: Certificate): Certificate {
    const item: Certificate = new Certificate();
    item.userName = json.userName ?? '';
    item.studentNo = json.studentNo ?? '';
    item.college = json.college ?? '';
    item.major = json.major ?? '';
    item.totalHours = json.totalHours ?? 0;
    item.activityCount = json.activityCount ?? 0;
    item.serialNo = json.serialNo ?? '';
    item.issueOrg = json.issueOrg ?? '';
    item.issueDate = json.issueDate ?? '';
    return item;
  }
}
