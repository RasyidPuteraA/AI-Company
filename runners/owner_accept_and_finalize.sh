#!/usr/bin/env bash
set -euo pipefail

FIRST="${1:-}"
SECOND="${2:-}"
THIRD="${3:-}"

if [ -z "$FIRST" ]; then
  echo "Usage:"
  echo "  $0 <project_key> <review_task_key> [owner_note]"
  echo "  $0 <review_task_key> [owner_note]"
  echo
  echo "Example:"
  echo "  $0 client-automation-consulting-demo CLIENT-2-REVIEW-001 \"Owner accepted delivery.\""
  echo "  $0 CLIENT-2-REVIEW-001 \"Owner accepted delivery.\""
  exit 1
fi

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

lookup_project_key() {
  local review_task_key="$1"
  local review_sql
  review_sql="$(sql_escape "$review_task_key")"

  docker exec -i ai_company_postgres \
    psql -U ai_company -d ai_company -t -A <<SQL
SELECT p.project_key
FROM tasks t
JOIN projects p ON p.id = t.project_id
WHERE t.task_key = '$review_sql'
LIMIT 1;
SQL
}

if [[ "$FIRST" == CLIENT-*REVIEW* ]] || [ -z "$SECOND" ]; then
  REVIEW_TASK_KEY="$FIRST"
  OWNER_NOTE="${SECOND:-Owner accepted delivery.}"
  PROJECT_KEY="$(lookup_project_key "$REVIEW_TASK_KEY" | tr -d '[:space:]')"
else
  PROJECT_KEY="$FIRST"
  REVIEW_TASK_KEY="$SECOND"
  OWNER_NOTE="${THIRD:-Owner accepted delivery.}"
fi

if [ -z "$PROJECT_KEY" ] || [ -z "$REVIEW_TASK_KEY" ]; then
  echo "Could not resolve project_key or review_task_key."
  echo "- project_key: ${PROJECT_KEY:-}"
  echo "- review_task_key: ${REVIEW_TASK_KEY:-}"
  exit 1
fi

echo "# Owner Accept and Finalize"
echo "- Project: $PROJECT_KEY"
echo "- Review task: $REVIEW_TASK_KEY"

./runners/owner_review_decision.sh \
  "$REVIEW_TASK_KEY" \
  ACCEPT \
  "$OWNER_NOTE"

./runners/finalize_accepted_project.sh \
  "$PROJECT_KEY" \
  "$REVIEW_TASK_KEY"

./runners/log_event.sh \
  "$PROJECT_KEY" \
  "$REVIEW_TASK_KEY" \
  owner \
  owner_accept_finalize_completed \
  COMPLETED \
  owner_inbox \
  "Owner accepted and project finalized" \
  "$OWNER_NOTE" || true

./runners/generate_daily_report.sh

echo
echo "Owner accept + finalize completed:"
echo "- Project: $PROJECT_KEY"
echo "- Review task: $REVIEW_TASK_KEY"
