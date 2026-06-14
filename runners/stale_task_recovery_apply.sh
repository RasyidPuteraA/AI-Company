#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:---dry-run}"
case "$MODE" in
  --dry-run|--apply-safe-internal|--apply-safe-auto|--apply-client-review-note)
    ;;
  *)
    echo "Usage: ./runners/stale_task_recovery_apply.sh [--dry-run|--apply-safe-internal|--apply-safe-auto|--apply-client-review-note]" >&2
    exit 2
    ;;
esac

CONFIG_FILE="company/config/ai_company_scheduler.env"
ENV_STALE_ENABLED="${AI_COMPANY_STALE_TASK_RECOVERY_ENABLED:-}"
ENV_STALE_AGE_HOURS="${AI_COMPANY_STALE_TASK_AGE_HOURS:-}"
ENV_AUTO_APPLY_INTERNAL="${AI_COMPANY_STALE_TASK_AUTO_APPLY_INTERNAL:-}"
ENV_AUTO_APPLY_AUTO="${AI_COMPANY_STALE_TASK_AUTO_APPLY_AUTO:-}"
ENV_CLIENT_REPORT_ONLY="${AI_COMPANY_STALE_TASK_CLIENT_REPORT_ONLY:-}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG_FILE"
fi
[ -n "$ENV_STALE_ENABLED" ] && AI_COMPANY_STALE_TASK_RECOVERY_ENABLED="$ENV_STALE_ENABLED"
[ -n "$ENV_STALE_AGE_HOURS" ] && AI_COMPANY_STALE_TASK_AGE_HOURS="$ENV_STALE_AGE_HOURS"
[ -n "$ENV_AUTO_APPLY_INTERNAL" ] && AI_COMPANY_STALE_TASK_AUTO_APPLY_INTERNAL="$ENV_AUTO_APPLY_INTERNAL"
[ -n "$ENV_AUTO_APPLY_AUTO" ] && AI_COMPANY_STALE_TASK_AUTO_APPLY_AUTO="$ENV_AUTO_APPLY_AUTO"
[ -n "$ENV_CLIENT_REPORT_ONLY" ] && AI_COMPANY_STALE_TASK_CLIENT_REPORT_ONLY="$ENV_CLIENT_REPORT_ONLY"

: "${AI_COMPANY_STALE_TASK_RECOVERY_ENABLED:=1}"
: "${AI_COMPANY_STALE_TASK_AGE_HOURS:=24}"
: "${AI_COMPANY_STALE_TASK_AUTO_APPLY_INTERNAL:=0}"
: "${AI_COMPANY_STALE_TASK_AUTO_APPLY_AUTO:=0}"
: "${AI_COMPANY_STALE_TASK_CLIENT_REPORT_ONLY:=1}"

if [ "$AI_COMPANY_STALE_TASK_RECOVERY_ENABLED" != "1" ]; then
  echo "Stale task recovery is disabled by AI_COMPANY_STALE_TASK_RECOVERY_ENABLED."
  exit 0
fi

if ! [[ "$AI_COMPANY_STALE_TASK_AGE_HOURS" =~ ^[0-9]+$ ]] || [ "$AI_COMPANY_STALE_TASK_AGE_HOURS" -lt 1 ]; then
  echo "ERROR: AI_COMPANY_STALE_TASK_AGE_HOURS must be a positive integer." >&2
  exit 1
fi

if [ "$MODE" = "--apply-safe-internal" ] && [ "$AI_COMPANY_STALE_TASK_AUTO_APPLY_INTERNAL" != "1" ]; then
  echo "ERROR: internal apply is disabled. Set AI_COMPANY_STALE_TASK_AUTO_APPLY_INTERNAL=1 for this command." >&2
  exit 2
fi

if [ "$MODE" = "--apply-safe-auto" ] && [ "$AI_COMPANY_STALE_TASK_AUTO_APPLY_AUTO" != "1" ]; then
  echo "ERROR: AUTO apply is disabled. Set AI_COMPANY_STALE_TASK_AUTO_APPLY_AUTO=1 for this command." >&2
  exit 2
fi

REPORT_DIR="company/reports/stale-task-recovery"
mkdir -p "$REPORT_DIR"
STAMP="$(date +%Y%m%dT%H%M%S%z)"
REPORT="$REPORT_DIR/${STAMP}-stale-task-recovery-apply.md"

safe_sql_literal() {
  printf "%s" "$1" | sed "s/'/''/g"
}

agent_lock_name() {
  case "$1" in
    devops_agent) printf "devops" ;;
    qa_agent) printf "qa" ;;
    *) printf "" ;;
  esac
}

has_active_lock() {
  local agent="$1"
  local name
  name="$(agent_lock_name "$agent")"
  if [ -n "$name" ] && [ -f "company/runtime/locks/${name}.lock.holder" ]; then
    return 0
  fi
  if [ "$agent" = "engineer_agent" ] && [ -f "company/runtime/locks/repo_write.lock.holder" ]; then
    return 0
  fi
  return 1
}

has_active_runtime_for_task() {
  local task_key="$1"
  local count
  count="$(docker exec ai_company_postgres psql -U ai_company -d ai_company -t -A -v task_key="$task_key" <<'SQL' | tr -d '[:space:]'
SELECT count(*)
FROM agent_runtime_status
WHERE current_task_key = :'task_key'
  AND LOWER(runtime_status) NOT IN ('idle', 'done', 'completed', 'failed');
SQL
)"
  [ "${count:-0}" -gt 0 ]
}

write_header() {
  {
    echo "# Stale Task Recovery Apply"
    echo
    echo "- generated_at: $(date -Iseconds)"
    echo "- mode: $MODE"
    echo "- threshold_hours: $AI_COMPANY_STALE_TASK_AGE_HOURS"
    echo "- report_path: $REPORT"
    echo
    echo "## Safety"
    echo
    echo "- No task deletion."
    echo "- No automatic client task status mutation."
    echo "- No automatic DONE marking."
    echo "- Safe internal/AUTO recovery uses BLOCKED only when explicitly enabled."
    echo
    echo "## Actions"
    echo
  } > "$REPORT"
}

log_recovery_event() {
  local task_key="$1"
  local agent="$2"
  local state="$3"
  local summary="$4"
  ./runners/log_event.sh \
    internal-ai-company-os \
    "$task_key" \
    "${agent:-devops_agent}" \
    stale_task_recovery_apply \
    "$state" \
    operations \
    "Stale task recovery apply" \
    "$summary" >/dev/null 2>&1 || true
}

apply_blocked_review_state() {
  local task_key="$1"
  local agent="$2"
  local note
  note="Stale recovery review required: task was IN_PROGRESS for more than ${AI_COMPANY_STALE_TASK_AGE_HOURS} hours with no active runtime or active lock. Not auto-completed."
  docker exec -i ai_company_postgres psql -U ai_company -d ai_company \
    -v task_key="$task_key" \
    -v note="$note" <<'SQL' >/dev/null
UPDATE tasks
SET
  status = 'BLOCKED',
  updated_at = now(),
  handover_note = CASE
    WHEN COALESCE(handover_note, '') = '' THEN :'note'
    ELSE handover_note || E'\n' || :'note'
  END
WHERE task_key = :'task_key'
  AND status = 'IN_PROGRESS';
SQL
  log_recovery_event "$task_key" "$agent" "BLOCKED" "$note"
}

write_header

TASKS="$(docker exec ai_company_postgres psql -U ai_company -d ai_company -t -A -F $'\t' -c "
SELECT
  task_key,
  title,
  COALESCE(assigned_agent_key, ''),
  status,
  updated_at,
  FLOOR(EXTRACT(EPOCH FROM (now() - updated_at)) / 3600)::int AS age_hours,
  CASE
    WHEN task_key LIKE 'INTERNAL-%' THEN 'internal'
    WHEN task_key LIKE 'AUTO-%' THEN 'auto'
    ELSE 'client'
  END AS task_category
FROM tasks
WHERE status = 'IN_PROGRESS'
  AND updated_at < now() - interval '$AI_COMPANY_STALE_TASK_AGE_HOURS hours'
ORDER BY updated_at ASC, task_key ASC;
")"

if [ -z "$TASKS" ]; then
  echo "No stale IN_PROGRESS tasks found." | tee -a "$REPORT"
  echo
  echo "Report written: $REPORT"
  exit 0
fi

changed=0
reviewed=0

while IFS=$'\t' read -r task_key title agent status updated_at age_hours category; do
  [ -n "$task_key" ] || continue
  action="report_only"
  reason=""

  if has_active_runtime_for_task "$task_key"; then
    action="skip_active_runtime"
    reason="active runtime still points at task"
  elif has_active_lock "$agent"; then
    action="skip_active_lock"
    reason="active lock holder exists for agent/resource"
  elif [ "$category" = "internal" ] && [ "$MODE" = "--apply-safe-internal" ]; then
    apply_blocked_review_state "$task_key" "$agent"
    action="moved_to_blocked_review"
    reason="explicit internal apply enabled"
    changed=$((changed + 1))
  elif [ "$category" = "auto" ] && [ "$MODE" = "--apply-safe-auto" ]; then
    apply_blocked_review_state "$task_key" "$agent"
    action="moved_to_blocked_review"
    reason="explicit AUTO apply enabled"
    changed=$((changed + 1))
  elif [ "$category" = "client" ] && [ "$MODE" = "--apply-client-review-note" ]; then
    action="client_owner_review_report"
    reason="client tasks are never status-mutated by stale recovery"
  else
    reason="dry-run or apply mode does not cover category"
  fi

  reviewed=$((reviewed + 1))
  printf -- "- %s | %s | %s | %s | age_hours=%s | action=%s | %s\n" \
    "$task_key" "$category" "$agent" "$status" "$age_hours" "$action" "$reason" | tee -a "$REPORT"
done <<< "$TASKS"

echo >> "$REPORT"
echo "## Result" >> "$REPORT"
echo >> "$REPORT"
echo "- reviewed: $reviewed" | tee -a "$REPORT"
echo "- changed: $changed" | tee -a "$REPORT"

log_recovery_event "INTERNAL-086" "devops_agent" "REPORT_ONLY" "Stale recovery apply runner completed mode=$MODE reviewed=$reviewed changed=$changed report=$REPORT"

echo
echo "Report written: $REPORT"
