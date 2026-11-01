/**
 * User —— 用户（对应表 sys_user）
 * ⚠️ password 字段故意不在此模型里：后端绝不向前端返回密码。
 */
export class User {
  id: number = 0;
  /** 学号（登录账号） */
  studentNo: string = '';
  name: string = '';
  phone: string = '';
  college: string = '';
  major: string = '';
  /** 技能标签，逗号分隔，如 "摄影,文案,急救" */
  skillTags: string = '';
  avatar: string = '';
  /** 志愿信用分 */
  creditScore: number = 0;
  /** 公益积分（互助货币） */
  point: number = 0;
  /** 累计志愿时长（小时） */
  totalHours: number = 0;
  lat: number = 0;
  lng: number = 0;
  createTime: string = '';

  static fromJson(json: User): User {
    const item: User = new User();
    item.id = json.id ?? 0;
    item.studentNo = json.studentNo ?? '';
    item.name = json.name ?? '';
    item.phone = json.phone ?? '';
    item.college = json.college ?? '';
    item.major = json.major ?? '';
    item.skillTags = json.skillTags ?? '';
    item.avatar = json.avatar ?? '';
    item.creditScore = json.creditScore ?? 0;
    item.point = json.point ?? 0;
    item.totalHours = json.totalHours ?? 0;
    item.lat = json.lat ?? 0;
    item.lng = json.lng ?? 0;
    item.createTime = json.createTime ?? '';
    return item;
  }

  static fromJsonList(list: User[]): User[] {
    const out: User[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(User.fromJson(list[i]));
    }
    return out;
  }

  /** 技能标签数组（标签展示用） */
  skillTagList(): string[] {
    if (this.skillTags === '') {
      return [];
    }
    return this.skillTags.split(',');
  }

  /** 姓名首字，用作无头像时的占位 */
  nameInitial(): string {
    if (this.name === '') {
      return '?';
    }
    return this.name.substring(0, 1);
  }
}
