#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

OS_CONFIG="company/config/ai_company_os.env"
SCHEDULER_CONFIG="company/config/ai_company_scheduler.env"
OS_STATE_FILE="company/runtime/ai-company-os/state.env"
STATE_DIR="company/runtime/ai-company-scheduler"
STATE_FILE="$STATE_DIR/state.env"
CURSOR_FILE="$STATE_DIR/internal-role-cursor"

mkdir -p "$STATE_DIR" company/runtime/locks

if [ -f "$OS_CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$OS_CONFIG"
fi

if [ -f "$SCHEDULER_CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$SCHEDULER_CONFIG"
fi

if [ -f "$OS_STATE_FILE" ] && bash -n "$OS_STATE_FILE" 2>/dev/null; then
  # shellcheck disable=SC1090
  source "$OS_STATE_FILE"
fi

: "${AI_COMPANY_OS_ENABLED:=0}"
: "${AI_COMPANY_OS_OWNER_SWITCH:=$([ "$AI_COMPANY_OS_ENABLED" = "1" ] && echo ON || echo OFF)}"
: "${AI_COMPANY_SCHEDULER_ENABLED:=1}"
: "${AI_COMPANY_MAX_PARALLEL_AGENTS:=2}"
: "${AI_COMPANY_CLIENT_PRIORITY:=1}"
: "${AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED:=1}"
: "${AI_COMPANY_SCHEDULER_INTERVAL_SECONDS:=60}"
: "${AI_COMPANY_SCHEDULER_MAX_ITERATIONS:=1}"
: "${AI_COMPANY_SCHEDULER_ROLE_ORDER:=pm,engineer,qa,devops}"
: "${AI_COMPANY_INTERNAL_ROLE_ORDER:=pm,engineer,qa,devops}"
: "${AI_COMPANY_ENABLE_PM_PARALLEL:=1}"
: "${AI_COMPANY_ENABLE_ENGINEER_PARALLEL:=1}"
: "${AI_COMPANY_ENABLE_QA_PARALLEL:=1}"
: "${AI_COMPANY_ENABLE_DEVOPS_PARALLEL:=1}"
: "${AI_COMPANY_OVERTIME_ALLOW_NEW_DISCOVERY:=0}"
: "${AI_COMPANY_OVERTIME_ALLOW_INTERNAL_IMPROVEMENT:=0}"
: "${AI_COMPANY_OVERTIME_ALLOW_QA:=1}"
: "${AI_COMPANY_OVERTIME_ALLOW_REPORTING:=1}"
: "${AI_COMPANY_LEARNING_ENABLED:=1}"
: "${AI_COMPANY_AUTO_RESTART_SERVICES:=0}"
: "${AI_COMPANY_STALE_TASK_RECOVERY_ENABLED:=1}"
: "${AI_COMPANY_STALE_TASK_AUTO_APPLY_INTERNAL:=0}"
: "${AI_COMPANY_STALE_TASK_AUTO_APPLY_AUTO:=0}"

if ! [[ "$AI_COMPANY_MAX_PARALLEL_AGENTS" =~ ^[0-9]+$ ]] || [ "$AI_COMPANY_MAX_PARALLEL_AGENTS" -lt 1 ]; then
  AI_COMPANY_MAX_PARALLEL_AGENTS=1
fi

shell_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

write_scheduler_state() {
  local state="$1"
  local mode="${2:-unknown}"
  local active_agents="${3:-}"
  local event="${4:-}"
  local work_hours_mode="${5:-${WORK_HOURS_MODE:-unknown}}"
  local overtime_info="${6:-}"
  local tmp_file
  tmp_file="${STATE_FILE}.$$.$RANDOM.tmp"
  {
    printf "AI_COMPANY_SCHEDULER_STATE=%s\n" "$(shell_quote "$state")"
    printf "AI_COMPANY_SCHEDULER_MODE=%s\n" "$(shell_quote "$mode")"
    printf "AI_COMPANY_SCHEDULER_WORK_HOURS_MODE=%s\n" "$(shell_quote "$work_hours_mode")"
    printf "AI_COMPANY_SCHEDULER_OVERTIME_INFO=%s\n" "$(shell_quote "$overtime_info")"
    printf "AI_COMPANY_SCHEDULER_ACTIVE_AGENTS=%s\n" "$(shell_quote "$active_agents")"
    printf "AI_COMPANY_SCHEDULER_LATEST_EVENT=%s\n" "$(shell_quote "$event")"
    printf "AI_COMPANY_SCHEDULER_UPDATED_AT=%s\n" "$(shell_quote "$(date -Iseconds)")"
  } > "$tmp_file"
  mv "$tmp_file" "$STATE_FILE"
}

log_scheduler_event() {
  local state="$1"
  local topic="$2"
  local summary="$3"
  ./runners/log_event.sh \
    internal-ai-company-os \
    INTERNAL-080 \
    pm_agent \
    multi_agent_scheduler \
    "$state" \
    autonomous_scheduler \
    "$topic" \
    "$summary" >/dev/null 2>&1 || true
}

run_learning_review_if_allowed() {
  if [ "${AI_COMPANY_LEARNING_ENABLED:-1}" != "1" ]; then
    return 0
  fi

  if [ "${WORK_HOURS_MODE:-unknown}" != "NORMAL_WORK" ]; then
    return 0
  fi

  if [ ! -x ./runners/learning_daily_review.sh ]; then
    return 0
  fi

  local output_file
  output_file="/tmp/ai-company-learning-daily-review.out"
  if ./runners/learning_daily_review.sh >"$output_file" 2>&1; then
    log_scheduler_event "DONE" "Learning daily review complete" "Learning daily review completed without blocking scheduler."
  else
    log_scheduler_event "WARN" "Learning daily review warning" "Learning daily review failed; scheduler continued. See $output_file."
  fi
}

run_post_update_restart_plan_if_allowed() {
  if [ ! -x ./runners/post_update_service_plan.sh ]; then
    return 0
  fi

  local output_file
  output_file="/tmp/ai-company-post-update-service-plan.out"
  if ./runners/post_update_service_plan.sh >"$output_file" 2>&1; then
    log_scheduler_event "DONE" "Post-update restart plan complete" "Post-update service plan completed in report-only mode."
  else
    log_scheduler_event "WARN" "Post-update restart plan warning" "Post-update service plan failed; scheduler continued. See $output_file."
    return 0
  fi

  if [ "${AI_COMPANY_AUTO_RESTART_SERVICES:-0}" != "1" ]; then
    return 0
  fi

  if [ ! -x ./runners/post_update_service_restart.sh ]; then
    log_scheduler_event "WARN" "Post-update restart unavailable" "Auto-restart is enabled but restart runner is missing."
    return 0
  fi

  output_file="/tmp/ai-company-post-update-service-restart.out"
  if ./runners/post_update_service_restart.sh --apply >"$output_file" 2>&1; then
    log_scheduler_event "DONE" "Post-update restart complete" "Auto-restart completed. See $output_file."
  else
    log_scheduler_event "WARN" "Post-update restart warning" "Auto-restart failed or health recovery warned. See $output_file."
  fi
}

run_stale_task_recovery_if_allowed() {
  if [ "${AI_COMPANY_STALE_TASK_RECOVERY_ENABLED:-1}" != "1" ]; then
    return 0
  fi

  if [ ! -x ./runners/stale_task_recovery_plan.sh ]; then
    return 0
  fi

  local output_file
  output_file="/tmp/ai-company-stale-task-recovery-plan.out"
  if ./runners/stale_task_recovery_plan.sh >"$output_file" 2>&1; then
    log_scheduler_event "REPORT_ONLY" "Stale task recovery plan complete" "Stale task recovery planning completed in report-only mode."
  else
    log_scheduler_event "WARN" "Stale task recovery plan warning" "Stale task recovery planning failed; scheduler continued. See $output_file."
    return 0
  fi

  if [ ! -x ./runners/stale_task_recovery_apply.sh ]; then
    return 0
  fi

  if [ "${AI_COMPANY_STALE_TASK_AUTO_APPLY_INTERNAL:-0}" = "1" ]; then
    output_file="/tmp/ai-company-stale-task-recovery-apply-internal.out"
    if AI_COMPANY_STALE_TASK_AUTO_APPLY_INTERNAL=1 ./runners/stale_task_recovery_apply.sh --apply-safe-internal >"$output_file" 2>&1; then
      log_scheduler_event "DONE" "Stale internal recovery applied" "Safe internal stale task recovery completed. See $output_file."
    else
      log_scheduler_event "WARN" "Stale internal recovery warning" "Safe internal stale task recovery failed; scheduler continued. See $output_file."
    fi
  fi

  if [ "${AI_COMPANY_STALE_TASK_AUTO_APPLY_AUTO:-0}" = "1" ]; then
    output_file="/tmp/ai-company-stale-task-recovery-apply-auto.out"
    if AI_COMPANY_STALE_TASK_AUTO_APPLY_AUTO=1 ./runners/stale_task_recovery_apply.sh --apply-safe-auto >"$output_file" 2>&1; then
      log_scheduler_event "DONE" "Stale AUTO recovery applied" "Safe AUTO stale task recovery completed. See $output_file."
    else
      log_scheduler_event "WARN" "Stale AUTO recovery warning" "Safe AUTO stale task recovery failed; scheduler continued. See $output_file."
    fi
  fi
}

psql_scalar() {
  docker exec -i ai_company_postgres psql \
    -U ai_company \
    -d ai_company \
    -t \
    -A \
    -v ON_ERROR_STOP=1 \
    -c "$1" 2>/dev/null | tr -d '[:space:]' || true
}

role_enabled() {
  case "$1" in
    pm) [ "$AI_COMPANY_ENABLE_PM_PARALLEL" = "1" ] ;;
    engineer) [ "$AI_COMPANY_ENABLE_ENGINEER_PARALLEL" = "1" ] ;;
    qa) [ "$AI_COMPANY_ENABLE_QA_PARALLEL" = "1" ] ;;
    devops) [ "$AI_COMPANY_ENABLE_DEVOPS_PARALLEL" = "1" ] ;;
    *) return 1 ;;
  esac
}

role_csv_to_array() {
  local csv="$1"
  local -n out_ref="$2"
  local index
  IFS=',' read -r -a out_ref <<< "$csv"
  for index in "${!out_ref[@]}"; do
    out_ref[$index]="$(printf "%s" "${out_ref[$index]}" | xargs)"
  done
}

select_internal_roles() {
  local -n selected_ref="$1"
  local roles=()
  local enabled_roles=()
  local cursor=0
  local count
  local i
  local idx
  local role

  role_csv_to_array "$AI_COMPANY_INTERNAL_ROLE_ORDER" roles
  for role in "${roles[@]}"; do
    if role_enabled "$role"; then
      enabled_roles+=("$role")
    fi
  done

  count="${#enabled_roles[@]}"
  if [ "$count" -eq 0 ]; then
    return
  fi

  if [ -f "$CURSOR_FILE" ]; then
    cursor="$(tr -dc '0-9' < "$CURSOR_FILE" || true)"
    cursor="${cursor:-0}"
  fi

  for ((i = 0; i < count && ${#selected_ref[@]} < AI_COMPANY_MAX_PARALLEL_AGENTS; i++)); do
    idx=$(((cursor + i) % count))
    selected_ref+=("${enabled_roles[$idx]}")
  done

  printf "%s\n" "$(((cursor + ${#selected_ref[@]}) % count))" > "$CURSOR_FILE"
}

select_client_roles() {
  local -n selected_ref="$1"
  local roles=()
  local role
  role_csv_to_array "$AI_COMPANY_SCHEDULER_ROLE_ORDER" roles
  for role in "${roles[@]}"; do
    if [ "${#selected_ref[@]}" -ge "$AI_COMPANY_MAX_PARALLEL_AGENTS" ]; then
      break
    fi
    if role_enabled "$role"; then
      selected_ref+=("$role")
    fi
  done
}

run_iteration() {
  if [ "$AI_COMPANY_OS_OWNER_SWITCH" != "ON" ]; then
    write_scheduler_state "paused_by_owner" "paused" "" "AI Company OS is OFF"
    echo "AI Company OS is OFF. Scheduler paused."
    return 0
  fi

  if [ "$AI_COMPANY_SCHEDULER_ENABLED" != "1" ]; then
    write_scheduler_state "disabled" "paused" "" "Scheduler disabled by config"
    echo "Scheduler disabled by config."
    return 0
  fi

  if [ "${AI_COMPANY_AGENT_EMERGENCY_STOP:-0}" = "1" ]; then
    write_scheduler_state "emergency_stop" "paused" "" "Emergency stop active"
    echo "Emergency stop active. Scheduler paused."
    return 0
  fi

  if ! ./runners/ai_company_work_hours_gate.sh >/tmp/ai-company-scheduler-work-hours.out 2>&1; then
    write_scheduler_state "paused_outside_work_hours" "paused" "" "Outside work hours"
    cat /tmp/ai-company-scheduler-work-hours.out
    return 0
  fi
  WORK_HOURS_MODE="$(awk -F= '$1=="WORK_HOURS_MODE"{print $2}' /tmp/ai-company-scheduler-work-hours.out | tail -1)"
  WORK_HOURS_MODE="${WORK_HOURS_MODE:-NORMAL_WORK}"
  overtime_info="normal"
  if [ "$WORK_HOURS_MODE" = "OVERTIME" ]; then
    overtime_info="allow_new_discovery=$AI_COMPANY_OVERTIME_ALLOW_NEW_DISCOVERY allow_internal_improvement=$AI_COMPANY_OVERTIME_ALLOW_INTERNAL_IMPROVEMENT allow_qa=$AI_COMPANY_OVERTIME_ALLOW_QA allow_reporting=$AI_COMPANY_OVERTIME_ALLOW_REPORTING"
  fi

  set +e
  ./runners/ai_company_budget_gate.sh >/tmp/ai-company-scheduler-budget.out 2>&1
  budget_status=$?
  set -e
  if [ "$budget_status" -eq 2 ]; then
    write_scheduler_state "paused_budget_stop" "paused" "" "Budget STOP"
    cat /tmp/ai-company-scheduler-budget.out
    return 0
  fi

  client_pending=0
  if [ "$AI_COMPANY_CLIENT_PRIORITY" = "1" ]; then
    client_pending="$(psql_scalar "
      SELECT count(*)
      FROM tasks
      WHERE project_id IS NOT NULL
        AND task_key NOT LIKE 'INTERNAL-%'
        AND task_key NOT LIKE 'AUTO-%'
        AND status IN ('TODO','INTERNAL_BACKLOG','IN_PROGRESS','NEEDS_REVISION','QA_FAILED','BLOCKED','WAITING_OWNER_ACCEPTANCE');
    ")"
    client_pending="${client_pending:-0}"
  fi

  mode="internal"
  roles=()
  if [ "$AI_COMPANY_CLIENT_PRIORITY" = "1" ] && [ "$client_pending" -gt 0 ]; then
    mode="client"
    select_client_roles roles
  elif [ "$AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED" = "1" ]; then
    mode="internal"
    select_internal_roles roles
  else
    write_scheduler_state "idle" "internal" "" "No client work and internal idle work disabled"
    echo "No client work pending; internal idle work disabled."
    return 0
  fi

  if [ "${#roles[@]}" -eq 0 ]; then
    write_scheduler_state "idle" "$mode" "" "No enabled roles selected" "$WORK_HOURS_MODE" "$overtime_info"
    echo "No enabled roles selected."
    return 0
  fi

  active_agents="$(IFS=','; printf "%s" "${roles[*]}")"
  write_scheduler_state "running" "$mode" "$active_agents" "Starting ${#roles[@]} role cycle(s)" "$WORK_HOURS_MODE" "$overtime_info"
  log_scheduler_event "RUNNING" "Scheduler cycle started" "Mode=$mode work_hours_mode=$WORK_HOURS_MODE roles=$active_agents client_pending=$client_pending."

  pids=()
  for role in "${roles[@]}"; do
    AI_COMPANY_WORK_HOURS_MODE="$WORK_HOURS_MODE" ./runners/ai_company_role_cycle.sh "$role" "$mode" &
    pids+=("$!")
  done

  failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed=1
    fi
  done

  if [ "$failed" -ne 0 ]; then
    write_scheduler_state "error" "$mode" "" "One or more role cycles failed" "$WORK_HOURS_MODE" "$overtime_info"
    log_scheduler_event "ERROR" "Scheduler cycle failed" "One or more $mode role cycles failed."
    return 1
  fi

  write_scheduler_state "idle" "$mode" "" "Scheduler cycle complete" "$WORK_HOURS_MODE" "$overtime_info"
  log_scheduler_event "DONE" "Scheduler cycle complete" "Mode=$mode work_hours_mode=$WORK_HOURS_MODE roles=$active_agents completed."
  run_stale_task_recovery_if_allowed
  run_learning_review_if_allowed
  run_post_update_restart_plan_if_allowed
}

iteration=0
while true; do
  iteration=$((iteration + 1))
  echo
  echo "## Multi-agent scheduler iteration $iteration / $AI_COMPANY_SCHEDULER_MAX_ITERATIONS"
  run_iteration

  if [ "$iteration" -ge "$AI_COMPANY_SCHEDULER_MAX_ITERATIONS" ]; then
    break
  fi

  sleep "$AI_COMPANY_SCHEDULER_INTERVAL_SECONDS"

  if [ -f "$OS_STATE_FILE" ] && bash -n "$OS_STATE_FILE" 2>/dev/null; then
    # shellcheck disable=SC1090
    source "$OS_STATE_FILE"
  fi
done

echo "AI Company multi-agent scheduler complete."
