-- ============================================================
-- 鸿志愿 · 数据库建表脚本（B1）
-- 库名 guanggu ｜ MySQL 8.x ｜ utf8mb4
--
-- 【约定】
--   · 不建物理外键（演示项目，省去级联维护；关联靠索引 + 应用层校验）
--   · 所有时间 DATETIME，格式 yyyy-MM-dd HH:mm:ss
--   · 金额类：hours DECIMAL(5,1)；积分/信用分 INT
--   · 密码：BCrypt（Spring Security BCryptPasswordEncoder 直接可验）
--   · 状态码一律英文（与 App 端 BizDict 对齐）：
--     活动 signuping/ongoing/finished/cancelled
--     报名 signed_up/checked_in/completed/no_show
--     求助 pending/ongoing/finished/cancelled
--     接单 ongoing/wait_confirm/finished/cancelled
--     消息 notice/interact/activity/help
-- ============================================================

CREATE DATABASE IF NOT EXISTS guanggu DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE guanggu;

-- 1. 用户（含信用分 / 积分 / 累计时长 —— App「我的」页三大数字的来源）
DROP TABLE IF EXISTS sys_user;
CREATE TABLE sys_user (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  student_no   VARCHAR(32)  NOT NULL UNIQUE COMMENT '学号（登录名）',
  name         VARCHAR(32)  NOT NULL COMMENT '姓名',
  phone        VARCHAR(20)  DEFAULT '' COMMENT '手机号',
  password     VARCHAR(72)  NOT NULL COMMENT 'BCrypt 哈希',
  college      VARCHAR(64)  DEFAULT '' COMMENT '学院',
  major        VARCHAR(64)  DEFAULT '' COMMENT '专业',
  skill_tags   VARCHAR(128) DEFAULT '' COMMENT '技能标签，逗号分隔',
  avatar       VARCHAR(255) DEFAULT '' COMMENT '头像 URL（可空）',
  credit_score INT          NOT NULL DEFAULT 90 COMMENT '志愿信用分',
  point        INT          NOT NULL DEFAULT 0 COMMENT '公益积分',
  total_hours  DECIMAL(5,1) NOT NULL DEFAULT 0 COMMENT '累计志愿时长（小时）',
  lat          DOUBLE       DEFAULT 0 COMMENT '常用位置纬度（距离排序基准）',
  lng          DOUBLE       DEFAULT 0 COMMENT '常用位置经度',
  create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_student (student_no)
) ENGINE=InnoDB COMMENT='用户表';

-- 2. 志愿活动
DROP TABLE IF EXISTS volunteer_activity;
CREATE TABLE volunteer_activity (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  title         VARCHAR(64)  NOT NULL COMMENT '活动标题',
  category      VARCHAR(16)  NOT NULL COMMENT 'env/teach/game/elder/campus',
  cover         VARCHAR(255) DEFAULT '' COMMENT '封面图 URL（可空，空则前端用分类色占位）',
  description   VARCHAR(1024) DEFAULT '' COMMENT '活动介绍',
  address       VARCHAR(128) NOT NULL COMMENT '集合地点',
  lat           DOUBLE       NOT NULL DEFAULT 0,
  lng           DOUBLE       NOT NULL DEFAULT 0,
  start_time    DATETIME     NOT NULL,
  end_time      DATETIME     NOT NULL,
  need_count    INT          NOT NULL DEFAULT 0 COMMENT '招募人数',
  joined_count  INT          NOT NULL DEFAULT 0 COMMENT '已报名人数',
  service_hours DECIMAL(4,1) NOT NULL DEFAULT 0 COMMENT '单场志愿时长（小时）',
  signin_code   CHAR(6)      NOT NULL COMMENT '6 位签到码',
  signin_radius INT          NOT NULL DEFAULT 200 COMMENT '地理围栏半径（米）',
  status        VARCHAR(16)  NOT NULL DEFAULT 'signuping' COMMENT 'signuping/ongoing/finished/cancelled',
  publisher_id  BIGINT       NOT NULL COMMENT '发布者 sys_user.id',
  create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_status_time (status, start_time),
  KEY idx_category (category),
  KEY idx_publisher (publisher_id)
) ENGINE=InnoDB COMMENT='志愿活动表';

-- 3. 活动报名
DROP TABLE IF EXISTS activity_signup;
CREATE TABLE activity_signup (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  activity_id BIGINT      NOT NULL,
  user_id     BIGINT      NOT NULL,
  status      VARCHAR(16) NOT NULL DEFAULT 'signed_up' COMMENT 'signed_up/checked_in/completed/no_show',
  signup_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_activity (activity_id),
  KEY idx_user (user_id),
  UNIQUE KEY uk_activity_user (activity_id, user_id)
) ENGINE=InnoDB COMMENT='活动报名表';

-- 4. 签到核销记录（B5：扫码/地理围栏/手输三种来源）
DROP TABLE IF EXISTS sign_record;
CREATE TABLE sign_record (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  activity_id BIGINT     NOT NULL,
  user_id     BIGINT     NOT NULL,
  sign_type   VARCHAR(8) NOT NULL DEFAULT 'scan' COMMENT 'scan/geo/manual',
  lat         DOUBLE     DEFAULT 0,
  lng         DOUBLE     DEFAULT 0,
  sign_time   DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_activity (activity_id),
  KEY idx_user (user_id),
  UNIQUE KEY uk_activity_user (activity_id, user_id)
) ENGINE=InnoDB COMMENT='签到核销记录表';

-- 5. 志愿时长明细（"第一种货币"：签到成功即入账一行，同时累加 sys_user.total_hours）
DROP TABLE IF EXISTS volunteer_hour;
CREATE TABLE volunteer_hour (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT       NOT NULL,
  activity_id BIGINT      NOT NULL,
  hours      DECIMAL(5,1) NOT NULL COMMENT '本次入账时长（小时）',
  gain_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user_time (user_id, gain_time)
) ENGINE=InnoDB COMMENT='志愿时长明细表';

-- 6. 互助求助
DROP TABLE IF EXISTS help_request;
CREATE TABLE help_request (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  publisher_id BIGINT       NOT NULL COMMENT '发布者',
  title        VARCHAR(64)  NOT NULL,
  category     VARCHAR(16)  NOT NULL COMMENT 'errand/borrow/qa/skill/carry',
  description  VARCHAR(512) DEFAULT '' COMMENT '求助描述',
  reward_point INT          NOT NULL DEFAULT 0 COMMENT '悬赏积分',
  expect_time  VARCHAR(32)  DEFAULT '' COMMENT '期望完成（演示版为自由文本，如"今天 18:00 前"）',
  address      VARCHAR(128) DEFAULT '' COMMENT '求助地点',
  lat          DOUBLE       DEFAULT 0,
  lng          DOUBLE       DEFAULT 0,
  status       VARCHAR(16)  NOT NULL DEFAULT 'pending' COMMENT 'pending/ongoing/finished/cancelled',
  create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_status_time (status, create_time),
  KEY idx_category (category),
  KEY idx_publisher (publisher_id)
) ENGINE=InnoDB COMMENT='互助求助表';

-- 7. 互助接单（一次接单生成一条；完成后双方可互评）
DROP TABLE IF EXISTS help_order;
CREATE TABLE help_order (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  request_id  BIGINT      NOT NULL COMMENT 'help_request.id',
  helper_id   BIGINT      NOT NULL COMMENT '接单人',
  status      VARCHAR(16) NOT NULL DEFAULT 'ongoing' COMMENT 'ongoing/wait_confirm/finished/cancelled',
  accept_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finish_time DATETIME    DEFAULT NULL,
  KEY idx_request (request_id),
  KEY idx_helper (helper_id)
) ENGINE=InnoDB COMMENT='互助接单表';

-- 8. 互助互评（双向；影响 sys_user.credit_score）
DROP TABLE IF EXISTS help_review;
CREATE TABLE help_review (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id     BIGINT      NOT NULL COMMENT 'help_order.id',
  from_user_id BIGINT      NOT NULL COMMENT '评价人',
  to_user_id   BIGINT      NOT NULL COMMENT '被评人',
  score        INT         NOT NULL COMMENT '1-5 星',
  content      VARCHAR(255) DEFAULT '' COMMENT '评语',
  create_time  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_order (order_id),
  KEY idx_to_user (to_user_id),
  UNIQUE KEY uk_order_from (order_id, from_user_id)
) ENGINE=InnoDB COMMENT='互助互评表';

-- 9. 积分流水（"第二种货币"：悬赏扣 / 完成得 / 活动奖励 / 兑换）
DROP TABLE IF EXISTS point_log;
CREATE TABLE point_log (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id      BIGINT      NOT NULL,
  change_value INT         NOT NULL COMMENT '正=得，负=扣',
  balance      INT         NOT NULL COMMENT '变动后余额',
  reason       VARCHAR(128) NOT NULL COMMENT '变动原因',
  related_id   BIGINT      DEFAULT 0 COMMENT '关联业务 id（活动/求助），0=无',
  create_time  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user_time (user_id, create_time)
) ENGINE=InnoDB COMMENT='积分流水表';

-- 10. 消息中心（写入时机：报名成功/即将开始/接单成功/订单完成/收到评价/时长到账）
DROP TABLE IF EXISTS message;
CREATE TABLE message (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT      NOT NULL COMMENT '收件人',
  type        VARCHAR(16) NOT NULL COMMENT 'notice/interact/activity/help',
  related_id  BIGINT      DEFAULT 0 COMMENT '关联业务 id（活动/求助），0=无',
  title       VARCHAR(64) NOT NULL,
  content     VARCHAR(255) DEFAULT '',
  is_read     TINYINT     NOT NULL DEFAULT 0 COMMENT '0 未读 / 1 已读',
  from_uid    BIGINT      NOT NULL DEFAULT 0 COMMENT '聊天通知的发送者（点通知直达会话用；系统通知 0）',
  create_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user_type_read (user_id, type, is_read)
) ENGINE=InnoDB COMMENT='消息中心表';

-- 11. 智能体会话持久化（G 阶段「志愿小鸿」：多轮上下文 + Function Calling 留痕）
DROP TABLE IF EXISTS chat_message;
CREATE TABLE chat_message (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  session_id  BIGINT      NOT NULL COMMENT '会话 id（同一用户同一会话）',
  user_id     BIGINT      NOT NULL,
  role        VARCHAR(16) NOT NULL COMMENT 'user/assistant/tool',
  content     TEXT        COMMENT '消息内容（assistant 可含自然语言）',
  tool_name   VARCHAR(32) DEFAULT '' COMMENT 'Function Calling 的工具名（tool 角色用）',
  tool_args   VARCHAR(512) DEFAULT '' COMMENT '工具入参 JSON（留痕，便于排查）',
  create_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_session (session_id, create_time)
) ENGINE=InnoDB COMMENT='智能体会话消息表';

-- 12. 互助沟通聊天表 help_chat（简化版 IM：会话键=求助 id；chat_message 已被 G 阶段智能体会话表占用）
CREATE TABLE help_chat (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  request_id  BIGINT       NOT NULL COMMENT '会话键 = 求助 id',
  from_uid    BIGINT       NOT NULL,
  to_uid      BIGINT       NOT NULL,
  content     VARCHAR(500) NOT NULL,
  is_read     TINYINT      NOT NULL DEFAULT 0 COMMENT '收件人已读标记',
  create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_req (request_id, id),
  KEY idx_to (to_uid, is_read)
) ENGINE=InnoDB COMMENT='互助沟通聊天表';
