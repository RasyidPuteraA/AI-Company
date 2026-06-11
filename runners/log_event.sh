#!/usr/bin/env bash
set -euo pipefail

PROJECT_KEY="${1:-}"
TASK_KEY="${2:-}"
AGENT_KEY="${3:-}"
EVENT_TYPE="${4:-}"
STATE="${5:-}"
LOCATION="${6:-}"
TOPIC="${7:-}"
SUMMARY="${8:-}"

if [ -z "$PROJECT_KEY" ] || [ -z "$TASK_KEY" ] || [ -z "$AGENT_KEY" ] || [ -z "$EVENT_TYPE" ]; then
  echo "Usage: ./runners/log_event.sh <project_key> <task_key> <agent_key> <event_type> <state> <location> <topic> <summary>"
  exit 1
fi

docker exec -i ai_company_postgres psql -U ai_company -d ai_company \
  -v project_key="$PROJECT_KEY" \
  -v task_key="$TASK_KEY" \
  -v agent_key="$AGENT_KEY" \
  -v event_type="$EVENT_TYPE" \
  -v state="$STATE" \
  -v location="$LOCATION" \
  -v topic="$TOPIC" \
  -v summary="$SUMMARY" <<'SQL'
INSERT INTO events (project_id, task_id, agent_key, event_type, state, location, topic, summary)
SELECT
  p.id,
  t.id,
  :'agent_key',
  :'event_type',
  :'state',
  :'location',
  :'topic',
  :'summary'
FROM projects p
LEFT JOIN tasks t ON t.project_id = p.id AND t.task_key = :'task_key'
WHERE p.project_key = :'project_key';
SQL

echo "Event logged: $EVENT_TYPE / $AGENT_KEY / $STATE"
