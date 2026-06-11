#!/usr/bin/env bash
set -euo pipefail

AGENT_KEY="${1:-}"

if [ -z "$AGENT_KEY" ]; then
  echo "Usage:"
  echo "  ./runners/claim_next_task.sh <agent_key>"
  echo
  echo "Examples:"
  echo "  ./runners/claim_next_task.sh engineer_agent"
  echo "  ./runners/claim_next_task.sh qa_agent"
  echo "  ./runners/claim_next_task.sh devops_agent"
  exit 1
fi

CLAIM_OUTPUT="$(
docker exec ai_company_postgres \
  psql -U ai_company -d ai_company -t -A -F '|' -c "
WITH candidate AS (
  SELECT id
  FROM tasks
  WHERE assigned_agent_key = '$AGENT_KEY'
    AND status IN ('TODO', 'INTERNAL_BACKLOG', 'NEEDS_REVISION', 'QA_FAILED')
  ORDER BY priority DESC NULLS LAST, id ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED
)
UPDATE tasks
SET
  status = 'IN_PROGRESS',
  updated_at = now(),
  handover_note = 'Claimed by $AGENT_KEY at ' || now()
FROM candidate
WHERE tasks.id = candidate.id
RETURNING task_key, title;
"
)"

CLAIM_OUTPUT="$(
  echo "$CLAIM_OUTPUT"     | grep '|'     | grep -v '^UPDATE '     | head -n 1     || true
)"

if [ -z "$CLAIM_OUTPUT" ]; then
  echo "No claimable task for agent: $AGENT_KEY"
  exit 0
fi

TASK_KEY="$(echo "$CLAIM_OUTPUT" | cut -d '|' -f 1)"
TASK_TITLE="$(echo "$CLAIM_OUTPUT" | cut -d '|' -f 2-)"

if [ -z "$TASK_KEY" ] || [[ "$TASK_KEY" == UPDATE* ]]; then
  echo "No claimable task for agent: $AGENT_KEY"
  exit 0
fi

PROJECT_KEY="$(
  docker exec ai_company_postgres \
    psql -U ai_company -d ai_company -t -A -c \
    "SELECT p.project_key FROM tasks t JOIN projects p ON p.id = t.project_id WHERE t.task_key = '$TASK_KEY' LIMIT 1;" \
  | tr -d '[:space:]'
)"

if [ -z "$PROJECT_KEY" ]; then
  PROJECT_KEY="unknown-project"
fi

./runners/log_event.sh \
  "$PROJECT_KEY" \
  "$TASK_KEY" \
  "$AGENT_KEY" \
  "task_claimed" \
  "IN_PROGRESS" \
  "agent_queue" \
  "Task claimed by $AGENT_KEY" \
  "$AGENT_KEY claimed $TASK_KEY: $TASK_TITLE"

echo "Task claimed:"
echo "- Agent: $AGENT_KEY"
echo "- Project: $PROJECT_KEY"
echo "- Task: $TASK_KEY"
echo "- Title: $TASK_TITLE"
