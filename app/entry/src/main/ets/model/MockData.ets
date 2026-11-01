import { User } from './User';
import { Activity } from './Activity';
import { Signup } from './Signup';
import { HourRecord } from './HourRecord';
import { HelpRequest } from './HelpRequest';
import { HelpOrder } from './HelpOrder';
import { HelpReview } from './HelpReview';
import { PointLog } from './PointLog';
import { MessageItem } from './MessageItem';
import { HomeSummary } from './HomeSummary';
import { Certificate } from './Certificate';
import { VolunteerStats } from './VolunteerStats';
import { ChatMessage } from './ChatMessage';
import { AgentReply } from './AgentReply';
import { ActivityStatus } from '../common/Constants';

/**
 * ============================================================
 *  MockData —— 「UI 先行」阶段的燃料（U 阶段专用）
 * ============================================================
 *  规则：
 *   1. **字段名与后端返回完全一致** —— 这样 D 阶段把 USE_MOCK 改 false 时，
 *      页面与 Service 层零改动。
 *   2. 假数据写成 JSON 文本再走 fromJson，而不是直接 new 或对象字面量。
 *      原因：① ArkTS 不允许用对象字面量初始化「带方法的类」；
 *            ② 让 Mock 与真实后端走**完全同一条**反序列化路径，
 *              D 阶段不会蹦出"Mock 能用、真实接口字段对不上"的意外。
 *   3. 每次调用重新解析，不共享可变实例 —— 避免页面之间互相污染状态。
 *
 *  D 阶段收尾（D7）时本文件可整体删除，不影响编译。
 */

// ==================== 基础数据 ====================

/** 当前登录用户（演示账号） */
const USER_JSON: string = `{
  "id": 1,
  "studentNo": "20230101",
  "name": "张明远",
  "phone": "13800000001",
  "college": "计算机科学与技术学院",
  "major": "软件工程",
  "skillTags": "摄影,文案,急救",
  "avatar": "",
  "creditScore": 92,
  "point": 180,
  "totalHours": 18.5,
  "lat": 30.5123,
  "lng": 114.4315,
  "createTime": "2026-03-01 09:00:00"
}`;

/** 其他用户（发布者 / 接单人 / 互评对象） */
const USERS_JSON: string = `[
  {"id": 2, "studentNo": "20230188", "name": "李文静", "college": "外国语学院", "major": "英语", "skillTags": "翻译,主持", "creditScore": 95, "point": 240, "totalHours": 26.0},
  {"id": 3, "studentNo": "20230322", "name": "王浩然", "college": "机械科学与工程学院", "major": "机械设计", "skillTags": "维修,搬运", "creditScore": 88, "point": 120, "totalHours": 12.0},
  {"id": 9, "studentNo": "20220045", "name": "苏晴", "college": "校青年志愿者协会", "major": "公共事业管理", "skillTags": "组织,摄影", "creditScore": 98, "point": 520, "totalHours": 64.5},
  {"id": 10, "studentNo": "20220119", "name": "陈志远", "college": "公共卫生学院", "major": "预防医学", "skillTags": "急救,健康宣讲", "creditScore": 96, "point": 410, "totalHours": 48.0},
  {"id": 11, "studentNo": "20230207", "name": "周敏", "college": "新闻与信息传播学院", "major": "广播电视学", "skillTags": "文案,剪辑", "creditScore": 90, "point": 160, "totalHours": 15.5},
  {"id": 12, "studentNo": "20220331", "name": "郑好", "college": "体育学院", "major": "运动训练", "skillTags": "赛事,裁判", "creditScore": 93, "point": 300, "totalHours": 37.0},
  {"id": 13, "studentNo": "20210456", "name": "林嘉树", "college": "环境科学与工程学院", "major": "环境工程", "skillTags": "环保,调研", "creditScore": 97, "point": 460, "totalHours": 56.5}
]`;

// ==================== 志愿活动（12 条） ====================

const ACTIVITIES_JSON: string = `[
  {"id": 101, "title": "东湖绿道环保清理行动", "category": "env", "cover": "",
   "description": "沿东湖绿道一期清理路面与湖岸垃圾，分组作业，工具由主办方提供。请穿运动鞋并自备饮用水。",
   "address": "武汉市武昌区东湖绿道一期入口", "lat": 30.5512, "lng": 114.3985,
   "startTime": "2026-09-26 08:30:00", "endTime": "2026-09-26 10:30:00",
   "needCount": 30, "joinedCount": 18, "serviceHours": 2, "signinCode": "648213", "signinRadius": 200,
   "status": "signuping", "publisherId": 9, "createTime": "2026-09-20 14:20:00",
   "distance": 1.2, "signedUp": true},

  {"id": 102, "title": "关山社区助老陪伴服务", "category": "elder", "cover": "",
   "description": "陪社区独居老人聊天、读报，协助整理房间与测量血压。有护理经验者优先。",
   "address": "武汉市洪山区关山街社区服务中心", "lat": 30.5062, "lng": 114.4120,
   "startTime": "2026-09-27 14:00:00", "endTime": "2026-09-27 17:00:00",
   "needCount": 12, "joinedCount": 12, "serviceHours": 3, "signinCode": "137905", "signinRadius": 150,
   "status": "signuping", "publisherId": 10, "createTime": "2026-09-19 10:05:00",
   "distance": 2.6, "signedUp": false},

  {"id": 103, "title": "南湖小学课后作业辅导", "category": "teach", "cover": "",
   "description": "为四年级学生辅导语文与数学作业，请提前准备两道趣味例题。",
   "address": "武汉市洪山区南湖第一小学", "lat": 30.5003, "lng": 114.3602,
   "startTime": "2026-09-28 15:30:00", "endTime": "2026-09-28 19:30:00",
   "needCount": 8, "joinedCount": 5, "serviceHours": 4, "signinCode": "502874", "signinRadius": 200,
   "status": "signuping", "publisherId": 11, "createTime": "2026-09-18 16:40:00",
   "distance": 3.4, "signedUp": false},

  {"id": 104, "title": "校园马拉松赛事志愿服务", "category": "game", "cover": "",
   "description": "负责补给站发水、赛道引导与终点计时记录。需提前 30 分钟到场参加岗前培训。",
   "address": "华中科技大学主校区体育场", "lat": 30.5123, "lng": 114.4315,
   "startTime": "2026-09-25 07:00:00", "endTime": "2026-09-25 13:00:00",
   "needCount": 60, "joinedCount": 42, "serviceHours": 6, "signinCode": "903167", "signinRadius": 300,
   "status": "signuping", "publisherId": 12, "createTime": "2026-09-15 09:12:00",
   "distance": 0.8, "signedUp": true},

  {"id": 105, "title": "校图书馆图书整理志愿岗", "category": "campus", "cover": "",
   "description": "按索书号归架、整理阅览区桌椅、协助读者查询。安静作业，请勿喧哗。",
   "address": "华中科技大学图书馆三楼", "lat": 30.5138, "lng": 114.4298,
   "startTime": "2026-09-24 09:00:00", "endTime": "2026-09-24 11:00:00",
   "needCount": 20, "joinedCount": 20, "serviceHours": 2, "signinCode": "271638", "signinRadius": 100,
   "status": "ongoing", "publisherId": 9, "createTime": "2026-09-14 11:30:00",
   "distance": 0.3, "signedUp": false},

  {"id": 106, "title": "校园绿化秋季植树活动", "category": "env", "cover": "",
   "description": "在教学楼东侧空地种植香樟与桂花树苗，主办方提供树苗与工具。",
   "address": "华中科技大学东九教学楼东侧", "lat": 30.5162, "lng": 114.4341,
   "startTime": "2026-09-29 08:00:00", "endTime": "2026-09-29 10:30:00",
   "needCount": 40, "joinedCount": 15, "serviceHours": 2.5, "signinCode": "415720", "signinRadius": 200,
   "status": "signuping", "publisherId": 13, "createTime": "2026-09-21 08:50:00",
   "distance": 1.1, "signedUp": false},

  {"id": 107, "title": "光谷敬老院中秋慰问演出", "category": "elder", "cover": "",
   "description": "为老人表演节目、陪伴聊天并赠送手作礼物。有才艺者欢迎报名演出环节。",
   "address": "武汉市洪山区光谷敬老院", "lat": 30.4912, "lng": 114.4102,
   "startTime": "2026-09-21 14:00:00", "endTime": "2026-09-21 17:00:00",
   "needCount": 25, "joinedCount": 25, "serviceHours": 3, "signinCode": "880432", "signinRadius": 150,
   "status": "finished", "publisherId": 10, "createTime": "2026-09-10 10:00:00",
   "distance": 5.2, "signedUp": true},

  {"id": 108, "title": "社区义诊现场秩序维护", "category": "campus", "cover": "",
   "description": "协助维持排队秩序、引导老人登记信息、分发健康宣传手册。",
   "address": "武汉市洪山区珞南社区卫生服务中心", "lat": 30.5231, "lng": 114.3576,
   "startTime": "2026-09-30 08:30:00", "endTime": "2026-09-30 12:30:00",
   "needCount": 16, "joinedCount": 9, "serviceHours": 4, "signinCode": "336914", "signinRadius": 200,
   "status": "signuping", "publisherId": 11, "createTime": "2026-09-22 09:15:00",
   "distance": 1.8, "signedUp": false},

  {"id": 109, "title": "光谷广场交通文明引导", "category": "game", "cover": "",
   "description": "在光谷广场主要路口协助引导行人过马路，配合交警开展文明出行宣传。",
   "address": "武汉市洪山区光谷广场地铁站 C 出口", "lat": 30.5069, "lng": 114.4027,
   "startTime": "2026-09-26 16:00:00", "endTime": "2026-09-26 19:00:00",
   "needCount": 24, "joinedCount": 7, "serviceHours": 3, "signinCode": "728561", "signinRadius": 150,
   "status": "signuping", "publisherId": 12, "createTime": "2026-09-20 17:30:00",
   "distance": 2.2, "signedUp": false},

  {"id": 110, "title": "暑期留守儿童支教营", "category": "teach", "cover": "",
   "description": "连续五天驻点支教，开展科学小实验、美术与体育活动，需全程参与。",
   "address": "湖北省黄冈市浠水县白莲镇中心小学", "lat": 30.4521, "lng": 115.2663,
   "startTime": "2026-08-18 08:00:00", "endTime": "2026-08-22 17:00:00",
   "needCount": 10, "joinedCount": 10, "serviceHours": 8, "signinCode": "199245", "signinRadius": 300,
   "status": "finished", "publisherId": 13, "createTime": "2026-08-01 10:00:00",
   "distance": 8.6, "signedUp": false},

  {"id": 111, "title": "秋季校运会赛场志愿服务", "category": "game", "cover": "",
   "description": "负责检录、器材搬运与成绩记录，需连续两天到岗。",
   "address": "华中科技大学东校区田径场", "lat": 30.5091, "lng": 114.4367,
   "startTime": "2026-10-08 07:30:00", "endTime": "2026-10-09 17:00:00",
   "needCount": 50, "joinedCount": 33, "serviceHours": 5, "signinCode": "604578", "signinRadius": 300,
   "status": "signuping", "publisherId": 9, "createTime": "2026-09-22 15:00:00",
   "distance": 0.5, "signedUp": false},

  {"id": 112, "title": "校园旧物回收环保行动", "category": "env", "cover": "",
   "description": "在宿舍区设点回收旧衣物、旧书与纸箱，分类打包后交由回收机构处理。",
   "address": "华中科技大学韵苑学生公寓广场", "lat": 30.5178, "lng": 114.4271,
   "startTime": "2026-09-27 09:00:00", "endTime": "2026-09-27 11:00:00",
   "needCount": 30, "joinedCount": 11, "serviceHours": 2, "signinCode": "250817", "signinRadius": 200,
   "status": "signuping", "publisherId": 13, "createTime": "2026-09-21 11:00:00",
   "distance": 0.9, "signedUp": false}
]`;

// ==================== 我的报名（4 条，覆盖 4 种状态） ====================

const SIGNUPS_JSON: string = `[
  {"id": 501, "activityId": 101, "userId": 1, "status": "signed_up", "signupTime": "2026-09-20 19:02:00"},
  {"id": 502, "activityId": 104, "userId": 1, "status": "checked_in", "signupTime": "2026-09-16 08:40:00"},
  {"id": 503, "activityId": 107, "userId": 1, "status": "completed", "signupTime": "2026-09-11 12:15:00"},
  {"id": 504, "activityId": 112, "userId": 1, "status": "signed_up", "signupTime": "2026-09-21 20:30:00"}
]`;

// ==================== 时长明细（8 条，合计 18.5h） ====================

const HOURS_JSON: string = `[
  {"id": 601, "userId": 1, "activityId": 107, "hours": 3, "gainTime": "2026-09-21 17:10:00", "activityTitle": "光谷敬老院中秋慰问演出", "activityCategory": "elder"},
  {"id": 602, "userId": 1, "activityId": 104, "hours": 1.5, "gainTime": "2026-09-19 09:20:00", "activityTitle": "校园马拉松赛事志愿服务", "activityCategory": "game"},
  {"id": 603, "userId": 1, "activityId": 96, "hours": 2, "gainTime": "2026-09-14 11:05:00", "activityTitle": "图书馆图书整理志愿岗", "activityCategory": "campus"},
  {"id": 604, "userId": 1, "activityId": 88, "hours": 4, "gainTime": "2026-08-22 17:30:00", "activityTitle": "暑期留守儿童支教营", "activityCategory": "teach"},
  {"id": 605, "userId": 1, "activityId": 81, "hours": 2, "gainTime": "2026-06-18 10:40:00", "activityTitle": "东湖绿道环保清理行动", "activityCategory": "env"},
  {"id": 606, "userId": 1, "activityId": 76, "hours": 3, "gainTime": "2026-05-30 16:20:00", "activityTitle": "关山社区助老陪伴服务", "activityCategory": "elder"},
  {"id": 607, "userId": 1, "activityId": 70, "hours": 2, "gainTime": "2026-04-25 11:00:00", "activityTitle": "校园旧物回收环保行动", "activityCategory": "env"},
  {"id": 608, "userId": 1, "activityId": 65, "hours": 1, "gainTime": "2026-03-22 18:00:00", "activityTitle": "春季校园清洁志愿岗", "activityCategory": "campus"}
]`;

// ==================== 互助求助（8 条，覆盖 pending/ongoing/finished） ====================

const HELPS_JSON: string = `[
  {"id": 201, "publisherId": 1, "title": "帮忙代取快递送到宿舍楼下", "category": "errand",
   "description": "两个小件快递，在韵苑菜鸟驿站，取件码稍后私信。送到 12 栋楼下即可。",
   "rewardPoint": 8, "expectTime": "今天 18:00 前", "address": "华中科技大学韵苑 12 栋",
   "lat": 30.5172, "lng": 114.4266, "status": "pending", "createTime": "2026-09-23 09:10:00",
   "distance": 0.3, "isPublisher": true, "isHelper": false},

  {"id": 202, "publisherId": 10, "title": "借一把民谣吉他（周末两天）", "category": "borrow",
   "description": "社团小型演出临时借用，周六取周日还，如有琴包更好，会小心保管。",
   "rewardPoint": 15, "expectTime": "本周六前", "address": "华中科技大学紫菘学生公寓",
   "lat": 30.5088, "lng": 114.4243, "status": "pending", "createTime": "2026-09-23 08:30:00",
   "distance": 1.2, "isPublisher": false, "isHelper": false},

  {"id": 203, "publisherId": 9, "title": "求教高数第三章课后习题", "category": "qa",
   "description": "多元函数微分学部分，第 12、15、18 题没思路，希望能当面讲一遍。",
   "rewardPoint": 20, "expectTime": "本周内", "address": "华中科技大学图书馆三楼研讨间",
   "lat": 30.5138, "lng": 114.4298, "status": "ongoing", "createTime": "2026-09-22 20:15:00",
   "distance": 0.5, "isPublisher": false, "isHelper": true},

  {"id": 204, "publisherId": 1, "title": "帮忙搬运两箱行李上 6 楼", "category": "carry",
   "description": "两箱书和衣物，无电梯，宿舍在 6 楼。已备好矿泉水。",
   "rewardPoint": 30, "expectTime": "已完成", "address": "华中科技大学西十二舍",
   "lat": 30.5148, "lng": 114.4229, "status": "finished", "createTime": "2026-09-19 15:40:00",
   "distance": 0.9, "isPublisher": true, "isHelper": false},

  {"id": 205, "publisherId": 11, "title": "求带一份材料到行政楼盖章", "category": "errand",
   "description": "社团活动备案表，需要教务处与学工处两个章，跑一趟即可，材料已装袋。",
   "rewardPoint": 10, "expectTime": "明天上午", "address": "华中科技大学行政楼",
   "lat": 30.5104, "lng": 114.4308, "status": "ongoing", "createTime": "2026-09-22 16:20:00",
   "distance": 0.6, "isPublisher": false, "isHelper": false},

  {"id": 206, "publisherId": 12, "title": "借一个充电宝救急", "category": "borrow",
   "description": "在东九上晚课，手机剩 5% 电，求借一个充电宝用到 21:30。",
   "rewardPoint": 5, "expectTime": "今晚 22:00 前", "address": "华中科技大学东九教学楼",
   "lat": 30.5162, "lng": 114.4341, "status": "pending", "createTime": "2026-09-23 11:05:00",
   "distance": 0.2, "isPublisher": false, "isHelper": false},

  {"id": 207, "publisherId": 13, "title": "求帮修改一份英文简历", "category": "skill",
   "description": "申请海外交换项目用的 CV，希望帮忙润色措辞并调整结构。",
   "rewardPoint": 25, "expectTime": "已完成", "address": "线上沟通", "lat": 0, "lng": 0,
   "status": "finished", "createTime": "2026-09-15 10:00:00",
   "distance": 1.5, "isPublisher": false, "isHelper": false},

  {"id": 208, "publisherId": 10, "title": "帮忙照看半天仓鼠", "category": "skill",
   "description": "国庆回家一天，需要有人帮忙喂食换水，笼子在我宿舍，操作很简单。",
   "rewardPoint": 18, "expectTime": "国庆期间", "address": "华中科技大学韵苑 8 栋",
   "lat": 30.5181, "lng": 114.4258, "status": "pending", "createTime": "2026-09-23 10:20:00",
   "distance": 2.1, "isPublisher": false, "isHelper": false}
]`;

// ==================== 接单（4 条） ====================

const ORDERS_JSON: string = `[
  {"id": 301, "requestId": 203, "helperId": 1, "status": "ongoing", "acceptTime": "2026-09-22 21:00:00", "finishTime": ""},
  {"id": 302, "requestId": 204, "helperId": 2, "status": "finished", "acceptTime": "2026-09-19 15:50:00", "finishTime": "2026-09-19 17:30:00"},
  {"id": 303, "requestId": 205, "helperId": 2, "status": "wait_confirm", "acceptTime": "2026-09-22 17:00:00", "finishTime": ""},
  {"id": 304, "requestId": 207, "helperId": 3, "status": "finished", "acceptTime": "2026-09-15 10:30:00", "finishTime": "2026-09-16 09:00:00"}
]`;

// ==================== 互评（4 条，对应已完成的 204 / 207） ====================

const REVIEWS_JSON: string = `[
  {"id": 401, "orderId": 302, "fromUserId": 1, "toUserId": 2, "score": 5, "content": "搬得很快，还帮我把纸箱拆平了，非常感谢！", "createTime": "2026-09-19 18:00:00", "fromUserName": "张明远"},
  {"id": 402, "orderId": 302, "fromUserId": 2, "toUserId": 1, "score": 5, "content": "同学很好沟通，楼下等着接应，很省事。", "createTime": "2026-09-19 18:30:00", "fromUserName": "李文静"},
  {"id": 403, "orderId": 304, "fromUserId": 13, "toUserId": 3, "score": 4, "content": "改得很细，回复也快，推荐。", "createTime": "2026-09-16 10:00:00", "fromUserName": "林嘉树"},
  {"id": 404, "orderId": 304, "fromUserId": 3, "toUserId": 13, "score": 5, "content": "需求说得清楚，配合顺利。", "createTime": "2026-09-16 12:00:00", "fromUserName": "王浩然"}
]`;

// ==================== 消息中心（12 条，保证有未读） ====================

const MESSAGES_JSON: string = `[
  {"id": 701, "userId": 1, "type": "activity", "relatedId": 101, "title": "报名成功", "content": "你已成功报名「东湖绿道环保清理行动」，请于 9-26 08:30 前到场并扫码签到。", "isRead": false, "createTime": "2026-09-20 19:02:00"},
  {"id": 702, "userId": 1, "type": "help", "relatedId": 203, "title": "接单成功", "content": "你已接下「求教高数第三章课后习题」，请在约定时间前联系发布者。", "isRead": false, "createTime": "2026-09-22 21:00:00"},
  {"id": 703, "userId": 1, "type": "notice", "relatedId": 0, "title": "志愿时长已到账", "content": "「光谷敬老院中秋慰问演出」3 小时已计入你的累计志愿时长。", "isRead": false, "createTime": "2026-09-21 17:10:00"},
  {"id": 704, "userId": 1, "type": "interact", "relatedId": 204, "title": "收到新评价", "content": "李文静给了你 5 星评价：同学很好沟通，楼下等着接应，很省事。", "isRead": true, "createTime": "2026-09-19 18:30:00"},
  {"id": 705, "userId": 1, "type": "activity", "relatedId": 104, "title": "活动即将开始", "content": "「校园马拉松赛事志愿服务」将于 9-25 07:00 开始，请提前 30 分钟到场签到。", "isRead": false, "createTime": "2026-09-24 20:00:00"},
  {"id": 706, "userId": 1, "type": "help", "relatedId": 204, "title": "订单已完成", "content": "「帮忙搬运两箱行李上 6 楼」已确认完成，30 积分已扣除，别忘了给对方评价。", "isRead": true, "createTime": "2026-09-19 17:30:00"},
  {"id": 707, "userId": 1, "type": "notice", "relatedId": 0, "title": "信用分提升", "content": "本次互助完成并获 5 星评价，信用分 +2，当前 92 分。", "isRead": true, "createTime": "2026-09-19 18:31:00"},
  {"id": 708, "userId": 1, "type": "activity", "relatedId": 111, "title": "新活动推荐", "content": "根据你的「赛会」偏好，为你推荐「秋季校运会赛场志愿服务」，还差 17 人。", "isRead": true, "createTime": "2026-09-22 15:05:00"},
  {"id": 709, "userId": 1, "type": "interact", "relatedId": 101, "title": "有人也报名了", "content": "你的同学王浩然也报名了「东湖绿道环保清理行动」。", "isRead": true, "createTime": "2026-09-21 10:12:00"},
  {"id": 710, "userId": 1, "type": "help", "relatedId": 201, "title": "求助待接单提醒", "content": "你发布的「帮忙代取快递送到宿舍楼下」暂无人接单，可考虑提高悬赏积分。", "isRead": true, "createTime": "2026-09-23 12:00:00"},
  {"id": 711, "userId": 1, "type": "notice", "relatedId": 0, "title": "本周志愿榜单更新", "content": "你本周志愿时长 4.5 小时，位列学院第 12 名，继续加油！", "isRead": true, "createTime": "2026-09-22 08:00:00"},
  {"id": 712, "userId": 1, "type": "activity", "relatedId": 112, "title": "报名成功", "content": "你已成功报名「校园旧物回收环保行动」，请于 9-27 09:00 前到场。", "isRead": true, "createTime": "2026-09-21 20:30:00"}
]`;

// ==================== 积分流水（10 条） ====================

const POINTS_JSON: string = `[
  {"id": 801, "userId": 1, "changeValue": 30, "balance": 180, "reason": "完成互助任务「帮忙搬运两箱行李上 6 楼」", "relatedId": 204, "createTime": "2026-09-19 17:30:00"},
  {"id": 802, "userId": 1, "changeValue": -30, "balance": 150, "reason": "发布求助悬赏「帮忙搬运两箱行李上 6 楼」", "relatedId": 204, "createTime": "2026-09-19 15:40:00"},
  {"id": 803, "userId": 1, "changeValue": 20, "balance": 180, "reason": "志愿时长奖励（光谷敬老院中秋慰问演出）", "relatedId": 107, "createTime": "2026-09-21 17:10:00"},
  {"id": 804, "userId": 1, "changeValue": -8, "balance": 160, "reason": "发布求助悬赏「帮忙代取快递送到宿舍楼下」", "relatedId": 201, "createTime": "2026-09-23 09:10:00"},
  {"id": 805, "userId": 1, "changeValue": 15, "balance": 175, "reason": "互助双方互评奖励", "relatedId": 204, "createTime": "2026-09-19 18:31:00"},
  {"id": 806, "userId": 1, "changeValue": 10, "balance": 160, "reason": "连续打卡 7 天奖励", "relatedId": 0, "createTime": "2026-09-18 08:00:00"},
  {"id": 807, "userId": 1, "changeValue": -5, "balance": 150, "reason": "兑换志愿纪念徽章", "relatedId": 0, "createTime": "2026-09-12 20:15:00"},
  {"id": 808, "userId": 1, "changeValue": 25, "balance": 155, "reason": "志愿时长奖励（暑期留守儿童支教营）", "relatedId": 88, "createTime": "2026-08-22 17:30:00"},
  {"id": 809, "userId": 1, "changeValue": 40, "balance": 130, "reason": "暑期支教优秀志愿者奖励", "relatedId": 88, "createTime": "2026-08-25 10:00:00"},
  {"id": 810, "userId": 1, "changeValue": 20, "balance": 90, "reason": "志愿时长奖励（图书馆图书整理志愿岗）", "relatedId": 96, "createTime": "2026-09-14 11:05:00"}
]`;

// ==================== 首页 / 卡片聚合 ====================

const HOME_JSON: string = `{
  "todayHours": 1.5,
  "todayTargetHours": 4,
  "ongoingCount": 2,
  "pendingSigninCount": 1,
  "totalHours": 18.5,
  "point": 180,
  "creditScore": 92,
  "unreadCount": 3,
  "nextActivityId": 104,
  "nextActivityTitle": "校园马拉松赛事志愿服务",
  "nextActivityStartTime": "2026-09-25 07:00:00"
}`;

// ==================== 志愿大厅个人数字 ====================
// ⚠️ 这里三个值必须与下面的 HOURS_JSON 自洽：
//   totalHours = 8 条时长明细之和 = 3+1.5+2+4+2+3+2+1 = 18.5
//   joinCount  = 8 条时长明细的条数（一条 = 参与过一次活动）
//   与 CURRENT_USER 的 totalHours / CERTIFICATE 的 activityCount 也保持一致（18.5 / 8）
const VOLUNTEER_STATS_JSON: string = `{
  "totalHours": 18.5,
  "joinCount": 8,
  "point": 180,
  "creditScore": 92
}`;

// ==================== 电子证书 ====================

const CERTIFICATE_JSON: string = `{
  "userName": "张明远",
  "studentNo": "20230101",
  "college": "计算机科学与技术学院",
  "major": "软件工程",
  "totalHours": 18.5,
  "activityCount": 8,
  "serialNo": "HZY-2026-0001",
  "issueOrg": "鸿志愿校园志愿服务平台",
  "issueDate": "2026-09-23"
}`;

// ==================== 小鸿会话（对齐设计稿「志愿小鸿」屏） ====================
// ⚠️ 这里的日期/时长/距离必须与 ACTIVITIES_JSON 自洽（106 / 109 两条）：
//   106 校园绿化秋季植树活动 09-29 08:00 · 2.5h · 1.1km
//   109 光谷广场交通文明引导   09-26 16:00 · 3h   · 2.2km
//   改活动假数据时，下面的推荐卡 subtitle 要一起改。

/** 首屏会话：就是设计稿里那三屏内容（用户那句 → 已生成草稿 → 草稿卡） */
const AGENT_SESSION_JSON: string = `[
  {"id": 901, "role": "user", "content": "周六下午两点图书馆整理图书，需要 10 个人，算 2 小时"},
  {"id": 902, "role": "assistant", "content": "已生成活动草稿，确认无误就可以发布"},
  {"id": 903, "role": "assistant", "content": "", "cards": [
    {"cardType": "activity", "targetId": 0, "title": "图书馆图书整理志愿服务",
     "subtitle": "", "tag": "", "isDraft": true,
     "rows": [
       {"cells": [{"label": "time", "value": "09-26 周六 14:00 - 16:00"}]},
       {"cells": [{"label": "place", "value": "南湖图书馆 3 楼"}]},
       {"cells": [{"label": "count", "value": "10 人"}, {"label": "hours", "value": "2h"}]}
     ]}
  ]}
]`;

/** 输入条上方的快捷提问芯片（设计稿是两条，会换行成两行） */
const AGENT_PROMPTS_JSON: string = `["帮我发起一个活动", "有什么适合我的"]`;

/**
 * 小鸿的回复模板表。自上而下匹配，第一条命中即用；
 * 最后一条 keywords 为空 = 兜底（永远命中），所以**必须放在数组最后**。
 */
const AGENT_REPLIES_JSON: string = `[
  {"keywords": "活动,发起,发布,组织,策划,办一场,志愿服务,志愿活动",
   "content": "已生成活动草稿，确认无误就可以发布",
   "cards": [
     {"cardType": "activity", "targetId": 0, "title": "图书馆图书整理志愿服务",
      "subtitle": "", "tag": "", "isDraft": true,
      "rows": [
        {"cells": [{"label": "time", "value": "09-26 周六 14:00 - 16:00"}]},
        {"cells": [{"label": "place", "value": "南湖图书馆 3 楼"}]},
        {"cells": [{"label": "count", "value": "10 人"}, {"label": "hours", "value": "2h"}]}
      ]}
   ]},

  {"keywords": "快递,求助,跑腿,借,帮忙,代取,悬赏,搬运",
   "content": "已生成求助草稿，确认后就能发布",
   "cards": [
     {"cardType": "help", "targetId": 0, "title": "帮忙代取快递送到宿舍楼下",
      "subtitle": "", "tag": "", "isDraft": true,
      "rows": [
        {"cells": [{"label": "reward", "value": "8 积分"}]},
        {"cells": [{"label": "expect", "value": "今天 18:00 前"}]},
        {"cells": [{"label": "place", "value": "华中科技大学韵苑菜鸟驿站"}]}
      ]}
   ]},

  {"keywords": "推荐,适合,有空,周末,附近,时间,几场,什么",
   "content": "按你的空闲时间和偏好，这 2 场比较合适",
   "cards": [
     {"cardType": "activity", "targetId": 106, "title": "校园绿化秋季植树活动",
      "subtitle": "09-29 周二 08:00 · 2.5h · 距你 1.1km", "tag": "匹配度 92%",
      "isDraft": false, "rows": []},
     {"cardType": "activity", "targetId": 109, "title": "光谷广场交通文明引导",
      "subtitle": "09-26 周六 16:00 · 3h · 距你 2.2km", "tag": "匹配度 88%",
      "isDraft": false, "rows": []}
   ]},

  {"keywords": "",
   "content": "这句我还没太听懂。你可以直接说「帮我发起一个活动」，或者「推荐几场适合我的志愿活动」。",
   "cards": []}
]`;

/**
 * MockData —— 全部假数据的统一入口。
 * 页面**不直接**用这个类，而是通过 `service/` 层调用（页面只认识 Service，不认识 Mock），
 * 这样 D 阶段把 `Constants.USE_MOCK` 改成 false 时页面零改动。
 */
export class MockData {

  // ==================== 用户 ====================

  static currentUser(): User {
    return User.fromJson(JSON.parse(USER_JSON) as User);
  }

  static allUsers(): User[] {
    return User.fromJsonList(JSON.parse(USERS_JSON) as User[]);
  }

  /** 按 id 取用户；找不到返回 null */
  static userById(id: number): User | null {
    if (id === 1) {
      return MockData.currentUser();
    }
    const list: User[] = MockData.allUsers();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i];
      }
    }
    return null;
  }

  // ==================== 志愿活动 ====================

  static activities(): Activity[] {
    return Activity.fromJsonList(JSON.parse(ACTIVITIES_JSON) as Activity[]);
  }

  /**
   * 按筛选条件取活动。
   * filter 取值：'' / 'recommend' / 'nearby' → 全部；其余按 category 精确匹配。
   */
  static activitiesByFilter(filter: string): Activity[] {
    const all: Activity[] = MockData.activities();
    if (filter === '' || filter === 'recommend' || filter === 'nearby') {
      return all;
    }
    const out: Activity[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].category === filter) {
        out.push(all[i]);
      }
    }
    return out;
  }

  /** 关键词搜索（标题 / 地点） */
  static searchActivities(keyword: string, filter: string): Activity[] {
    const base: Activity[] = MockData.activitiesByFilter(filter);
    if (keyword === '') {
      return base;
    }
    const out: Activity[] = [];
    for (let i = 0; i < base.length; i++) {
      const a: Activity = base[i];
      if (a.title.indexOf(keyword) >= 0 || a.address.indexOf(keyword) >= 0) {
        out.push(a);
      }
    }
    return out;
  }

  /** 按距离升序（附近排序） */
  static sortByDistance(list: Activity[]): Activity[] {
    const out: Activity[] = list.slice();
    out.sort((a: Activity, b: Activity) => a.distance - b.distance);
    return out;
  }

  /** 按开始时间升序 */
  static sortByTime(list: Activity[]): Activity[] {
    const out: Activity[] = list.slice();
    out.sort((a: Activity, b: Activity) => a.startTime < b.startTime ? -1 : 1);
    return out;
  }

  /** 活动详情：在列表数据基础上补齐 publisher / signedUp / mySignupStatus（与真实接口行为一致） */
  static activityDetail(id: number): Activity | null {
    const all: Activity[] = MockData.activities();
    for (let i = 0; i < all.length; i++) {
      if (all[i].id === id) {
        const a: Activity = all[i];
        a.publisher = MockData.userById(a.publisherId);
        const status: string = MockData.myActivitySignupStatus(id);
        a.signedUp = status !== '';
        a.mySignupStatus = status;
        return a;
      }
    }
    return null;
  }

  /** 推荐活动（首页「本周推荐」大卡用） */
  static recommendedActivity(): Activity {
    const d: Activity | null = MockData.activityDetail(104);
    if (d) {
      return d;
    }
    return MockData.activities()[0];
  }

  /**
   * 活动排行榜（志愿大厅「活动排行榜」卡）。
   * 口径：按**已报名人数**降序，取前 count 名 —— 报名越多的活动越"热"。
   * 已结束的活动不参与排名（避免旧活动的历史人数长期霸榜）。
   */
  static activityRank(count: number): Activity[] {
    const all: Activity[] = MockData.activities();
    const open: Activity[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].status !== ActivityStatus.FINISHED) {
        open.push(all[i]);
      }
    }
    open.sort((a: Activity, b: Activity) => b.joinedCount - a.joinedCount);
    if (open.length > count) {
      return open.slice(0, count);
    }
    return open;
  }

  // ==================== 志愿大厅个人数字 ====================

  static volunteerStats(): VolunteerStats {
    return VolunteerStats.fromJson(JSON.parse(VOLUNTEER_STATS_JSON) as VolunteerStats);
  }

  // ==================== 我的报名 / 我的时长 ====================

  static mySignups(): Signup[] {
    const list: Signup[] = Signup.fromJsonList(JSON.parse(SIGNUPS_JSON) as Signup[]);
    // 联表补上活动详情（真实接口也是这么返回的）
    for (let i = 0; i < list.length; i++) {
      const a: Activity | null = MockData.activityDetail(list[i].activityId);
      if (a) {
        list[i].activity = a;
      }
    }
    return list;
  }

  /** 我对某活动的报名状态；未报名返回空串 */
  static myActivitySignupStatus(activityId: number): string {
    const list: Signup[] = Signup.fromJsonList(JSON.parse(SIGNUPS_JSON) as Signup[]);
    for (let i = 0; i < list.length; i++) {
      if (list[i].activityId === activityId) {
        return list[i].status;
      }
    }
    return '';
  }

  static hourRecords(): HourRecord[] {
    return HourRecord.fromJsonList(JSON.parse(HOURS_JSON) as HourRecord[]);
  }

  static totalHours(): number {
    return HourRecord.sumHours(MockData.hourRecords());
  }

  static certificate(): Certificate {
    return Certificate.fromJson(JSON.parse(CERTIFICATE_JSON) as Certificate);
  }

  // ==================== 互助 ====================

  static helps(): HelpRequest[] {
    return HelpRequest.fromJsonList(JSON.parse(HELPS_JSON) as HelpRequest[]);
  }

  /**
   * 按筛选取求助。
   * filter 取值：'' / 'all' → 全部；其余按 category 精确匹配。
   */
  static helpsByFilter(filter: string): HelpRequest[] {
    const all: HelpRequest[] = MockData.helps();
    if (filter === '' || filter === 'all') {
      return all;
    }
    const out: HelpRequest[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].category === filter) {
        out.push(all[i]);
      }
    }
    return out;
  }

  /** 关键词搜索（标题 / 描述） */
  static searchHelps(keyword: string, filter: string): HelpRequest[] {
    const base: HelpRequest[] = MockData.helpsByFilter(filter);
    if (keyword === '') {
      return base;
    }
    const out: HelpRequest[] = [];
    for (let i = 0; i < base.length; i++) {
      const h: HelpRequest = base[i];
      if (h.title.indexOf(keyword) >= 0 || h.description.indexOf(keyword) >= 0) {
        out.push(h);
      }
    }
    return out;
  }

  /**
   * 给一批求助补上发布者信息（只在 `publisher` 还是 null 时补）。
   *
   * 【为什么列表也要补】大厅卡片底行要显示「计算机学院 · 李同学 · 0.4km」，
   *   而 `publisher` 属于「按需返回」字段（真实后端在列表接口里也会带）。
   *   这里统一补一次，页面就不必自己再去查用户表。
   */
  static fillPublishers(list: HelpRequest[]): HelpRequest[] {
    for (let i = 0; i < list.length; i++) {
      if (list[i].publisher === null) {
        list[i].publisher = MockData.userById(list[i].publisherId);
      }
    }
    return list;
  }

  /** 我发布的求助 */
  static myPublishedHelps(): HelpRequest[] {
    const all: HelpRequest[] = MockData.helps();
    const out: HelpRequest[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].isPublisher) {
        out.push(all[i]);
      }
    }
    return out;
  }

  /** 我接单的求助 */
  static myAcceptedHelps(): HelpRequest[] {
    const all: HelpRequest[] = MockData.helps();
    const out: HelpRequest[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].isHelper) {
        out.push(all[i]);
      }
    }
    return out;
  }

  /** 求助详情：补齐 publisher / order / reviews，并判定「我」在这单里的身份 */
  static helpDetail(id: number): HelpRequest | null {
    const all: HelpRequest[] = MockData.helps();
    for (let i = 0; i < all.length; i++) {
      if (all[i].id === id) {
        const h: HelpRequest = all[i];
        h.publisher = MockData.userById(h.publisherId);

        // 接单信息；有我接的单则标记 isHelper，底部操作条据此换按钮
        const o: HelpOrder | null = MockData.orderOf(h.id);
        if (o) {
          h.order = o;
          if (o.helperId === 1) {
            h.isHelper = true;
          }
        }

        h.reviews = MockData.reviewsOf(h.id);
        h.reviewedByMe = HelpReview.hasReviewed(h.reviews, 1);
        return h;
      }
    }
    return null;
  }

  /** 全部接单（供筛选，不直接给页面用） */
  static allOrders(): HelpOrder[] {
    return HelpOrder.fromJsonList(JSON.parse(ORDERS_JSON) as HelpOrder[]);
  }

  /** 某求助的接单信息；无接单返回 null。会顺带把接单人信息补上。 */
  static orderOf(helpId: number): HelpOrder | null {
    const orders: HelpOrder[] = MockData.allOrders();
    for (let i = 0; i < orders.length; i++) {
      if (orders[i].requestId === helpId) {
        const o: HelpOrder = orders[i];
        o.helper = MockData.userById(o.helperId);
        return o;
      }
    }
    return null;
  }

  /** 全部互评（供筛选，不直接给页面用） */
  static allReviews(): HelpReview[] {
    return HelpReview.fromJsonList(JSON.parse(REVIEWS_JSON) as HelpReview[]);
  }

  /** 某求助的互评列表（先由求助找到订单，再按 orderId 过滤） */
  static reviewsOf(helpId: number): HelpReview[] {
    const out: HelpReview[] = [];
    const o: HelpOrder | null = MockData.orderOf(helpId);
    if (o === null) {
      return out;
    }
    const order: HelpOrder = o;
    const all: HelpReview[] = MockData.allReviews();
    for (let i = 0; i < all.length; i++) {
      if (all[i].orderId === order.id) {
        out.push(all[i]);
      }
    }
    return out;
  }

  // ==================== 消息 ====================

  static messages(): MessageItem[] {
    return MessageItem.fromJsonList(JSON.parse(MESSAGES_JSON) as MessageItem[]);
  }

  static messagesByType(type: string): MessageItem[] {
    const all: MessageItem[] = MockData.messages();
    if (type === '' || type === 'all') {
      return all;
    }
    return MessageItem.filterByType(all, type);
  }

  static unreadCount(): number {
    return MessageItem.countUnread(MockData.messages());
  }

  // ==================== 积分 ====================

  static pointLogs(): PointLog[] {
    return PointLog.fromJsonList(JSON.parse(POINTS_JSON) as PointLog[]);
  }

  // ==================== 首页聚合 / 证书 ====================

  static homeSummary(): HomeSummary {
    return HomeSummary.fromJson(JSON.parse(HOME_JSON) as HomeSummary);
  }

  // ==================== 小鸿 ====================

  /** 首屏会话（对齐设计稿小鸿屏） */
  static agentConversation(): ChatMessage[] {
    return ChatMessage.fromJsonList(JSON.parse(AGENT_SESSION_JSON) as ChatMessage[]);
  }

  /** 输入条上方的快捷提问芯片 */
  static agentPrompts(): string[] {
    return JSON.parse(AGENT_PROMPTS_JSON) as string[];
  }

  /**
   * 按关键词取一条回复。
   * 自上而下第一条命中的模板胜出；命中不到就用表尾那条 `keywords` 为空的兜底模板
   * （所以兜底模板的位置是契约的一部分，不能随手挪到前面）。
   */
  static agentReply(text: string): ChatMessage {
    const replies: AgentReply[] = AgentReply.fromJsonList(JSON.parse(AGENT_REPLIES_JSON) as AgentReply[]);
    let hit: AgentReply = replies[replies.length - 1];
    for (let i = 0; i < replies.length; i++) {
      if (replies[i].matches(text)) {
        hit = replies[i];
        break;
      }
    }
    return ChatMessage.localAssistantMessage(hit.content, hit.cards);
  }
}
