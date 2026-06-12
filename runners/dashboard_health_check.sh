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
echo "## Service status"
if ! systemctl is-active --quiet ai-company-dashboard.service; then
  echo "Dashboard service is not active."
  sudo systemctl status ai-company-dashboard.service --no-pager -l || true
  exit 1
fi

echo "Dashboard service is active."

curl_status() {
  local name="$1"
  local url="$2"
  local output_file="$3"
  shift 3

  local status
  status="$(curl -m 10 -sS -o "$output_file" -w "%{http_code}" "$@" "$url" 2>"$output_file.err" || true)"

  if [ -s "$output_file.err" ]; then
    echo "- $name curl stderr:"
    cat "$output_file.err" || true
  fi

  echo "$status"
}

echo
echo "## API smoke tests"

SUMMARY_STATUS="$(curl_status '/api/summary' "$BASE_URL/api/summary" /tmp/ai-company-dashboard-summary.out)"
SUMMARY_STATUS="$(printf '%s\n' "$SUMMARY_STATUS" | tail -1)"
echo "- /api/summary HTTP $SUMMARY_STATUS"

if [ "$SUMMARY_STATUS" != "200" ]; then
  echo "Failed /api/summary response:"
  cat /tmp/ai-company-dashboard-summary.out || true
  exit 1
fi

TASKS_STATUS="$(curl_status '/api/tasks' "$BASE_URL/api/tasks" /tmp/ai-company-dashboard-tasks.out)"
TASKS_STATUS="$(printf '%s\n' "$TASKS_STATUS" | tail -1)"
echo "- /api/tasks HTTP $TASKS_STATUS"

if [ "$TASKS_STATUS" != "200" ]; then
  echo "Failed /api/tasks response:"
  cat /tmp/ai-company-dashboard-tasks.out || true
  exit 1
fi

OWNER_ENDPOINT_STATUS="$(curl_status '/api/owner/review/accept-finalize' "$BASE_URL/api/owner/review/accept-finalize" /tmp/ai-company-dashboard-owner.out \
  -X POST \
  -H 'Content-Type: application/json' \
  -d '{}')"
OWNER_ENDPOINT_STATUS="$(printf '%s\n' "$OWNER_ENDPOINT_STATUS" | tail -1)"

echo "- /api/owner/review/accept-finalize empty-body HTTP $OWNER_ENDPOINT_STATUS"

if [ "$OWNER_ENDPOINT_STATUS" != "400" ]; then
  echo "Unexpected owner endpoint response:"
  cat /tmp/ai-company-dashboard-owner.out || true
  exit 1
fi

if ! grep -q "Missing review_task_key" /tmp/ai-company-dashboard-owner.out; then
  echo "Owner endpoint did not return expected validation message:"
  cat /tmp/ai-company-dashboard-owner.out || true
  exit 1
fi

echo
echo "Dashboard health check passed."
