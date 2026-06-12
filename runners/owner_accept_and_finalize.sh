#!/usr/bin/env bash
set -euo pipefail

PROJECT_KEY="${1:-}"
REVIEW_TASK_KEY="${2:-}"
OWNER_NOTE="${3:-Owner accepted delivery.}"

if [ -z "$PROJECT_KEY" ] || [ -z "$REVIEW_TASK_KEY" ]; then
  echo "Usage:"
  echo "  $0 <project_key> <review_task_key> [owner_note]"
  echo
  echo "Example:"
  echo "  $0 client-automation-consulting-demo CLIENT-2-REVIEW-001 \"Owner accepted delivery.\""
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
