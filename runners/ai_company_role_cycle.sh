#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ROLE="${1:-}"
MODE="${2:-auto}"

if [ -z "$ROLE" ]; then
  echo "Usage: ./runners/ai_company_role_cycle.sh <pm|engineer|qa|devops> [client|internal|auto]"
  exit 2
fi

OS_CONFIG="company/config/ai_company_os.env"
SCHEDULER_CONFIG="company/config/ai_company_scheduler.env"
OS_STATE_FILE="company/runtime/ai-company-os/state.env"
STATE_DIR="company/runtime/ai-company-scheduler"
ROLE_DIR="$STATE_DIR/roles"
ROLE_STATE_FILE="$ROLE_DIR/$ROLE.env"

mkdir -p "$ROLE_DIR" company/runtime/locks

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
: "${AI_COMPANY_CLIENT_PRIORITY:=1}"
: "${AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED:=1}"
: "${AI_COMPANY_REPO_WRITE_LOCK_REQUIRED:=1}"
: "${AI_COMPANY_DEVOPS_LOCK_REQUIRED:=1}"
: "${AI_COMPANY_ENABLE_AUTO_EDIT:=1}"
: "${AI_COMPANY_ENABLE_AUTO_COMMIT:=1}"
: "${AI_COMPANY_AUTO_MARK_DONE:=1}"
: "${AI_COMPANY_OVERTIME_ALLOW_NEW_DISCOVERY:=0}"
: "${AI_COMPANY_OVERTIME_ALLOW_INTERNAL_IMPROVEMENT:=0}"
: "${AI_COMPANY_OVERTIME_ALLOW_QA:=1}"
: "${AI_COMPANY_OVERTIME_ALLOW_REPORTING:=1}"
: "${AI_COMPANY_WORK_HOURS_MODE:=}"

case "$ROLE" in
  pm)
    AGENT_KEY="pm_agent"
    ;;
  engineer)
    AGENT_KEY="engineer_agent"
    ;;
  qa)
    AGENT_KEY="qa_agent"
    ;;
  devops)
    AGENT_KEY="devops_agent"
    ;;
  *)
    echo "Unknown role: $ROLE"
    exit 2
    ;;
esac

shell_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

write_role_state() {
  local state="$1"
  local task="${2:-}"
  local event="${3:-}"
  local tmp_file
  tmp_file="${ROLE_STATE_FILE}.$$.$RANDOM.tmp"
  {
    printf "ROLE=%s\n" "$(shell_quote "$ROLE")"
    printf "ROLE_AGENT=%s\n" "$(shell_quote "$AGENT_KEY")"
    printf "ROLE_STATE=%s\n" "$(shell_quote "$state")"
    printf "ROLE_TASK=%s\n" "$(shell_quote "$task")"
    printf "ROLE_EVENT=%s\n" "$(shell_quote "$event")"
    printf "ROLE_UPDATED_AT=%s\n" "$(shell_quote "$(date -Iseconds)")"
  } > "$tmp_file"
  mv "$tmp_file" "$ROLE_STATE_FILE"
}

log_role_event() {
  local state="$1"
  local topic="$2"
  local summary="$3"
  ./runners/log_event.sh \
    internal-ai-company-os \
    INTERNAL-080 \
    "$AGENT_KEY" \
    "multi_agent_role_cycle" \
    "$state" \
    "autonomous_scheduler" \
    "$topic" \
    "$summary" >/dev/null 2>&1 || true
}

psql_rows() {
  docker exec -i ai_company_postgres psql \
    -U ai_company \
    -d ai_company \
    -t \
    -A \
    -F "|" \
    -v ON_ERROR_STOP=1 \
    -c "$1" 2>/dev/null || true
}

task_project() {
  local task_key="$1"
  psql_rows "
    SELECT p.project_key
    FROM tasks t
    JOIN projects p ON p.id = t.project_id
    WHERE t.task_key = '$task_key'
    LIMIT 1;
  " | tr -d '[:space:]'
}

pending_client_count() {
  psql_rows "
    SELECT count(*)
    FROM tasks
    WHERE project_id IS NOT NULL
      AND task_key NOT LIKE 'INTERNAL-%'
      AND task_key NOT LIKE 'AUTO-%'
      AND status IN ('TODO','INTERNAL_BACKLOG','IN_PROGRESS','NEEDS_REVISION','QA_FAILED','BLOCKED','WAITING_OWNER_ACCEPTANCE');
  " | tr -d '[:space:]'
}

claim_task() {
  local filter="$1"
  local allow_new="${2:-1}"
  local output
  if [ "$filter" = "client" ]; then
    if [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ]; then
      output="$(psql_rows "
SELECT task_key
FROM tasks
WHERE assigned_agent_key = '$AGENT_KEY'
  AND task_key NOT LIKE 'INTERNAL-%'
  AND task_key NOT LIKE 'AUTO-%'
  AND status = 'IN_PROGRESS'
ORDER BY priority DESC NULLS LAST, updated_at ASC, id ASC
LIMIT 1;
")"
      output="$(printf "%s\n" "$output" | sed '/^[[:space:]]*$/d' | head -1)"
      if [ -n "$output" ]; then
        printf "%s\n" "$output"
        return 0
      fi
      if [ "$allow_new" != "1" ]; then
        return 0
      fi
    fi
    output="$(psql_rows "
WITH candidate AS (
  SELECT id
  FROM tasks
  WHERE assigned_agent_key = '$AGENT_KEY'
    AND task_key NOT LIKE 'INTERNAL-%'
    AND task_key NOT LIKE 'AUTO-%'
    AND status IN ('TODO', 'INTERNAL_BACKLOG', 'NEEDS_REVISION', 'QA_FAILED')
  ORDER BY priority DESC NULLS LAST, id ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED
)
UPDATE tasks
SET
  status = 'IN_PROGRESS',
  updated_at = now(),
  handover_note = 'Claimed by $AGENT_KEY at ' || now()
FROM candidate
WHERE tasks.id = candidate.id
RETURNING task_key;
")"
    output="$(printf "%s\n" "$output" | sed '/^[[:space:]]*$/d' | head -1)"
    if [ -n "$output" ]; then
      ./runners/update_agent_runtime_status.sh "$AGENT_KEY" claimed "$output" "autonomous_scheduler" "$AGENT_KEY claimed $output via multi-agent scheduler." >/dev/null 2>&1 || true
    fi
    printf "%s\n" "$output"
  else
    if [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ]; then
      output="$(psql_rows "
SELECT task_key
FROM tasks
WHERE assigned_agent_key = '$AGENT_KEY'
  AND task_key LIKE 'AUTO-%'
  AND status = 'IN_PROGRESS'
ORDER BY priority DESC NULLS LAST, updated_at ASC, id ASC
LIMIT 1;
")"
      output="$(printf "%s\n" "$output" | sed '/^[[:space:]]*$/d' | head -1)"
      if [ -n "$output" ]; then
        printf "%s\n" "$output"
        return 0
      fi
      if [ "$allow_new" != "1" ]; then
        return 0
      fi
    fi
    output="$(psql_rows "
WITH candidate AS (
  SELECT id
  FROM tasks
  WHERE assigned_agent_key = '$AGENT_KEY'
    AND task_key LIKE 'AUTO-%'
    AND status IN ('TODO', 'INTERNAL_BACKLOG', 'NEEDS_REVISION', 'QA_FAILED')
  ORDER BY priority DESC NULLS LAST, id ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED
)
UPDATE tasks
SET
  status = 'IN_PROGRESS',
  updated_at = now(),
  handover_note = 'Claimed by $AGENT_KEY at ' || now()
FROM candidate
WHERE tasks.id = candidate.id
RETURNING task_key;
")"
    output="$(printf "%s\n" "$output" | sed '/^[[:space:]]*$/d' | head -1)"
    if [ -n "$output" ]; then
      ./runners/update_agent_runtime_status.sh "$AGENT_KEY" claimed "$output" "autonomous_scheduler" "$AGENT_KEY claimed $output via multi-agent scheduler." >/dev/null 2>&1 || true
    fi
    printf "%s\n" "$output"
  fi
}

with_repo_lock() {
  if [ "$AI_COMPANY_REPO_WRITE_LOCK_REQUIRED" = "1" ]; then
    ./runners/ai_company_lock.sh repo_write "$@"
  else
    "$@"
  fi
}

with_devops_lock() {
  if [ "$AI_COMPANY_DEVOPS_LOCK_REQUIRED" = "1" ]; then
    ./runners/ai_company_lock.sh devops "$@"
  else
    "$@"
  fi
}

if [ "$AI_COMPANY_OS_OWNER_SWITCH" != "ON" ]; then
  write_role_state "paused_by_owner" "" "AI Company OS is OFF"
  echo "$ROLE: AI Company OS is OFF."
  exit 0
fi

if [ "$AI_COMPANY_SCHEDULER_ENABLED" != "1" ]; then
  write_role_state "scheduler_disabled" "" "Scheduler disabled by config"
  echo "$ROLE: scheduler disabled."
  exit 0
fi

if [ "${AI_COMPANY_AGENT_EMERGENCY_STOP:-0}" = "1" ]; then
  write_role_state "emergency_stop" "" "Emergency stop active"
  echo "$ROLE: emergency stop active."
  exit 0
fi

if ! ./runners/ai_company_work_hours_gate.sh >/tmp/ai-company-role-work-hours-"$ROLE".out 2>&1; then
  write_role_state "paused_outside_work_hours" "" "Outside work hours"
  cat /tmp/ai-company-role-work-hours-"$ROLE".out
  exit 0
fi
AI_COMPANY_WORK_HOURS_MODE="$(awk -F= '$1=="WORK_HOURS_MODE"{print $2}' /tmp/ai-company-role-work-hours-"$ROLE".out | tail -1)"
AI_COMPANY_WORK_HOURS_MODE="${AI_COMPANY_WORK_HOURS_MODE:-NORMAL_WORK}"

set +e
./runners/ai_company_budget_gate.sh >/tmp/ai-company-role-budget-"$ROLE".out 2>&1
budget_status=$?
set -e
if [ "$budget_status" -eq 2 ]; then
  write_role_state "paused_budget_stop" "" "Budget STOP"
  cat /tmp/ai-company-role-budget-"$ROLE".out
  exit 0
fi

if [ "$MODE" = "auto" ]; then
  client_count="$(pending_client_count)"
  client_count="${client_count:-0}"
  if [ "$AI_COMPANY_CLIENT_PRIORITY" = "1" ] && [ "$client_count" -gt 0 ]; then
    MODE="client"
  else
    MODE="internal"
  fi
fi

write_role_state "starting" "" "Starting $MODE role cycle"
log_role_event "STARTING" "$ROLE cycle starting" "Starting $MODE role cycle for $AGENT_KEY."

case "$ROLE:$MODE" in
  pm:client)
    allow_new=1
    if [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ]; then
      allow_new=0
    fi
    task_key="$(claim_task client "$allow_new")"
    if [ -z "$task_key" ]; then
      write_role_state "idle" "" "No overtime-safe client PM task"
      exit 0
    fi
    project_key="$(task_project "$task_key")"
    if [ -z "$project_key" ]; then
      write_role_state "blocked" "$task_key" "Missing project key"
      exit 1
    fi
    write_role_state "working" "$task_key" "Generating PM intake and task breakdown"
    with_repo_lock ./runners/pm_intake_processor.sh "$project_key" "$task_key"
    with_repo_lock ./runners/generate_tasks_from_pm_analysis.sh "$project_key" "$task_key"
    ./runners/update_task_status.sh "$task_key" DONE "PM intake analysis and downstream task breakdown generated by multi-agent scheduler."
    ;;
  pm:internal)
    if [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ] && [ "$AI_COMPANY_OVERTIME_ALLOW_REPORTING" != "1" ]; then
      write_role_state "skipped_overtime" "" "Reporting disabled during overtime"
      exit 0
    fi
    write_role_state "working" "" "Checking owner inbox and planning queue"
    ./runners/owner_inbox.sh >/tmp/ai-company-pm-owner-inbox.out 2>&1 || true
    log_role_event "IDLE_REVIEW" "PM checked owner inbox" "PM reviewed owner command/client intake queue during internal idle cycle."
    ;;
  engineer:client)
    allow_new=1
    if [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ]; then
      allow_new=0
    fi
    task_key="$(claim_task client "$allow_new")"
    if [ -z "$task_key" ]; then
      write_role_state "idle" "" "No overtime-safe client engineer task"
      exit 0
    fi
    project_key="$(task_project "$task_key")"
    write_role_state "working" "$task_key" "Running client engineer implementation"
    with_repo_lock ./runners/engineer_implementation_runner.sh "$project_key" "$task_key"
    ;;
  engineer:internal)
    allow_new=1
    if [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ]; then
      allow_new="$AI_COMPANY_OVERTIME_ALLOW_INTERNAL_IMPROVEMENT"
    fi
    task_key="$(claim_task internal "$allow_new")"
    if [ -n "$task_key" ]; then
      write_role_state "working" "$task_key" "Solving existing autonomous internal task"
      AI_COMPANY_ENABLE_AUTO_EDIT="$AI_COMPANY_ENABLE_AUTO_EDIT" \
      AI_COMPANY_ENABLE_AUTO_COMMIT="$AI_COMPANY_ENABLE_AUTO_COMMIT" \
      AI_COMPANY_AUTO_MARK_DONE="$AI_COMPANY_AUTO_MARK_DONE" \
      with_repo_lock ./runners/autonomous_code_dev.sh "$AGENT_KEY" "$task_key" --run
    elif [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ] && [ "$AI_COMPANY_OVERTIME_ALLOW_NEW_DISCOVERY" != "1" ]; then
      write_role_state "skipped_overtime" "" "New autonomous discovery disabled during overtime"
      exit 0
    elif [ "$AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED" = "1" ]; then
      write_role_state "discovering" "" "Running bounded autonomous discovery"
      AI_COMPANY_SELF_DIRECTED_CREATE_TASKS=1 \
      AI_COMPANY_SELF_DIRECTED_AUTO_SOLVE=0 \
      AI_COMPANY_SELF_DIRECTED_MAX_TASKS_PER_RUN=1 \
      ./runners/autonomous_self_directed_loop.sh "$AGENT_KEY" --once
    else
      write_role_state "idle" "" "Internal idle work disabled"
      exit 0
    fi
    ;;
  qa:client)
    allow_new=1
    if [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ]; then
      allow_new="$AI_COMPANY_OVERTIME_ALLOW_QA"
    fi
    task_key="$(claim_task client "$allow_new")"
    if [ -z "$task_key" ]; then
      write_role_state "idle" "" "No overtime-safe client QA task"
      exit 0
    fi
    project_key="$(task_project "$task_key")"
    write_role_state "working" "$task_key" "Running client QA verification"
    with_repo_lock ./runners/ai_company_lock.sh qa ./runners/qa_verification_runner.sh "$project_key" "$task_key"
    ;;
  qa:internal)
    if [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ] && [ "$AI_COMPANY_OVERTIME_ALLOW_QA" != "1" ]; then
      write_role_state "skipped_overtime" "" "QA disabled during overtime"
      exit 0
    fi
    write_role_state "verifying" "" "Running pre_commit_check"
    ./runners/ai_company_lock.sh qa ./runners/pre_commit_check.sh
    ;;
  devops:client)
    allow_new=1
    if [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ]; then
      allow_new="$AI_COMPANY_OVERTIME_ALLOW_REPORTING"
    fi
    task_key="$(claim_task client "$allow_new")"
    if [ -z "$task_key" ]; then
      write_role_state "idle" "" "No overtime-safe client DevOps task"
      exit 0
    fi
    write_role_state "working" "$task_key" "Running DevOps health checks for claimed task"
    with_devops_lock ./runners/agent_services_health_check.sh
    ./runners/update_task_status.sh "$task_key" DONE "DevOps scheduler cycle completed non-destructive service health checks."
    ;;
  devops:internal)
    if [ "$AI_COMPANY_WORK_HOURS_MODE" = "OVERTIME" ] && [ "$AI_COMPANY_OVERTIME_ALLOW_REPORTING" != "1" ]; then
      write_role_state "skipped_overtime" "" "Reporting/status checks disabled during overtime"
      exit 0
    fi
    write_role_state "checking" "" "Running non-destructive VPS/service health checks"
    with_devops_lock ./runners/dashboard_health_check.sh
    with_devops_lock ./runners/agent_services_health_check.sh
    ;;
  *)
    write_role_state "skipped" "" "Mode $MODE not applicable"
    ;;
esac

write_role_state "done" "" "$MODE role cycle complete"
log_role_event "DONE" "$ROLE cycle complete" "$MODE role cycle completed for $AGENT_KEY."
echo "$ROLE $MODE role cycle complete."
