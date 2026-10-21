#!/usr/bin/env bash
# E2E business-flow check for Phase B scope (guard order fix + RBAC + existing modules)
# Runs against the locally running API on Windows host + local PostgreSQL 16.
#
# Credentials come from the environment (or pms-eng-api/.env) — never hardcode them here.
#   ADMIN_EMAIL / ADMIN_PASSWORD  — seeded admin account
#   PGUSER / PGPASSWORD / PGDATABASE / PGHOST — local PostgreSQL for SQL assertions
set -u

cd "$(dirname "$0")" || exit 1
if [ -f .env ]; then set -a; . ./.env; set +a; fi

API="${API:-http://127.0.0.1:3000/api}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-}"
PGPASSWORD="${PGPASSWORD:-}"
PGDATABASE="${PGDATABASE:-dreamhigh_pms}"

if [ -z "$ADMIN_PASSWORD" ] || [ -z "$ADMIN_EMAIL" ]; then
  echo "ADMIN_EMAIL và ADMIN_PASSWORD chưa được set — không thể chạy phần kiểm tra RBAC admin." >&2
  exit 2
fi

PASS=0; FAIL=0
declare -a RESULTS

check() { # name expected actual
  local name="$1" exp="$2" act="$3"
  if [ "$exp" = "$act" ]; then
    PASS=$((PASS+1)); RESULTS+=("PASS | $name | expected=$exp actual=$act")
  else
    FAIL=$((FAIL+1)); RESULTS+=("FAIL | $name | expected=$exp actual=$act")
  fi
}

code() { curl -sS -o /dev/null -w "%{http_code}" "$@"; }
psql_q() { PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -tAc "$1"; }

STAMP=$(date +%s)
EMAIL="e2e.phaseb.${STAMP}@dreamhigh.vn"
PASSWD='DreamHigh123@'

echo "### A. Guard order / auth (X-TC-01, 1.1-TC-03/04)"
check "1.1-TC-03 no token -> 401"        401 "$(code $API/users)"
check "1.1-TC-03 bad token -> 401"       401 "$(code -H 'Authorization: Bearer bad.tok.en' $API/users)"
check "1.1-TC-04 no token /categories"   401 "$(code $API/categories/programs)"
check "X-TC-01 no token /students"       401 "$(code $API/students)"
check "X-TC-01 no token /enrollment"     401 "$(code -X POST -H 'Content-Type: application/json' -d '{}' $API/enrollment/placement-test)"
check "health public -> 200"             200 "$(code $API/health)"

echo "### B. Register + login"
REG=$(curl -sS -w "\n%{http_code}" -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"fullName\":\"E2E Phase B\",\"password\":\"$PASSWD\"}")
REGC=$(echo "$REG" | tail -1)
check "1.1-TC-01 register valid -> 201"   201 "$REGC"
REG_BODY=$(echo "$REG" | head -n -1)
echo "$REG_BODY" | grep -q "passwordHash" && HASHLEAK=1 || HASHLEAK=0
check "1.1-TC-01 no passwordHash leaked" 0 "$HASHLEAK"

DUP=$(code -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"fullName\":\"Dup\",\"password\":\"$PASSWD\"}")
check "1.1-TC-02 duplicate email -> 400" 400 "$DUP"

WEAK=$(code -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d "{\"email\":\"weak.${STAMP}@dreamhigh.vn\",\"fullName\":\"W\",\"password\":\"123\"}")
check "1.1-TC-02 weak password -> 400"    400 "$WEAK"

LOGIN=$(curl -sS -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWD\"}")
TOKEN=$(echo "$LOGIN" | sed -n 's/.*"accessToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$TOKEN" ] && TOKOK=1 || TOKOK=0
check "1.1-TC-03 login correct -> token"  1 "$TOKOK"
echo "$LOGIN" | grep -q "passwordHash" && HASHLEAK2=1 || HASHLEAK2=0
check "1.1-TC-01 login no passwordHash"  0 "$HASHLEAK2"

BADPWD=$(code -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"WrongPass123@\"}")
check "1.1-TC-04 login wrong pwd -> 401" 401 "$BADPWD"

echo "### C. Authenticated access + RBAC"
PROF=$(code -H "Authorization: Bearer $TOKEN" $API/users/profile)
check "1.1-TC-09 profile -> 200"          200 "$PROF"

LISTUSERS=$(code -H "Authorization: Bearer $TOKEN" $API/users)
check "1.1-TC-11 non-ADMIN /users -> 403" 403 "$LISTUSERS"

STATS=$(code -H "Authorization: Bearer $TOKEN" $API/students)
check "RBAC role-less user /students -> 403" 403 "$STATS"

CLASS404=$(code -H "Authorization: Bearer $TOKEN" $API/classes/NO_SUCH_CLASS)
check "4.1-TC-01 class missing -> 404"    404 "$CLASS404"

echo "### D. Phase B (2.3 Schedule/Session) endpoints"
for p in "sessions/my-schedule" "sessions" "reports/teaching-hours" "classes/1/sessions/generate"; do
  R=$(code -H "Authorization: Bearer $TOKEN" -X GET "$API/$p")
  check "PhaseB GET /$p -> 404 (not built)" 404 "$R"
done

echo "### E. Phase B schema support (prisma)"
export PATH="/c/Program Files/PostgreSQL/16/bin:$PATH"
TBL=$(psql_q "select count(*) from information_schema.tables where table_name='sessions';")
check "B1 sessions table exists"          1 "$TBL"
IDX=$(psql_q "select count(*) from pg_indexes where tablename='sessions' and indexdef like '%start_time%';")
echo "INFO sessions indexes containing start_time: $IDX"

echo "### F. Admin RBAC + credential leak (4.1-TC-04)"
ALOGIN=$(curl -sS -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")
ATOKEN=$(echo "$ALOGIN" | sed -n 's/.*"accessToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$ATOKEN" ] && ATOK=1 || ATOK=0
check "admin login -> token"              1 "$ATOK"
check "admin /users -> 200"               200 "$(code -H "Authorization: Bearer $ATOKEN" $API/users)"
check "admin /students -> 200"            200 "$(code -H "Authorization: Bearer $ATOKEN" $API/students)"
check "admin /leads -> 200"               200 "$(code -H "Authorization: Bearer $ATOKEN" $API/leads)"
check "admin /audit-logs -> 200"          200 "$(code -H "Authorization: Bearer $ATOKEN" $API/audit-logs)"

CLS=$(psql_q "select class_code from classes limit 1;")
CRESP=$(curl -sS -H "Authorization: Bearer $ATOKEN" "$API/classes/$CLS")
echo "$CRESP" | grep -q "passwordHash" && LEAK1=1 || LEAK1=0
echo "$CRESP" | grep -q "googleSub"    && LEAK2=1 || LEAK2=0
check "4.1-TC-04 no passwordHash in class detail" 0 "$LEAK1"
check "4.1-TC-04 no googleSub in class detail"    0 "$LEAK2"

echo
echo "===== RESULTS ====="
for r in "${RESULTS[@]}"; do echo "$r"; done
echo "---------------------"
echo "PASS: $PASS   FAIL: $FAIL"
echo "TEST_EMAIL=$EMAIL"
exit $([ "$FAIL" -eq 0 ] && echo 0 || echo 1)
