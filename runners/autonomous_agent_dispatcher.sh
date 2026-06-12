#!/usr/bin/env bash
set -euo pipefail

AGENT="${1:-}"

if [ -z "$AGENT" ]; then
  echo "Usage: $0 AGENT_KEY"
  exit 1
fi

if [ "${AI_COMPANY_AGENT_EMERGENCY_STOP:-0}" = "1" ]; then
  echo "EMERGENCY STOP active. Dispatcher halted."
  exit 0
fi

LOCK_DIR="/tmp/ai-company-dispatch-${AGENT}.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Dispatcher already running for $AGENT"
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

PSQL=(docker exec -i ai_company_postgres psql -U ai_company -d ai_company -t -A -F $'\t')

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

AGENT_SQL="$(sql_escape "$AGENT")"

TASK_ROW="$("${PSQL[@]}" <<SQL
SELECT
  t.task_key,
  COALESCE(p.project_key, 'internal-ai-company-os') AS project_key,
  t.title
FROM tasks t
LEFT JOIN projects p ON p.id = t.project_id
WHERE t.assigned_agent_key = '$AGENT_SQL'
  AND t.status = 'IN_PROGRESS'
ORDER BY t.updated_at DESC NULLS LAST, t.created_at DESC NULLS LAST, t.id DESC
LIMIT 1;
SQL
)"

if [ -z "$TASK_ROW" ]; then
  echo "No IN_PROGRESS task to dispatch for $AGENT"
  exit 0
fi

IFS=$'\t' read -r TASK_KEY PROJECT_KEY TITLE <<< "$TASK_ROW"

echo "# Autonomous Dispatcher"
echo "- Agent: $AGENT"
echo "- Task: $TASK_KEY"
echo "- Project: $PROJECT_KEY"
echo "- Title: $TITLE"

mkdir -p company/runtime/agent-dispatches

MARKER="company/runtime/agent-dispatches/${TASK_KEY}.done"
if [ -f "$MARKER" ]; then
  echo "Task already dispatched successfully before: $TASK_KEY"
  exit 0
fi

mark_success() {
  local note="$1"
  local command_text="$2"

  date -Is > "$MARKER"

  ./runners/log_event.sh \
    "${PROJECT_KEY:-internal-ai-company-os}" \
    "$TASK_KEY" \
    "$AGENT" \
    "task_dispatched" \
    "DONE" \
    "autonomous_dispatcher" \
    "$note" \
    "Dispatcher completed command: $command_text" || true

  echo "Dispatch completed: $TASK_KEY"
}

mark_failed() {
  local note="$1"
  local command_text="$2"

  ./runners/log_event.sh \
    "${PROJECT_KEY:-internal-ai-company-os}" \
    "$TASK_KEY" \
    "$AGENT" \
    "task_dispatch_failed" \
    "FAILED" \
    "autonomous_dispatcher" \
    "$note failed" \
    "Dispatcher command failed: $command_text" || true

  exit 1
}

run_runner() {
  local note="$1"
  local runner="$2"

  echo "Dispatch command: $runner $PROJECT_KEY $TASK_KEY"

  if "$runner" "$PROJECT_KEY" "$TASK_KEY"; then
    mark_success "$note" "$runner $PROJECT_KEY $TASK_KEY"
    return 0
  fi

  echo "Primary signature failed. Trying fallback: $runner $TASK_KEY"

  if "$runner" "$TASK_KEY"; then
    mark_success "$note" "$runner $TASK_KEY"
    return 0
  fi

  mark_failed "$note" "$runner $PROJECT_KEY $TASK_KEY OR $runner $TASK_KEY"
}

case "$AGENT:$TASK_KEY" in
  pm_agent:CLIENT-*-001)
    run_runner "PM intake dispatched" ./runners/pm_intake_processor.sh

    ./runners/generate_tasks_from_pm_analysis.sh "$PROJECT_KEY" "$TASK_KEY" \
      || ./runners/generate_tasks_from_pm_analysis.sh "$TASK_KEY" \
      || true

    ./runners/update_task_status.sh "$TASK_KEY" DONE "PM intake completed by autonomous dispatcher." || true
    ;;

  engineer_agent:CLIENT-*-ENG-*)
    run_runner "Engineer implementation dispatched" ./runners/engineer_implementation_runner.sh
    ;;

  qa_agent:CLIENT-*-QA-*)
    run_runner "QA verification dispatched" ./runners/qa_verification_runner.sh

    ./runners/submit_project_to_owner_review.sh "$PROJECT_KEY" "$TASK_KEY" \
      || ./runners/submit_project_to_owner_review.sh "$TASK_KEY" \
      || true
    ;;

  *)
    echo "No autonomous execution rule for $AGENT / $TASK_KEY"
    echo "Leaving task unchanged for manual or future dispatcher support."
    ;;
esac
