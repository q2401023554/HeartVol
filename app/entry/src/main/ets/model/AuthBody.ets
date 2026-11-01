/**
 * 认证接口请求体（D2）
 * 🔴 ArkTS 不允许裸对象字面量当请求体（arkts-no-untyped-obj-literals），
 *   所以每个请求体都要有一个显式声明的类。
 */
export class LoginBody {
  studentNo: string = '';
  password: string = '';

  constructor(studentNo: string, password: string) {
    this.studentNo = studentNo;
    this.password = password;
  }
}

export class RegisterBody {
  studentNo: string = '';
  password: string = '';
  name: string = '';
  college: string = '';
  major: string = '';

  constructor(studentNo: string, password: string, name: string, college: string, major: string) {
    this.studentNo = studentNo;
    this.password = password;
    this.name = name;
    this.college = college;
    this.major = major;
  }
}

/** 资料修改（设置页）：姓名必填；电话/学院可空 */
export class ProfileBody {
  name: string = '';
  phone: string = '';
  college: string = '';

  constructor(name: string, phone: string, college: string) {
    this.name = name;
    this.phone = phone;
    this.college = college;
  }
}
