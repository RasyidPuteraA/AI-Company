#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:---dry-run}"

if [ "$MODE" != "--dry-run" ] && [ "$MODE" != "--once" ]; then
  echo "Usage: $0 [--dry-run|--once]"
  exit 1
fi

psql_scalar() {
  docker exec ai_company_postgres psql -U ai_company -d ai_company -At -c "$1" | head -1 | tr -d '[:space:]'
}

owner_pending="$(psql_scalar "SELECT count(*) FROM tasks WHERE status IN ('WAITING_OWNER_ACCEPTANCE','NEEDS_REVISION','QA_FAILED','BLOCKED');")"
active_client="$(psql_scalar "SELECT count(*) FROM tasks WHERE (task_key LIKE 'CLIENT-%' OR task_key LIKE 'TASK-%') AND status IN ('TODO','IN_PROGRESS','WAITING_OWNER_ACCEPTANCE','NEEDS_REVISION','QA_FAILED','BLOCKED');")"

echo "# Idle Internal Improvement Planner"
echo "Mode: $MODE"
echo "Owner pending: $owner_pending"
echo "Active client work: $active_client"

if [ "$owner_pending" -gt 0 ]; then
  echo "Idle planning skipped: Owner attention is required."
  exit 0
fi

if [ "$active_client" -gt 0 ]; then
  echo "Idle planning skipped: active client work exists."
  exit 0
fi

NEXT_LINE=""

while IFS='|' read -r KEY TITLE DESCRIPTION PRIORITY AGENT PHASE SAFETY; do
  [ -z "${KEY:-}" ] && continue
  EXISTS="$(psql_scalar "SELECT count(*) FROM tasks WHERE task_key='${KEY}';")"
  if [ "$EXISTS" -eq 0 ]; then
    NEXT_LINE="$KEY|$TITLE|$DESCRIPTION|$PRIORITY|$AGENT|$PHASE|$SAFETY"
    break
  fi
done <<'CANDIDATES'
INTERNAL-065|Add Stale Internal Task Recovery Guard|Add a safe guard that detects stale internal IN_PROGRESS tasks and reports them for owner or agent follow-up.|HIGH|devops_agent|operations|safe
INTERNAL-066|Add Report Index Runner|Add a report index runner that lists latest daily, 3-day, and weekly reports for meetings.|MEDIUM|pm_agent|reporting|safe
INTERNAL-067|Add Idle Planner Dashboard Visibility|Show idle planner status and next suggested internal task on the dashboard.|MEDIUM|engineer_agent|dashboard|safe
INTERNAL-068|Add Backup Readiness Check|Add a safe backup readiness check for repo, database, reports, and dashboard configuration.|HIGH|devops_agent|operations|safe
CANDIDATES

if [ -z "$NEXT_LINE" ]; then
  echo "No predefined idle improvement candidate remains."
  exit 0
fi

IFS='|' read -r KEY TITLE DESCRIPTION PRIORITY AGENT PHASE SAFETY <<< "$NEXT_LINE"

echo "Next idle improvement candidate:"
echo "- Task: $KEY"
echo "- Title: $TITLE"
echo "- Agent: $AGENT"
echo "- Priority: $PRIORITY"

if [ "$MODE" = "--dry-run" ]; then
  echo "Dry-run only. No task created."
  exit 0
fi

./runners/create_internal_task.sh "$KEY" "$TITLE" "$DESCRIPTION" "$PRIORITY" "$AGENT" "$PHASE" "$SAFETY"

echo "Created idle improvement task: $KEY"
