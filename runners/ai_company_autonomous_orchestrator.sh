#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/ai_company_os.env"
STATE_DIR="company/runtime/ai-company-os"
STATE_FILE="$STATE_DIR/state.env"
PROJECT_KEY="internal-ai-company-os"
TASK_KEY="INTERNAL-078"

mkdir -p "$STATE_DIR"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

if [ -f "$STATE_FILE" ]; then
  if bash -n "$STATE_FILE" 2>/dev/null; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  else
    echo "Warning: ignoring malformed AI Company OS state file: $STATE_FILE" >&2
  fi
fi

: "${AI_COMPANY_OS_ENABLED:=0}"
: "${AI_COMPANY_OS_OWNER_SWITCH:=$([ "$AI_COMPANY_OS_ENABLED" = "1" ] && echo ON || echo OFF)}"
: "${AI_COMPANY_AUTOSOLVE_ENABLED:=1}"
: "${AI_COMPANY_CLIENT_PRIORITY:=1}"
: "${AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED:=1}"
: "${AI_COMPANY_MAX_AUTONOMOUS_ITERATIONS:=1}"
: "${AI_COMPANY_DISCOVERY_ONLY_AFTER_RESOLUTION:=1}"
: "${AI_COMPANY_OS_STATUS_NOTE:=}"
: "${AI_COMPANY_OVERTIME_ALLOW_NEW_DISCOVERY:=0}"

shell_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

write_state() {
  local mode="$1"
  local active_agent="${2:-}"
  local event="${3:-}"
  local report="${4:-${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}}"
  local status_note="${5:-$event}"
  local updated_at
  local tmp_file
  updated_at="$(date -Iseconds)"
  tmp_file="${STATE_FILE}.$$.$RANDOM.tmp"

  {
    printf "AI_COMPANY_OS_OWNER_SWITCH=%s\n" "$(shell_quote "$AI_COMPANY_OS_OWNER_SWITCH")"
    printf "AI_COMPANY_OS_MODE=%s\n" "$(shell_quote "$mode")"
    printf "AI_COMPANY_OS_ACTIVE_AGENT=%s\n" "$(shell_quote "$active_agent")"
    printf "AI_COMPANY_OS_LATEST_EVENT=%s\n" "$(shell_quote "$event")"
    printf "AI_COMPANY_OS_STATUS_NOTE=%s\n" "$(shell_quote "$status_note")"
    printf "AI_COMPANY_OS_LATEST_DISCOVERY_REPORT=%s\n" "$(shell_quote "$report")"
    printf "AI_COMPANY_OS_UPDATED_AT=%s\n" "$(shell_quote "$updated_at")"
  } > "$tmp_file"

  mv "$tmp_file" "$STATE_FILE"
}

log_event_safe() {
  local state="$1"
  local topic="$2"
  local summary="$3"

  ./runners/log_event.sh \
    "$PROJECT_KEY" \
    "$TASK_KEY" \
    "pm_agent" \
    "ai_company_os_orchestrator" \
    "$state" \
    "autonomous_orchestrator" \
    "$topic" \
    "$summary" >/dev/null 2>&1 || true
}

psql_scalar() {
  local sql="$1"
  docker exec -i ai_company_postgres psql -U ai_company -d ai_company -t -A -c "$sql" 2>/dev/null | tr -d '[:space:]' || true
}

on_unexpected_error() {
  local line="$1"
  local command="$2"
  write_state "ERROR" "" "Unexpected orchestrator failure" "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}" "Unexpected failure at line $line while running: $command"
  log_event_safe "ERROR" "Unexpected orchestrator failure" "Line $line failed while running: $command"
}

trap 'on_unexpected_error "$LINENO" "$BASH_COMMAND"' ERR

if [ "$AI_COMPANY_OS_OWNER_SWITCH" != "ON" ]; then
  write_state "PAUSED_BY_OWNER" "" "AI Company OS is OFF" "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}" "Owner switch is OFF; autonomous runtime is paused and no agent is active."
  log_event_safe "PAUSED_BY_OWNER" "AI Company OS paused" "Master autonomous mode is OFF."
  echo "AI Company OS is OFF. Nothing to do."
  exit 0
fi

if [ "${AI_COMPANY_AGENT_EMERGENCY_STOP:-0}" = "1" ]; then
  write_state "ERROR" "" "Emergency stop active" "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}" "AI_COMPANY_AGENT_EMERGENCY_STOP=1; orchestrator halted before starting work."
  log_event_safe "ERROR" "Emergency stop active" "AI_COMPANY_AGENT_EMERGENCY_STOP=1; orchestrator halted."
  echo "Emergency stop active. Nothing to do."
  exit 0
fi

if ! ./runners/ai_company_work_hours_gate.sh >/tmp/ai-company-work-hours-gate.out 2>&1; then
  write_state "PAUSED_OUTSIDE_WORK_HOURS" "" "Paused outside work hours" "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}" "Outside configured work hours; autonomous runtime skipped this cycle."
  log_event_safe "PAUSED_OUTSIDE_WORK_HOURS" "Outside work hours" "Master autonomous mode paused outside configured work hours."
  cat /tmp/ai-company-work-hours-gate.out
  exit 0
fi
WORK_HOURS_MODE="$(awk -F= '$1=="WORK_HOURS_MODE"{print $2}' /tmp/ai-company-work-hours-gate.out | tail -1)"
WORK_HOURS_MODE="${WORK_HOURS_MODE:-NORMAL_WORK}"

set +e
./runners/ai_company_budget_gate.sh >/tmp/ai-company-budget-gate.out 2>&1
budget_status=$?
set -e
if [ "$budget_status" -eq 2 ]; then
  write_state "PAUSED_BUDGET_LIMIT" "" "Paused by internal budget STOP" "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}" "Internal Codex budget gate returned STOP; autonomous work skipped this cycle."
  log_event_safe "PAUSED_BUDGET_LIMIT" "Budget STOP" "Internal Codex budget gate returned STOP; autonomous work paused."
  cat /tmp/ai-company-budget-gate.out
  exit 0
fi

client_pending=0
if [ "$AI_COMPANY_CLIENT_PRIORITY" = "1" ] && command -v docker >/dev/null 2>&1; then
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

if [ "$client_pending" -gt 0 ]; then
  write_state "WORKING_ON_CLIENT" "" "Client work has priority" "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}" "Client queue has $client_pending pending task(s); internal autonomous discovery skipped."
  log_event_safe "WORKING_ON_CLIENT" "Client priority" "Client project/task queue has pending work; existing agent workflow keeps priority."
  echo "Client work pending: $client_pending. Internal autonomous work skipped this cycle."
  exit 0
fi

if [ "$AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED" != "1" ]; then
  write_state "RUNNING" "" "Internal idle work disabled" "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}" "No client work pending, but internal idle autonomous work is disabled."
  log_event_safe "RUNNING" "Internal idle work disabled" "No client work pending, but internal idle autonomous work is disabled."
  echo "Internal idle work disabled."
  exit 0
fi

if [ "$WORK_HOURS_MODE" = "OVERTIME" ] && [ "$AI_COMPANY_OVERTIME_ALLOW_NEW_DISCOVERY" != "1" ]; then
  write_state "OVERTIME" "" "Overtime safe mode" "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}" "Overtime window active; new autonomous discovery is disabled by default."
  log_event_safe "OVERTIME" "Overtime safe mode" "New autonomous discovery skipped during overtime by policy."
  echo "Overtime window active. New autonomous discovery skipped by policy."
  exit 0
fi

active_auto_count=0
active_auto_task=""
if command -v docker >/dev/null 2>&1; then
  active_auto_count="$(psql_scalar "
    SELECT count(*)
    FROM tasks
    WHERE task_key LIKE 'AUTO-%'
      AND status NOT IN ('DONE','ACCEPTED','IMPLEMENTED','QA_PASSED','FAILED','BLOCKED','SKIPPED');
  ")"
  active_auto_count="${active_auto_count:-0}"
  active_auto_task="$(docker exec -i ai_company_postgres psql -U ai_company -d ai_company -t -A -F '|' -c "
    SELECT task_key || ' (' || status || ')'
    FROM tasks
    WHERE task_key LIKE 'AUTO-%'
      AND status NOT IN ('DONE','ACCEPTED','IMPLEMENTED','QA_PASSED','FAILED','BLOCKED','SKIPPED')
    ORDER BY updated_at DESC, id DESC
    LIMIT 1;
  " 2>/dev/null | tr -d '\r' | sed '/^[[:space:]]*$/d' | head -1 || true)"
fi

if [ "$AI_COMPANY_DISCOVERY_ONLY_AFTER_RESOLUTION" = "1" ] && [ "$active_auto_count" -gt 0 ]; then
  reason="Discovery skipped: $active_auto_count unresolved AUTO task(s) remain. Resolve or close ${active_auto_task:-the active AUTO task} before creating another autonomous discovery task."
  write_state "SOLVING_ISSUE" "" "Active AUTO issue still unresolved" "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}" "$reason"
  log_event_safe "SOLVING_ISSUE" "Discovery skipped for unresolved AUTO task" "$reason"
  echo "$reason"
  exit 0
fi

write_state "SCANNING_SYSTEM" "engineer_agent" "Running autonomous discovery"
log_event_safe "SCANNING_SYSTEM" "Autonomous discovery started" "No client work pending; scanning for internal issues."

set +e
output="$(
  AI_COMPANY_SELF_DIRECTED_CREATE_TASKS=1 \
  AI_COMPANY_SELF_DIRECTED_AUTO_SOLVE="$AI_COMPANY_AUTOSOLVE_ENABLED" \
  AI_COMPANY_SELF_DIRECTED_MAX_TASKS_PER_RUN=1 \
  AI_COMPANY_ENABLE_AUTO_EDIT="${AI_COMPANY_ENABLE_AUTO_EDIT:-1}" \
  AI_COMPANY_ENABLE_AUTO_COMMIT="${AI_COMPANY_ENABLE_AUTO_COMMIT:-1}" \
  AI_COMPANY_AUTO_MARK_DONE="${AI_COMPANY_AUTO_MARK_DONE:-1}" \
  ./runners/autonomous_self_directed_loop.sh engineer_agent --once 2>&1
)"
status=$?
set -e

printf "%s\n" "$output"

report="$(printf "%s\n" "$output" | awk -F': ' '/^Discovery report: /{print $2}' | tail -1)"
if [ -z "$report" ]; then
  report="$(find company/reports/autonomous-discovery -maxdepth 1 -type f -name '*-discovery.md' 2>/dev/null | sort | tail -1 || true)"
fi

if [ "$status" -ne 0 ]; then
  write_state "ERROR" "" "Autonomous discovery/solve failed" "$report" "Autonomous discovery/solve exited with status $status. Report: ${report:-none}"
  log_event_safe "ERROR" "Autonomous cycle failed" "Autonomous discovery or solve exited with status $status. Report: ${report:-none}"
  exit "$status"
fi

write_state "REPORTING" "engineer_agent" "Autonomous cycle completed" "$report" "Discovery/solve finished; preparing verification."
log_event_safe "REPORTING" "Autonomous cycle completed" "Autonomous discovery/solve cycle completed. Report: ${report:-none}"

if [ -x ./runners/pre_commit_check.sh ]; then
  write_state "VERIFYING" "qa_agent" "Running pre_commit_check" "$report" "Running pre_commit_check after autonomous cycle."
  set +e
  ./runners/pre_commit_check.sh
  verify_status=$?
  set -e
  if [ "$verify_status" -ne 0 ]; then
    write_state "ERROR" "" "pre_commit_check failed" "$report" "pre_commit_check exited with status $verify_status after autonomous cycle. Report: ${report:-none}"
    log_event_safe "ERROR" "Autonomous verification failed" "pre_commit_check exited with status $verify_status after autonomous cycle. Report: ${report:-none}"
    exit "$verify_status"
  fi
fi

write_state "RUNNING" "" "AI Company OS cycle complete" "$report" "Autonomous cycle completed successfully; no agent is currently active."
echo "AI Company OS autonomous orchestrator cycle complete."
