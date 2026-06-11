#!/usr/bin/env bash
set -euo pipefail

echo "# AI Company OS Company Status"
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

run_query "Task Health Summary" "
SELECT
  COUNT(*) FILTER (WHERE task_key NOT LIKE 'INTERNAL-%') AS client_tasks,
  COUNT(*) FILTER (WHERE task_key LIKE 'INTERNAL-%') AS internal_tasks,
  COUNT(*) FILTER (WHERE status = 'WAITING_OWNER_ACCEPTANCE') AS waiting_owner,
  COUNT(*) FILTER (WHERE status = 'ACCEPTED') AS accepted,
  COUNT(*) FILTER (WHERE status = 'DONE') AS done,
  COUNT(*) FILTER (WHERE status IN ('QA_FAILED', 'NEEDS_REVISION', 'BLOCKED')) AS needs_attention
FROM tasks;
"

run_query "Client Task Status" "
SELECT
  task_key,
  title,
  status,
  COALESCE(assigned_agent_key, '') AS agent
FROM tasks
WHERE task_key NOT LIKE 'INTERNAL-%'
ORDER BY id DESC;
"

run_query "Internal Development Status" "
SELECT
  task_key,
  title,
  status
FROM tasks
WHERE task_key LIKE 'INTERNAL-%'
ORDER BY id DESC
LIMIT 12;
"

run_query "Owner Attention Queue" "
SELECT
  task_key,
  title,
  status,
  COALESCE(handover_note, '') AS note
FROM tasks
WHERE status IN ('WAITING_OWNER_ACCEPTANCE', 'QA_FAILED', 'NEEDS_REVISION', 'BLOCKED')
ORDER BY updated_at DESC, id DESC;
"

run_query "Latest Accepted Deliveries" "
SELECT
  task_key,
  title,
  status,
  COALESCE(handover_note, '') AS owner_note,
  updated_at
FROM tasks
WHERE status = 'ACCEPTED'
ORDER BY updated_at DESC, id DESC
LIMIT 5;
"

run_query "Latest Agent Events" "
SELECT
  event_type,
  agent_key,
  state,
  location,
  topic,
  created_at
FROM events
ORDER BY id DESC
LIMIT 12;
"

echo "## Suggested Commands"
echo
echo "Owner inbox:"
echo "./runners/owner_inbox.sh"
echo
echo "Daily report:"
echo "./runners/generate_daily_report.sh && cat company/reports/daily/\$(date +%F)-daily-report.md"
echo
echo "Accept task:"
echo "./runners/owner_review_task.sh TASK-KEY ACCEPT \"Owner accepted this delivery.\""
echo
echo "Request revision:"
echo "./runners/owner_review_task.sh TASK-KEY REVISION \"Owner requested these changes: ...\""
