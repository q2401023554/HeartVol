# 鸿志愿 · HeartVol

面向高校场景的志愿服务与互助平台。志愿者端为 HarmonyOS 原生应用（ArkTS / ArkUI），服务端为轻量 Spring Boot 3 服务，覆盖活动发布、扫码签到、志愿服务时长认定、证书生成、互助求助与站内消息全流程。

`HarmonyOS 6.1.1(24)` · `ArkTS / ArkUI` · `Spring Boot 3` · `MySQL 8`

> 规模：客户端 87 个 `.ets`（约 17.8k 行）/ 18 个页面；服务端 31 个 `.java`（约 3.1k 行）/ 31 个接口；数据库 12 张表。

## 功能

| 模块 | 能力 |
| :--- | :--- |
| 账号 | 注册登录、HMAC-SHA256 令牌鉴权、BCrypt 口令散列、信用分与积分 |
| 活动 | 发布 / 编辑 / 下架、分类与筛选、人数与时长设定、封面与经纬度、我的发布 |
| 报名 | 报名与取消、名额占用、我的报名、组织者审核视图 |
| 签到 | 组织者出示二维码，志愿者端 Scan Kit 扫码签到；一次性签到码 + 有效期校验 |
| 时长 | 签到自动累计志愿时长，按活动与月份汇总，个人时长档案 |
| 证书 | 服务时长达标后生成志愿证书，云端同步与本地留存 |
| 互助 | 求助发布（悬赏 / 期望时间 / 地点）、接单、完成确认、双向评价 |
| 消息 | 系统通知与业务消息、未读计数、按类型跳转对应详情页 |
| 助手 | 接入大模型的对话式助手「小鸿」，查活动、答流程、找互助 |

## 架构

```
HeartVol/
├── app/                        HarmonyOS 客户端（Stage 模型）
│   └── entry/src/main/ets/
│       ├── pages/              18 个页面
│       ├── components/         复用组件
│       ├── view/               页面内的区块视图
│       ├── model/              数据模型与请求 DTO
│       ├── service/            网络层、鉴权、本地存储
│       ├── common/             常量、HTTP 工具、接口基地址
│       └── entryability/       应用入口
├── server/                     Spring Boot 3 服务端
│   ├── src/main/java/cn/heartgun/guanggu/
│   │   ├── controller/         8 个 REST 控制器
│   │   ├── service/            业务服务
│   │   ├── repo/               JdbcTemplate 数据访问
│   │   └── common/             鉴权拦截器、令牌、统一响应
│   └── sql/                    schema.sql（12 表）+ seed.sql（演示数据）
└── docs/                       项目分析报告、真机回归清单、演示脚本
```

技术取舍：

- 服务端不引入 ORM，直接用 `JdbcTemplate` + 手写 SQL，SQL 全在 `repo/` 层可见，排查线上问题不必猜框架行为。
- 鉴权不引 Spring Security，`AuthInterceptor` + 手写 HMAC-SHA256 令牌，链路短，移动端接入成本低。
- 客户端状态集中在 `AppStorage` 与页面级 `@State`，不引入第三方状态库；跨页数据经 `router` 参数与本地持久化传递。
- 地图、扫码、分享分别对接 Map Kit、Scan Kit、`systemShare`，未自研轮子。

## 快速开始

### 服务端

```bash
# 1. 建库并导入表结构与演示数据
mysql -uroot -p -e "CREATE DATABASE guanggu DEFAULT CHARSET utf8mb4;"
mysql -uroot -p guanggu < server/sql/schema.sql
mysql -uroot -p guanggu < server/sql/seed.sql

# 2. 凭据走环境变量，不要写进配置文件
export DB_PASSWORD='你的数据库口令'
export JWT_SECRET="$(openssl rand -hex 32)"

# 3. 启动
cd server && mvn spring-boot:run
```

健康检查：`GET http://localhost:8080/api/health`

### 客户端

1. DevEco Studio 打开 `app/` 目录。
2. `File > Project Structure > Signing Configs` 勾选自动签名（**仓库不含任何签名材料**）。
3. 修改 `entry/src/main/ets/common/Constants.ets` 中的接口基地址为本机服务端地址。
4. 真机运行。

> 扫码签到需真机；模拟器无摄像头。

## 接口约定

- 统一前缀 `/api`，请求体与响应体均为 JSON。
- 鉴权头：`Authorization: Bearer <token>`，令牌由服务端以 HMAC-SHA256 签发，默认有效期 7 天。
- 响应包：`{ "code": 0, "msg": "ok", "data": ... }`，`code != 0` 时 `msg` 可直接展示给用户。

## 数据表

`sys_user`、`volunteer_activity`、`activity_signup`、`sign_record`、`volunteer_hour`、`help_request`、`help_order`、`help_review`、`point_log`、`message`、`chat_message`、`help_chat`。

## 说明

- 仓库为教学与毕业设计用途，演示数据见 `server/sql/seed.sql`，账号口令均为测试用。
- 未包含：APK/App 包、构建产物、签名证书、部署脚本。这些属于环境资产，按需自行配置。
- 已知限制：证书文件以本地文件 + 云端记录双写，暂未做跨设备一致性校验；消息推送依赖轮询，未接 Push Kit。

## License

MIT
