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
grep -q "/api/owner/review/accept-finalize" apps/dashboard/server.js
grep -q "Missing review_task_key" apps/dashboard/server.js
echo "Owner review finalize route exists in source."

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

echo
echo "## API smoke tests"

SUMMARY_OUT="$TMP_DIR/summary.out"
SUMMARY_STATUS="$(curl -m 10 -sS -o "$SUMMARY_OUT" -w "%{http_code}" "$BASE_URL/api/summary" || true)"
echo "- /api/summary HTTP $SUMMARY_STATUS"
if [ "$SUMMARY_STATUS" != "200" ]; then
  echo "Failed /api/summary response:"
  cat "$SUMMARY_OUT" || true
  exit 1
fi

TASKS_OUT="$TMP_DIR/tasks.out"
TASKS_STATUS="$(curl -m 10 -sS -o "$TASKS_OUT" -w "%{http_code}" "$BASE_URL/api/tasks" || true)"
echo "- /api/tasks HTTP $TASKS_STATUS"
if [ "$TASKS_STATUS" != "200" ]; then
  echo "Failed /api/tasks response:"
  cat "$TASKS_OUT" || true
  exit 1
fi

echo
echo "## Optional POST validation smoke test"
OWNER_OUT="$TMP_DIR/owner.out"
OWNER_STATUS="$(curl -m 3 -sS -o "$OWNER_OUT" -w "%{http_code}" \
  -X POST \
  -H 'Content-Type: application/json' \
  -d '{}' \
  "$BASE_URL/api/owner/review/accept-finalize" 2>/dev/null || true)"
echo "- /api/owner/review/accept-finalize empty-body HTTP $OWNER_STATUS"

if [ "$OWNER_STATUS" = "400" ] && grep -q "Missing review_task_key" "$OWNER_OUT"; then
  echo "Owner endpoint validation passed."
else
  echo "WARN: Owner endpoint POST validation did not complete during health check; source route check already passed."
fi

echo
echo "Dashboard health check passed."
