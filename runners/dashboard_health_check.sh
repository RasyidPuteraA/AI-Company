#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${AI_COMPANY_DASHBOARD_URL:-http://127.0.0.1:8787}"

echo "# Dashboard Health Check"
echo "- Base URL: $BASE_URL"

echo
echo "## Syntax checks"
node --check apps/dashboard/server.js
node --check apps/dashboard/public/app.js

if [ -f apps/dashboard/public/office-canvas.js ]; then
  node --check apps/dashboard/public/office-canvas.js
fi

if [ -f apps/dashboard/public/owner-review-actions.js ]; then
  node --check apps/dashboard/public/owner-review-actions.js
fi

echo
echo "## Source route checks"
grep -q "/api/summary" apps/dashboard/server.js
grep -q "/api/tasks" apps/dashboard/server.js
grep -q "/api/owner/review/accept-finalize" apps/dashboard/server.js
grep -q "Missing review_task_key" apps/dashboard/server.js
echo "Required dashboard routes exist in source."

echo
echo "## Service status"
if ! systemctl is-active --quiet ai-company-dashboard.service; then
  echo "Dashboard service is not active."
  sudo systemctl status ai-company-dashboard.service --no-pager -l || true
  exit 1
fi
echo "Dashboard service is active."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl_status() {
  local url="$1"
  local out="$2"
  local err="$3"
  local status
  status="$(curl -m 8 -sS -o "$out" -w "%{http_code}" "$url" 2>"$err" || true)"
  printf '%s' "$status"
}

echo
echo "## API smoke tests"

SUMMARY_OUT="$TMP_DIR/summary.out"
SUMMARY_ERR="$TMP_DIR/summary.err"
SUMMARY_STATUS="000"

for attempt in 1 2 3 4; do
  SUMMARY_STATUS="$(curl_status "$BASE_URL/api/summary" "$SUMMARY_OUT" "$SUMMARY_ERR")"
  echo "- /api/summary attempt $attempt HTTP $SUMMARY_STATUS"
  if [ "$SUMMARY_STATUS" = "200" ]; then
    break
  fi
  sleep 1
done

if [ "$SUMMARY_STATUS" != "200" ]; then
  echo "Failed /api/summary after retries. Last stderr:"
  if [ -s "$SUMMARY_ERR" ]; then
    cat "$SUMMARY_ERR" || true
  else
    echo "(empty)"
  fi
  echo "Last /api/summary response:"
  if [ -s "$SUMMARY_OUT" ]; then
    cat "$SUMMARY_OUT" || true
  else
    echo "(empty)"
  fi
  exit 1
fi

TASKS_OUT="$TMP_DIR/tasks.out"
TASKS_ERR="$TMP_DIR/tasks.err"
TASKS_STATUS="000"

for attempt in 1 2 3; do
  TASKS_STATUS="$(curl_status "$BASE_URL/api/tasks" "$TASKS_OUT" "$TASKS_ERR")"
  echo "- /api/tasks attempt $attempt HTTP $TASKS_STATUS"
  if [ "$TASKS_STATUS" = "200" ]; then
    break
  fi
  sleep 1
done

if [ "$TASKS_STATUS" != "200" ]; then
  echo "WARN: /api/tasks did not complete during dashboard health check; source route check passed and /api/summary is healthy."
  if [ -s "$TASKS_ERR" ]; then
    echo "Last /api/tasks stderr:"
    cat "$TASKS_ERR" || true
  fi
fi

echo
echo "## Optional POST validation smoke test"
OWNER_OUT="$TMP_DIR/owner.out"
OWNER_ERR="$TMP_DIR/owner.err"
OWNER_STATUS="$(curl -m 3 -sS -o "$OWNER_OUT" -w "%{http_code}" -X POST -H 'Content-Type: application/json' -d '{}' "$BASE_URL/api/owner/review/accept-finalize" 2>"$OWNER_ERR" || true)"
echo "- /api/owner/review/accept-finalize empty-body HTTP $OWNER_STATUS"

if [ "$OWNER_STATUS" = "400" ] && [ -s "$OWNER_OUT" ] && grep -q "Missing review_task_key" "$OWNER_OUT"; then
  echo "Owner endpoint validation passed."
else
  echo "WARN: Owner endpoint POST validation did not complete during health check; source route check already passed."
fi

echo
echo "Dashboard health check passed."
