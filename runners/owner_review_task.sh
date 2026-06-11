#!/usr/bin/env bash
set -euo pipefail

TASK_KEY="${1:-}"
ACTION="${2:-}"
NOTE="${3:-}"

if [ -z "$TASK_KEY" ] || [ -z "$ACTION" ]; then
  echo "Usage:"
  echo "  ./runners/owner_review_task.sh <task_key> ACCEPT [note]"
  echo "  ./runners/owner_review_task.sh <task_key> REVISION [note]"
  exit 1
fi

ACTION_UPPER="$(echo "$ACTION" | tr '[:lower:]' '[:upper:]')"

case "$ACTION_UPPER" in
  ACCEPT)
    NEW_STATUS="ACCEPTED"
    EVENT_TYPE="owner_accepted"
    EVENT_STATE="ACCEPTED"
    DEFAULT_NOTE="Owner accepted the completed task."
    ;;
  REVISION|REJECT|REJECTED)
    NEW_STATUS="NEEDS_REVISION"
    EVENT_TYPE="owner_requested_revision"
    EVENT_STATE="NEEDS_REVISION"
    DEFAULT_NOTE="Owner requested revision."
    ;;
  *)
    echo "Invalid action: $ACTION"
    echo "Use ACCEPT or REVISION"
    exit 1
    ;;
esac

if [ -z "$NOTE" ]; then
  NOTE="$DEFAULT_NOTE"
fi

PROJECT_KEY="$(
  docker exec ai_company_postgres \
    psql -U ai_company -d ai_company -t -A -c \
    "SELECT p.project_key FROM tasks t JOIN projects p ON p.id = t.project_id WHERE t.task_key = '$TASK_KEY' LIMIT 1;" \
  | tr -d '[:space:]'
)"

if [ -z "$PROJECT_KEY" ]; then
  echo "Task not found or project not found: $TASK_KEY"
  exit 1
fi

./runners/update_task_status.sh "$TASK_KEY" "$NEW_STATUS" "$NOTE"

./runners/log_event.sh \
  "$PROJECT_KEY" \
  "$TASK_KEY" \
  "pm_agent" \
  "$EVENT_TYPE" \
  "$EVENT_STATE" \
  "owner_office" \
  "Owner review completed" \
  "$NOTE"

echo "Owner review recorded:"
echo "- Task: $TASK_KEY"
echo "- Project: $PROJECT_KEY"
echo "- Status: $NEW_STATUS"
echo "- Note: $NOTE"
