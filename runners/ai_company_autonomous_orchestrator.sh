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
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

: "${AI_COMPANY_OS_ENABLED:=0}"
: "${AI_COMPANY_OS_OWNER_SWITCH:=$([ "$AI_COMPANY_OS_ENABLED" = "1" ] && echo ON || echo OFF)}"
: "${AI_COMPANY_AUTOSOLVE_ENABLED:=1}"
: "${AI_COMPANY_CLIENT_PRIORITY:=1}"
: "${AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED:=1}"
: "${AI_COMPANY_MAX_AUTONOMOUS_ITERATIONS:=1}"
: "${AI_COMPANY_DISCOVERY_ONLY_AFTER_RESOLUTION:=1}"

shell_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

write_state() {
  local mode="$1"
  local active_agent="${2:-}"
  local event="${3:-}"
  local report="${4:-${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-}}"
  local updated_at
  updated_at="$(date -Iseconds)"

  {
    printf "AI_COMPANY_OS_OWNER_SWITCH=%s\n" "$(shell_quote "$AI_COMPANY_OS_OWNER_SWITCH")"
    printf "AI_COMPANY_OS_MODE=%s\n" "$(shell_quote "$mode")"
    printf "AI_COMPANY_OS_ACTIVE_AGENT=%s\n" "$(shell_quote "$active_agent")"
    printf "AI_COMPANY_OS_LATEST_EVENT=%s\n" "$(shell_quote "$event")"
    printf "AI_COMPANY_OS_LATEST_DISCOVERY_REPORT=%s\n" "$(shell_quote "$report")"
    printf "AI_COMPANY_OS_UPDATED_AT=%s\n" "$(shell_quote "$updated_at")"
  } > "$STATE_FILE.tmp"

  mv "$STATE_FILE.tmp" "$STATE_FILE"
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

if [ "$AI_COMPANY_OS_OWNER_SWITCH" != "ON" ]; then
  write_state "PAUSED_BY_OWNER" "" "AI Company OS is OFF"
  log_event_safe "PAUSED_BY_OWNER" "AI Company OS paused" "Master autonomous mode is OFF."
  echo "AI Company OS is OFF. Nothing to do."
  exit 0
fi

if [ "${AI_COMPANY_AGENT_EMERGENCY_STOP:-0}" = "1" ]; then
  write_state "ERROR" "" "Emergency stop active"
  log_event_safe "ERROR" "Emergency stop active" "AI_COMPANY_AGENT_EMERGENCY_STOP=1; orchestrator halted."
  echo "Emergency stop active. Nothing to do."
  exit 0
fi

if ! ./runners/ai_company_work_hours_gate.sh >/tmp/ai-company-work-hours-gate.out 2>&1; then
  write_state "PAUSED_OUTSIDE_WORK_HOURS" "" "Paused outside work hours"
  log_event_safe "PAUSED_OUTSIDE_WORK_HOURS" "Outside work hours" "Master autonomous mode paused outside configured work hours."
  cat /tmp/ai-company-work-hours-gate.out
  exit 0
fi

set +e
./runners/ai_company_budget_gate.sh >/tmp/ai-company-budget-gate.out 2>&1
budget_status=$?
set -e
if [ "$budget_status" -eq 2 ]; then
  write_state "PAUSED_BUDGET_LIMIT" "budget_manager" "Paused by internal budget STOP"
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
  write_state "WORKING_ON_CLIENT" "pm_agent" "Client work has priority"
  log_event_safe "WORKING_ON_CLIENT" "Client priority" "Client project/task queue has pending work; existing agent workflow keeps priority."
  echo "Client work pending: $client_pending. Internal autonomous work skipped this cycle."
  exit 0
fi

if [ "$AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED" != "1" ]; then
  write_state "RUNNING" "" "Internal idle work disabled"
  log_event_safe "RUNNING" "Internal idle work disabled" "No client work pending, but internal idle autonomous work is disabled."
  echo "Internal idle work disabled."
  exit 0
fi

active_auto_count=0
if command -v docker >/dev/null 2>&1; then
  active_auto_count="$(psql_scalar "
    SELECT count(*)
    FROM tasks
    WHERE task_key LIKE 'AUTO-%'
      AND status NOT IN ('DONE','ACCEPTED','IMPLEMENTED','QA_PASSED','FAILED','BLOCKED','SKIPPED');
  ")"
  active_auto_count="${active_auto_count:-0}"
fi

if [ "$AI_COMPANY_DISCOVERY_ONLY_AFTER_RESOLUTION" = "1" ] && [ "$active_auto_count" -gt 0 ]; then
  write_state "SOLVING_ISSUE" "engineer_agent" "Active AUTO issue still unresolved"
  log_event_safe "SOLVING_ISSUE" "Continuing active AUTO issue" "Discovery skipped because an active AUTO task is not resolved yet."
  echo "Active unresolved AUTO task count: $active_auto_count. Discovery skipped."
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
  write_state "ERROR" "engineer_agent" "Autonomous discovery/solve failed" "$report"
  log_event_safe "ERROR" "Autonomous cycle failed" "Autonomous discovery or solve exited with status $status. Report: ${report:-none}"
  exit "$status"
fi

write_state "REPORTING" "engineer_agent" "Autonomous cycle completed" "$report"
log_event_safe "REPORTING" "Autonomous cycle completed" "Autonomous discovery/solve cycle completed. Report: ${report:-none}"

if [ -x ./runners/pre_commit_check.sh ]; then
  write_state "VERIFYING" "qa_agent" "Running pre_commit_check" "$report"
  ./runners/pre_commit_check.sh
fi

write_state "RUNNING" "" "AI Company OS cycle complete" "$report"
echo "AI Company OS autonomous orchestrator cycle complete."
