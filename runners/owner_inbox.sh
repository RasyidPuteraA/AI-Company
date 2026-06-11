#!/usr/bin/env bash
set -euo pipefail

echo "# AI Company OS Owner Inbox"
echo
echo "Generated at: $(date)"
echo

run_query() {
  local title="$1"
  local sql="$2"

  echo "## $title"
  echo
  docker exec ai_company_postgres \
    psql -U ai_company -d ai_company -P pager=off -c "$sql"
  echo
}

run_query "Waiting Owner Acceptance" "
SELECT
  task_key,
  title,
  status,
  COALESCE(handover_note, '') AS handover_note
FROM tasks
WHERE status = 'WAITING_OWNER_ACCEPTANCE'
ORDER BY updated_at DESC, id DESC;
"

run_query "Needs Revision / QA Failed / Blocked" "
SELECT
  task_key,
  title,
  status,
  COALESCE(handover_note, '') AS handover_note
FROM tasks
WHERE status IN ('NEEDS_REVISION', 'QA_FAILED', 'BLOCKED')
ORDER BY updated_at DESC, id DESC;
"

run_query "Recently Accepted" "
SELECT
  task_key,
  title,
  status,
  COALESCE(handover_note, '') AS owner_note,
  updated_at
FROM tasks
WHERE status = 'ACCEPTED'
ORDER BY updated_at DESC, id DESC
LIMIT 10;
"

run_query "Internal Development Status" "
SELECT
  task_key,
  title,
  status,
  COALESCE(handover_note, '') AS handover_note
FROM tasks
WHERE task_key LIKE 'INTERNAL-%'
ORDER BY id DESC
LIMIT 10;
"

echo "## Suggested Owner Commands"
echo
echo "Accept a delivery:"
echo "./runners/owner_review_task.sh TASK-KEY ACCEPT \"Owner accepted this delivery.\""
echo
echo "Request revision:"
echo "./runners/owner_review_task.sh TASK-KEY REVISION \"Owner requested these changes: ...\""
echo
echo "Regenerate daily report:"
echo "./runners/generate_daily_report.sh"
