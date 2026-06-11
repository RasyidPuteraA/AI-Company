#!/usr/bin/env bash
set -euo pipefail

TASK_KEY="${1:-}"
STATUS="${2:-}"
HANDOVER_NOTE="${3:-}"

if [ -z "$TASK_KEY" ] || [ -z "$STATUS" ]; then
  echo "Usage: ./runners/update_task_status.sh <task_key> <status> [handover_note]"
  exit 1
fi

docker exec -i ai_company_postgres psql -U ai_company -d ai_company \
  -v task_key="$TASK_KEY" \
  -v status="$STATUS" \
  -v handover_note="$HANDOVER_NOTE" <<'SQL'
UPDATE tasks
SET
  status = :'status',
  updated_at = NOW(),
  handover_note = CASE
    WHEN :'handover_note' = '' THEN handover_note
    ELSE :'handover_note'
  END
WHERE task_key = :'task_key';
SQL

echo "Task updated: $TASK_KEY -> $STATUS"
