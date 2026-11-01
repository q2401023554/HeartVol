#!/bin/bash
# ============================================================
# 鸿志愿 · B8 全量接口回归（服务器本地执行）
# 用法: bash check_b8.sh
# 输出: 每接口 PASS/FAIL + 汇总；预期 = 响应体 code（401 特例为 HTTP 状态码）
# ============================================================
BASE=http://localhost:8080/api
PASS=0; FAIL=0; FAILED_NAMES=""

chk() { # name expect actual
  local name=$1 expect=$2 actual=$3
  if [ "$expect" = "$actual" ]; then
    PASS=$((PASS+1)); echo "PASS  $name (code=$actual)"
  else
    FAIL=$((FAIL+1)); FAILED_NAMES="$FAILED_NAMES $name"
    echo "FAIL  $name expect=$expect actual=$actual"
  fi
}
body_code() { python3 -c "import sys,json
try: print(json.load(sys.stdin).get('code'))
except Exception: print('PARSE_ERR')"; }
http_status() { curl -s -o /dev/null -w "%{http_code}" "$@"; }

RAND=$RANDOM

# ---------- 认证（B2/B3） ----------
chk health 200 "$(curl -s $BASE/health | body_code)"
chk register 200 "$(curl -s -X POST $BASE/auth/register -H 'Content-Type: application/json' \
  -d "{\"studentNo\":\"B8$RAND\",\"password\":\"123456\",\"name\":\"回归测试员\",\"college\":\"测试学院\"}" | body_code)"
chk register-duplicate 400 "$(curl -s -X POST $BASE/auth/register -H 'Content-Type: application/json' \
  -d "{\"studentNo\":\"B8$RAND\",\"password\":\"123456\",\"name\":\"回归测试员\"}" | body_code)"
chk login-ok 200 "$(curl -s -X POST $BASE/auth/login -H 'Content-Type: application/json' \
  -d '{"studentNo":"20230101","password":"123456"}' | body_code)"
chk login-wrong 400 "$(curl -s -X POST $BASE/auth/login -H 'Content-Type: application/json' \
  -d '{"studentNo":"20230101","password":"wrong"}' | body_code)"

TOKEN1=$(curl -s -X POST $BASE/auth/login -H 'Content-Type: application/json' \
  -d '{"studentNo":"20230101","password":"123456"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
TOKEN2=$(curl -s -X POST $BASE/auth/login -H 'Content-Type: application/json' \
  -d '{"studentNo":"20230188","password":"123456"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
A1="Authorization: Bearer $TOKEN1"
A2="Authorization: Bearer $TOKEN2"

chk me-with-token 200 "$(curl -s $BASE/user/me -H "$A1" | body_code)"
chk me-no-token-http401 401 "$(http_status $BASE/user/me)"
chk me-bad-token-http401 401 "$(http_status $BASE/user/me -H 'Authorization: Bearer bad.token.here')"

# ---------- 志愿（B4） ----------
chk activities-list 200 "$(curl -s "$BASE/activities?sort=distance" -H "$A1" | body_code)"
chk activities-filter 200 "$(curl -s "$BASE/activities?category=env&keyword=%E4%B8%9C%E6%B9%96" -H "$A1" | body_code)"
chk activity-detail 200 "$(curl -s $BASE/activities/101 -H "$A1" | body_code)"
chk activity-detail-404 404 "$(curl -s $BASE/activities/9999 -H "$A1" | body_code)"

NEW_ACT=$(curl -s -X POST $BASE/activities -H "$A1" -H 'Content-Type: application/json' \
  -d "{\"title\":\"B8回归活动\",\"category\":\"env\",\"address\":\"测试\",\"lat\":30.5,\"lng\":114.4,\"startTime\":\"2026-11-01 09:00:00\",\"endTime\":\"2026-11-01 11:00:00\",\"needCount\":10,\"serviceHours\":2}" | body_code)
chk activity-publish 200 "$NEW_ACT"

# ---------- 签到与我的记录（B5） ----------
# 用新注册的回归用户走完整报名→签到（种子用户状态已推进，避免状态假设）
T3=$(curl -s -X POST $BASE/auth/login -H 'Content-Type: application/json' \
  -d "{\"studentNo\":\"B8$RAND\",\"password\":\"123456\"}" | sed -E 's/.*"token":"([^"]+)".*/\1/')
A3="Authorization: Bearer $T3"
chk signup 200 "$(curl -s -X POST $BASE/activities/112/signup -H "$A3" | body_code)"
chk signup-duplicate 400 "$(curl -s -X POST $BASE/activities/112/signup -H "$A3" | body_code)"
chk signin-wrong-code 400 "$(curl -s -X POST $BASE/activities/112/signin -H "$A3" -H 'Content-Type: application/json' -d '{"code":"000000"}' | body_code)"
chk signin-ok 200 "$(curl -s -X POST $BASE/activities/112/signin -H "$A3" -H 'Content-Type: application/json' -d '{"code":"250817","signType":"manual"}' | body_code)"
chk signin-repeat 400 "$(curl -s -X POST $BASE/activities/112/signin -H "$A3" -H 'Content-Type: application/json' -d '{"code":"250817"}' | body_code)"
chk my-signups 200 "$(curl -s $BASE/user/signups -H "$A3" | body_code)"
chk my-hours 200 "$(curl -s $BASE/user/hours -H "$A3" | body_code)"

# ---------- 互助（B6）：用户1 发布 → 用户2 接单 → 用户1 确认 → 双方互评 ----------
chk helps-list 200 "$(curl -s "$BASE/helps?sort=distance" -H "$A1" | body_code)"
chk help-detail 200 "$(curl -s $BASE/helps/201 -H "$A1" | body_code)"
chk help-publish 200 "$(curl -s -X POST $BASE/helps -H "$A1" -H 'Content-Type: application/json' \
  -d "{\"title\":\"B8-help-v2\",\"category\":\"errand\",\"description\":\"regression\",\"rewardPoint\":5,\"expectTime\":\"today\",\"address\":\"test\"}" | body_code)"
B8_HELP=$(mysql -N guanggu -e "SELECT id FROM help_request WHERE title='B8-help-v2' ORDER BY id DESC LIMIT 1")
chk help-accept 200 "$(curl -s -X POST $BASE/helps/$B8_HELP/accept -H "$A2" | body_code)"
chk help-finish 200 "$(curl -s -X POST $BASE/helps/$B8_HELP/finish -H "$A1" | body_code)"
B8_ORDER=$(mysql -N guanggu -e "SELECT id FROM help_order WHERE request_id=$B8_HELP ORDER BY id DESC LIMIT 1")
chk help-review-1 200 "$(curl -s -X POST $BASE/helps/orders/$B8_ORDER/review -H "$A1" -H 'Content-Type: application/json' -d '{"score":5,"content":"回归"}' | body_code)"
chk help-review-2 200 "$(curl -s -X POST $BASE/helps/orders/$B8_ORDER/review -H "$A2" -H 'Content-Type: application/json' -d '{"score":4,"content":"回归"}' | body_code)"
chk help-review-duplicate 400 "$(curl -s -X POST $BASE/helps/orders/$B8_ORDER/review -H "$A1" -H 'Content-Type: application/json' -d '{"score":5}' | body_code)"

# ---------- 消息（B7） ----------
chk messages-list 200 "$(curl -s "$BASE/user/messages?size=3" -H "$A1" | body_code)"
chk messages-filter 200 "$(curl -s "$BASE/user/messages?type=help" -H "$A1" | body_code)"
chk messages-unread 200 "$(curl -s $BASE/user/messages/unread -H "$A1" | body_code)"
chk messages-read-all 200 "$(curl -s -X POST "$BASE/user/messages/read-all" -H "$A1" | body_code)"
B8_MSG=$(mysql -N guanggu -e "SELECT id FROM message WHERE user_id=1 ORDER BY id DESC LIMIT 1")
chk messages-read-one 200 "$(curl -s -X POST $BASE/user/messages/$B8_MSG/read -H "$A1" | body_code)"
chk messages-read-one-404 404 "$(curl -s -X POST $BASE/user/messages/999999/read -H "$A1" | body_code)"

echo "=========================================="
echo "回归结果: PASS=$PASS FAIL=$FAIL"
[ $FAIL -gt 0 ] && echo "失败项:$FAILED_NAMES"
[ $FAIL -eq 0 ] && echo "ALL GREEN ✅"
