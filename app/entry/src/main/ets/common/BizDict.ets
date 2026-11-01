import { IconTone, TagTone } from './AppTheme';
import { IconPath } from './AppIcon';
import {
  ActivityCategory,
  ActivityStatus,
  SignupStatus,
  HelpCategory,
  HelpStatus,
  HelpOrderStatus,
  MessageType
} from './Constants';

/**
 * BizDict —— 业务码 → 展示 的唯一字典
 *
 * 【为什么要有这个文件】
 *   后端和数据库里存的是英文码（env / signuping / pending…），
 *   而界面上要显示「环保」「报名中」「待接单」+ 对应的图标和颜色。
 *   如果每个页面各写一遍 if-else，改一个分类颜色就得翻十几个文件。
 *   所以：**所有「码 → 图标 / 色调 / 中文」的映射只写在这里**。
 *
 * 【约定】
 *   - 传进来的码一律来自 Constants.ets 里的枚举
 *   - 查不到就返回中性默认值（而不是抛错），保证脏数据不会让页面崩
 */
export class BizDict {

  // ==================== 活动分类 ====================

  /** 活动分类图标 */
  static actIcon(category: string): string {
    if (category === ActivityCategory.ENV) {
      return IconPath.LEAF;
    }
    if (category === ActivityCategory.TEACH) {
      return IconPath.BOOK;
    }
    if (category === ActivityCategory.GAME) {
      return IconPath.TROPHY;
    }
    if (category === ActivityCategory.ELDER) {
      return IconPath.HEART;
    }
    if (category === ActivityCategory.CAMPUS) {
      return IconPath.HOME;
    }
    return IconPath.STAR;
  }

  /** 活动分类色调 */
  static actTone(category: string): string {
    if (category === ActivityCategory.ENV) {
      return IconTone.GREEN;
    }
    if (category === ActivityCategory.TEACH) {
      return IconTone.BLUE;
    }
    if (category === ActivityCategory.GAME) {
      return IconTone.YELLOW;
    }
    if (category === ActivityCategory.ELDER) {
      return IconTone.ORANGE;
    }
    if (category === ActivityCategory.CAMPUS) {
      return IconTone.BLUE;
    }
    return IconTone.GRAY;
  }

  /** 活动分类中文名（筛选条也用同一套） */
  static actLabel(category: string): Resource {
    if (category === ActivityCategory.ENV) {
      return $r('app.string.filter_env');
    }
    if (category === ActivityCategory.TEACH) {
      return $r('app.string.filter_teach');
    }
    if (category === ActivityCategory.GAME) {
      return $r('app.string.filter_game');
    }
    if (category === ActivityCategory.ELDER) {
      return $r('app.string.filter_elder');
    }
    if (category === ActivityCategory.CAMPUS) {
      return $r('app.string.filter_campus');
    }
    return $r('app.string.common_empty');
  }

  // ==================== 活动状态 ====================

  static actStatusLabel(status: string): Resource {
    if (status === ActivityStatus.SIGNUPING) {
      return $r('app.string.detail_status_signuping');
    }
    if (status === ActivityStatus.ONGOING) {
      return $r('app.string.detail_status_ongoing');
    }
    if (status === ActivityStatus.FINISHED) {
      return $r('app.string.detail_status_end');
    }
    return $r('app.string.common_empty');
  }

  static actStatusTone(status: string): string {
    if (status === ActivityStatus.SIGNUPING) {
      return TagTone.ORANGE;
    }
    if (status === ActivityStatus.ONGOING) {
      return TagTone.GREEN;
    }
    if (status === ActivityStatus.FINISHED) {
      return TagTone.GRAY;
    }
    return TagTone.GRAY;
  }

  // ==================== 报名状态 ====================

  static signupStatusLabel(status: string): Resource {
    if (status === SignupStatus.SIGNED_UP) {
      return $r('app.string.signup_status_signed_up');
    }
    if (status === SignupStatus.CHECKED_IN) {
      return $r('app.string.signup_status_checked_in');
    }
    if (status === SignupStatus.COMPLETED) {
      return $r('app.string.signup_status_completed');
    }
    if (status === SignupStatus.NO_SHOW) {
      return $r('app.string.signup_status_no_show');
    }
    return $r('app.string.common_empty');
  }

  static signupStatusTone(status: string): string {
    if (status === SignupStatus.SIGNED_UP) {
      return TagTone.ORANGE;
    }
    if (status === SignupStatus.CHECKED_IN) {
      return TagTone.BLUE;
    }
    if (status === SignupStatus.COMPLETED) {
      return TagTone.GREEN;
    }
    if (status === SignupStatus.NO_SHOW) {
      return TagTone.RED;
    }
    return TagTone.GRAY;
  }

  // ==================== 互助分类 ====================

  static helpIcon(category: string): string {
    if (category === HelpCategory.ERRAND) {
      return IconPath.RUN;
    }
    if (category === HelpCategory.BORROW) {
      return IconPath.BOX;
    }
    if (category === HelpCategory.QA) {
      return IconPath.MESSAGE;
    }
    if (category === HelpCategory.SKILL) {
      return IconPath.TOOL;
    }
    if (category === HelpCategory.CARRY) {
      return IconPath.CART;
    }
    return IconPath.PEOPLE;
  }

  static helpTone(category: string): string {
    if (category === HelpCategory.ERRAND) {
      return IconTone.GREEN;
    }
    if (category === HelpCategory.BORROW) {
      return IconTone.BLUE;
    }
    if (category === HelpCategory.QA) {
      return IconTone.YELLOW;
    }
    if (category === HelpCategory.SKILL) {
      return IconTone.ORANGE;
    }
    if (category === HelpCategory.CARRY) {
      return IconTone.BLUE;
    }
    return IconTone.GRAY;
  }

  static helpLabel(category: string): Resource {
    if (category === HelpCategory.ERRAND) {
      return $r('app.string.help_cat_errand');
    }
    if (category === HelpCategory.BORROW) {
      return $r('app.string.help_cat_borrow');
    }
    if (category === HelpCategory.QA) {
      return $r('app.string.help_cat_qa');
    }
    if (category === HelpCategory.SKILL) {
      return $r('app.string.help_cat_skill');
    }
    if (category === HelpCategory.CARRY) {
      return $r('app.string.help_cat_carry');
    }
    return $r('app.string.common_empty');
  }

  // ==================== 求助状态 ====================

  static helpStatusLabel(status: string): Resource {
    if (status === HelpStatus.PENDING) {
      return $r('app.string.help_status_pending');
    }
    if (status === HelpStatus.ONGOING) {
      return $r('app.string.help_status_doing');
    }
    if (status === HelpStatus.FINISHED) {
      return $r('app.string.help_status_done');
    }
    if (status === HelpStatus.CANCELED) {
      return $r('app.string.help_status_canceled');
    }
    return $r('app.string.common_empty');
  }

  /**
   * 求助状态的色调。
   *
   * 【为什么「待接单」是绿、「进行中」是黄 —— 与活动状态正好反过来】
   *   照设计稿 `鸿志愿_互助大厅_消息中心_我的_界面稿.png`：
   *   大厅卡片上「待接单」是绿底绿字（#EAF5EF/#4D9B70）、「进行中」是黄底黄字。
   *   语义上也自洽：待接单 = 这单还空着、**可以接**（肯定态）；
   *   进行中 = 已经有人在跑、**需要跟进**（提醒态）。
   *   活动状态那边正好相反（报名中=橙、进行中=绿），两套是不同领域，不必强行统一。
   */
  static helpStatusTone(status: string): string {
    if (status === HelpStatus.PENDING) {
      return TagTone.GREEN;
    }
    if (status === HelpStatus.ONGOING) {
      return TagTone.YELLOW;
    }
    if (status === HelpStatus.FINISHED) {
      return TagTone.GRAY;
    }
    if (status === HelpStatus.CANCELED) {
      return TagTone.GRAY;
    }
    return TagTone.GRAY;
  }

  // ==================== 接单状态 ====================

  static orderStatusLabel(status: string): Resource {
    if (status === HelpOrderStatus.ONGOING) {
      return $r('app.string.order_status_ongoing');
    }
    if (status === HelpOrderStatus.WAIT_CONFIRM) {
      return $r('app.string.order_status_wait_confirm');
    }
    if (status === HelpOrderStatus.FINISHED) {
      return $r('app.string.order_status_finished');
    }
    return $r('app.string.common_empty');
  }

  // ==================== 消息类型 ====================

  static msgIcon(type: string): string {
    if (type === MessageType.NOTICE) {
      return IconPath.BELL;
    }
    if (type === MessageType.INTERACT) {
      return IconPath.HEART;
    }
    if (type === MessageType.ACTIVITY) {
      return IconPath.CERTIFICATE;
    }
    if (type === MessageType.HELP) {
      return IconPath.PEOPLE;
    }
    return IconPath.MESSAGE;
  }

  static msgTone(type: string): string {
    if (type === MessageType.NOTICE) {
      return IconTone.BLUE;
    }
    if (type === MessageType.INTERACT) {
      return IconTone.ORANGE;
    }
    if (type === MessageType.ACTIVITY) {
      return IconTone.YELLOW;
    }
    if (type === MessageType.HELP) {
      return IconTone.GREEN;
    }
    return IconTone.GRAY;
  }
}
