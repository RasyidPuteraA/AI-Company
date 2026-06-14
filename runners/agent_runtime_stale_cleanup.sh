#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:---dry-run}"
case "$MODE" in
  --dry-run|--apply)
    ;;
  *)
    echo "Usage: ./runners/agent_runtime_stale_cleanup.sh [--dry-run|--apply]" >&2
    exit 2
    ;;
esac

CONFIG_FILE="company/config/ai_company_scheduler.env"
ENV_STALE_AGE_HOURS="${AI_COMPANY_STALE_TASK_AGE_HOURS:-}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG_FILE"
fi
[ -n "$ENV_STALE_AGE_HOURS" ] && AI_COMPANY_STALE_TASK_AGE_HOURS="$ENV_STALE_AGE_HOURS"

: "${AI_COMPANY_STALE_TASK_AGE_HOURS:=24}"

if ! [[ "$AI_COMPANY_STALE_TASK_AGE_HOURS" =~ ^[0-9]+$ ]] || [ "$AI_COMPANY_STALE_TASK_AGE_HOURS" -lt 1 ]; then
  echo "ERROR: AI_COMPANY_STALE_TASK_AGE_HOURS must be a positive integer." >&2
  exit 1
fi

REPORT_DIR="company/reports/stale-task-recovery"
mkdir -p "$REPORT_DIR"
STAMP="$(date +%Y%m%dT%H%M%S%z)"
REPORT="$REPORT_DIR/${STAMP}-agent-runtime-stale-cleanup.md"

agent_lock_name() {
  case "$1" in
    devops_agent) printf "devops" ;;
    qa_agent) printf "qa" ;;
    engineer_agent) printf "repo_write" ;;
    *) printf "" ;;
  esac
}

has_active_lock() {
  local agent="$1"
  local name
  name="$(agent_lock_name "$agent")"
  [ -n "$name" ] && [ -f "company/runtime/locks/${name}.lock.holder" ]
}

{
  echo "# Agent Runtime Stale Cleanup"
  echo
  echo "- generated_at: $(date -Iseconds)"
  echo "- mode: $MODE"
  echo "- threshold_hours: $AI_COMPANY_STALE_TASK_AGE_HOURS"
  echo "- report_path: $REPORT"
  echo
  echo "## Actions"
  echo
} > "$REPORT"

ROWS="$(docker exec ai_company_postgres psql -U ai_company -d ai_company -t -A -F $'\t' -c "
SELECT
  ars.agent_key,
  ars.runtime_status,
  COALESCE(ars.current_task_key, '') AS current_task_key,
  COALESCE(t.status, 'MISSING') AS task_status,
  COALESCE(t.updated_at, ars.updated_at) AS task_updated_at,
  FLOOR(EXTRACT(EPOCH FROM (now() - COALESCE(t.updated_at, ars.updated_at))) / 3600)::int AS task_age_hours,
  ars.updated_at AS runtime_updated_at,
  FLOOR(EXTRACT(EPOCH FROM (now() - ars.updated_at)) / 3600)::int AS runtime_age_hours
FROM agent_runtime_status ars
LEFT JOIN tasks t ON t.task_key = ars.current_task_key
WHERE COALESCE(ars.current_task_key, '') <> ''
ORDER BY ars.agent_key;
")"

changed=0
reviewed=0

if [ -z "$ROWS" ]; then
  echo "No runtime rows with current_task_key found." | tee -a "$REPORT"
else
  while IFS=$'\t' read -r agent runtime_status task_key task_status task_updated_at task_age runtime_updated_at runtime_age; do
    [ -n "$agent" ] || continue
    reviewed=$((reviewed + 1))
    action="no_action"
    reason="runtime still appears active or recent"

    if has_active_lock "$agent"; then
      action="skip_active_lock"
      reason="active lock holder exists"
    elif [[ "$task_status" =~ ^(DONE|ACCEPTED|IMPLEMENTED|QA_PASSED|FAILED|SKIPPED|BLOCKED)$ ]]; then
      action="set_idle_if_apply"
      reason="runtime points at terminal/review task status $task_status"
    elif [ "$task_status" = "MISSING" ]; then
      action="set_idle_if_apply"
      reason="runtime points at missing task"
    elif [ "$task_status" = "IN_PROGRESS" ] && [ "${task_age:-0}" -ge "$AI_COMPANY_STALE_TASK_AGE_HOURS" ] && [ "${runtime_age:-0}" -ge "$AI_COMPANY_STALE_TASK_AGE_HOURS" ]; then
      action="set_idle_if_apply"
      reason="runtime and task are stale IN_PROGRESS"
    fi

    if [ "$MODE" = "--apply" ] && [ "$action" = "set_idle_if_apply" ]; then
      docker exec -i ai_company_postgres psql -U ai_company -d ai_company \
        -v agent_key="$agent" \
        -v note="Stale runtime cleanup cleared ${task_key}; ${reason}." <<'SQL' >/dev/null
UPDATE agent_runtime_status
SET
  runtime_status = 'idle',
  current_task_key = '',
  location = 'system',
  status_note = :'note',
  updated_at = now()
WHERE agent_key = :'agent_key';
SQL
      ./runners/log_event.sh \
        internal-ai-company-os \
        INTERNAL-086 \
        "$agent" \
        agent_runtime_stale_cleanup \
        IDLE \
        operations \
        "Agent runtime stale cleanup" \
        "Cleared stale runtime task ${task_key}; ${reason}." >/dev/null 2>&1 || true
      action="set_idle"
      changed=$((changed + 1))
    fi

    printf -- "- %s | runtime=%s | task=%s | task_status=%s | task_age_hours=%s | runtime_age_hours=%s | action=%s | %s\n" \
      "$agent" "$runtime_status" "$task_key" "$task_status" "$task_age" "$runtime_age" "$action" "$reason" | tee -a "$REPORT"
  done <<< "$ROWS"
fi

echo >> "$REPORT"
echo "## Result" >> "$REPORT"
echo >> "$REPORT"
echo "- reviewed: $reviewed" | tee -a "$REPORT"
echo "- changed: $changed" | tee -a "$REPORT"

./runners/log_event.sh \
  internal-ai-company-os \
  INTERNAL-086 \
  devops_agent \
  agent_runtime_stale_cleanup \
  REPORT_ONLY \
  operations \
  "Agent runtime stale cleanup report" \
  "Runtime stale cleanup completed mode=$MODE reviewed=$reviewed changed=$changed report=$REPORT" >/dev/null 2>&1 || true

echo
echo "Report written: $REPORT"
