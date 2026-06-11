#!/usr/bin/env bash
set -euo pipefail

AGENT_KEY="${1:-}"
RUNTIME_STATUS="${2:-}"
CURRENT_TASK_KEY="${3:-}"
LOCATION="${4:-unknown}"
STATUS_NOTE="${5:-}"

if [ -z "$AGENT_KEY" ] || [ -z "$RUNTIME_STATUS" ]; then
  echo "Usage:"
  echo "  ./runners/update_agent_runtime_status.sh <agent_key> <runtime_status> [task_key] [location] [note]"
  echo
  echo "Examples:"
  echo "  ./runners/update_agent_runtime_status.sh engineer_agent working INTERNAL-019 engineering_desk 'Implementing runtime status tracking.'"
  echo "  ./runners/update_agent_runtime_status.sh engineer_agent idle '' engineering_desk 'No active task.'"
  exit 1
fi

docker exec ai_company_postgres \
  psql -U ai_company -d ai_company \
  -v agent_key="$AGENT_KEY" \
  -v runtime_status="$RUNTIME_STATUS" \
  -v current_task_key="$CURRENT_TASK_KEY" \
  -v location="$LOCATION" \
  -v status_note="$STATUS_NOTE" \
  -c "
INSERT INTO agent_runtime_status (
  agent_key,
  runtime_status,
  current_task_key,
  location,
  status_note,
  updated_at
)
VALUES (
  :'agent_key',
  :'runtime_status',
  NULLIF(:'current_task_key', ''),
  :'location',
  :'status_note',
  now()
)
ON CONFLICT (agent_key)
DO UPDATE SET
  runtime_status = EXCLUDED.runtime_status,
  current_task_key = EXCLUDED.current_task_key,
  location = EXCLUDED.location,
  status_note = EXCLUDED.status_note,
  updated_at = now();
"

echo "Agent runtime status updated:"
echo "- Agent: $AGENT_KEY"
echo "- Status: $RUNTIME_STATUS"
echo "- Task: ${CURRENT_TASK_KEY:-none}"
echo "- Location: $LOCATION"
