#!/usr/bin/env bash
set -euo pipefail

AGENT_KEY="${1:-}"

if [ -z "$AGENT_KEY" ]; then
  echo "Usage:"
  echo "  ./runners/agent_queue.sh <agent_key>"
  echo
  echo "Examples:"
  echo "  ./runners/agent_queue.sh engineer_agent"
  echo "  ./runners/agent_queue.sh qa_agent"
  echo "  ./runners/agent_queue.sh devops_agent"
  exit 1
fi

echo "# Agent Queue: $AGENT_KEY"
echo
echo "Generated at: $(date)"
echo

docker exec ai_company_postgres \
  psql -U ai_company -d ai_company -P pager=off -c "
SELECT
  task_key,
  title,
  status,
  current_phase,
  priority,
  COALESCE(handover_note, '') AS handover_note,
  updated_at
FROM tasks
WHERE assigned_agent_key = '$AGENT_KEY'
ORDER BY
  CASE
    WHEN status IN ('TODO', 'INTERNAL_BACKLOG', 'NEEDS_REVISION', 'QA_FAILED') THEN 0
    WHEN status = 'IN_PROGRESS' THEN 1
    WHEN status = 'WAITING_OWNER_ACCEPTANCE' THEN 2
    ELSE 3
  END,
  priority DESC NULLS LAST,
  id DESC;
"
