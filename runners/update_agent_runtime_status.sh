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
  exit 1
fi

SQL_ESCAPE() {
  printf "%s" "$1" | sed "s/'/''/g"
}

AGENT_KEY_SQL="$(SQL_ESCAPE "$AGENT_KEY")"
RUNTIME_STATUS_SQL="$(SQL_ESCAPE "$RUNTIME_STATUS")"
CURRENT_TASK_KEY_SQL="$(SQL_ESCAPE "$CURRENT_TASK_KEY")"
LOCATION_SQL="$(SQL_ESCAPE "$LOCATION")"
STATUS_NOTE_SQL="$(SQL_ESCAPE "$STATUS_NOTE")"

docker exec ai_company_postgres \
  psql -U ai_company -d ai_company -P pager=off -c "
INSERT INTO agent_runtime_status (
  agent_key,
  runtime_status,
  current_task_key,
  location,
  status_note,
  updated_at
)
VALUES (
  '$AGENT_KEY_SQL',
  '$RUNTIME_STATUS_SQL',
  NULLIF('$CURRENT_TASK_KEY_SQL', ''),
  '$LOCATION_SQL',
  '$STATUS_NOTE_SQL',
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
