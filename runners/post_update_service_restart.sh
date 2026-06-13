#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

MODE=""
SKIP_PRECHECK=0
SINCE_REF=""
REPORT_DIR="company/reports/post-update"
OS_CONFIG="company/config/ai_company_os.env"
SCHEDULER_CONFIG="company/config/ai_company_scheduler.env"
OS_STATE_FILE="company/runtime/ai-company-os/state.env"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    --skip-precheck)
      SKIP_PRECHECK=1
      shift
      ;;
    --since-ref)
      SINCE_REF="${2:-}"
      if [ -z "$SINCE_REF" ]; then
        echo "ERROR: --since-ref requires a ref." >&2
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./runners/post_update_service_restart.sh --dry-run|--apply [--since-ref REF] [--skip-precheck]

Restarts only AI Company OS services affected by changed files. The runner
refuses to mutate services unless --apply is present.
EOF
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "ERROR: refusing to restart without --apply. Use --dry-run to preview." >&2
  exit 2
fi

mkdir -p "$REPORT_DIR"

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
: "${AI_COMPANY_AGENT_EMERGENCY_STOP:=0}"
: "${AI_COMPANY_AUTO_RESTART_SERVICES:=0}"
: "${AI_COMPANY_AUTO_RESTART_DASHBOARD:=1}"
: "${AI_COMPANY_AUTO_RESTART_SCHEDULER:=1}"
: "${AI_COMPANY_AUTO_RESTART_AGENT_SERVICES:=0}"

plan_args=()
if [ -n "$SINCE_REF" ]; then
  plan_args+=(--since-ref "$SINCE_REF")
fi

mapfile -t planned_services < <(./runners/post_update_service_plan.sh "${plan_args[@]}" --services-only | sed '/^[[:space:]]*$/d')

allow_service() {
  case "$1" in
    ai-company-dashboard.service) [ "$AI_COMPANY_AUTO_RESTART_DASHBOARD" = "1" ] ;;
    ai-company-multi-agent-scheduler.service) [ "$AI_COMPANY_AUTO_RESTART_SCHEDULER" = "1" ] ;;
    ai-company-agent@*) [ "$AI_COMPANY_AUTO_RESTART_AGENT_SERVICES" = "1" ] ;;
    *) return 1 ;;
  esac
}

services=()
skipped=()
for service in "${planned_services[@]}"; do
  if allow_service "$service"; then
    services+=("$service")
  else
    skipped+=("$service")
  fi
done

timestamp="$(date -Iseconds)"
stamp="$(date +%Y%m%dT%H%M%S%z)"
report="$REPORT_DIR/${stamp}-service-restart-${MODE}.md"
log_file="$REPORT_DIR/${stamp}-service-restart-${MODE}.log"
status="PASS"
summary="Restart preview complete."

log_event() {
  local state="$1"
  local topic="$2"
  local text="$3"
  if [ -x ./runners/log_event.sh ]; then
    ./runners/log_event.sh \
      internal-ai-company-os \
      INTERNAL-085 \
      devops_agent \
      post_update_service_restart \
      "$state" \
      runners/post_update_service_restart.sh \
      "$topic" \
      "$text" >/dev/null 2>&1 || true
  fi
}

write_report() {
  {
    echo "# Post-Update Service Restart"
    echo "- generated_at: $timestamp"
    echo "- mode: $MODE"
    echo "- status: $status"
    echo "- report: $report"
    echo "- log: $log_file"
    echo "- owner_switch: $AI_COMPANY_OS_OWNER_SWITCH"
    echo "- emergency_stop: $AI_COMPANY_AGENT_EMERGENCY_STOP"
    echo "- auto_restart_services: $AI_COMPANY_AUTO_RESTART_SERVICES"
    echo "- summary: $summary"
    echo
    echo "## Planned Services"
    if [ "${#planned_services[@]}" -eq 0 ]; then
      echo "- none"
    else
      printf -- "- %s\n" "${planned_services[@]}"
    fi
    echo
    echo "## Restarted Or Eligible Services"
    if [ "${#services[@]}" -eq 0 ]; then
      echo "- none"
    else
      printf -- "- %s\n" "${services[@]}"
    fi
    echo
    echo "## Skipped By Config"
    if [ "${#skipped[@]}" -eq 0 ]; then
      echo "- none"
    else
      printf -- "- %s\n" "${skipped[@]}"
    fi
  } > "$report"
}

if [ "${#planned_services[@]}" -eq 0 ]; then
  status="PASS"
  summary="No affected services; no restart needed."
  : > "$log_file"
  write_report
  echo "No affected services. Report: $report"
  exit 0
fi

if [ "${#services[@]}" -eq 0 ]; then
  status="WARN"
  summary="Affected services were detected, but all are disabled by restart category config."
  : > "$log_file"
  write_report
  echo "$summary Report: $report"
  exit 0
fi

if [ "$MODE" = "dry-run" ]; then
  status="PASS"
  summary="Dry run only; no services restarted."
  : > "$log_file"
  write_report
  echo "Dry run affected services:"
  printf -- "- %s\n" "${services[@]}"
  echo "Report: $report"
  exit 0
fi

if [ "$AI_COMPANY_OS_OWNER_SWITCH" != "ON" ]; then
  status="FAIL"
  summary="Owner switch is not ON; refusing service restart."
  : > "$log_file"
  write_report
  echo "ERROR: $summary Report: $report" >&2
  log_event "FAIL" "Post-update restart blocked" "$summary"
  exit 1
fi

if [ "$AI_COMPANY_AGENT_EMERGENCY_STOP" = "1" ]; then
  status="FAIL"
  summary="Emergency stop is active; refusing service restart."
  : > "$log_file"
  write_report
  echo "ERROR: $summary Report: $report" >&2
  log_event "FAIL" "Post-update restart blocked" "$summary"
  exit 1
fi

if ! ./runners/ai_company_work_hours_gate.sh >/tmp/ai-company-post-update-work-hours.out 2>&1; then
  status="FAIL"
  summary="Work-hours gate is closed; refusing service restart."
  cp /tmp/ai-company-post-update-work-hours.out "$log_file" || true
  write_report
  echo "ERROR: $summary Report: $report" >&2
  log_event "FAIL" "Post-update restart blocked" "$summary"
  exit 1
fi

set +e
./runners/ai_company_budget_gate.sh >/tmp/ai-company-post-update-budget.out 2>&1
budget_status=$?
set -e
if [ "$budget_status" -eq 2 ]; then
  status="FAIL"
  summary="Budget gate is STOP; refusing service restart."
  cp /tmp/ai-company-post-update-budget.out "$log_file" || true
  write_report
  echo "ERROR: $summary Report: $report" >&2
  log_event "FAIL" "Post-update restart blocked" "$summary"
  exit 1
fi

if [ "$SKIP_PRECHECK" != "1" ]; then
  if ! ./runners/pre_commit_check.sh >"$log_file" 2>&1; then
    status="FAIL"
    summary="Pre-commit safety check failed; refusing service restart."
    write_report
    echo "ERROR: $summary Report: $report" >&2
    log_event "FAIL" "Post-update restart blocked" "$summary"
    exit 1
  fi
else
  echo "Precheck skipped by explicit --skip-precheck." > "$log_file"
fi

log_event "RUNNING" "Post-update restart started" "Restarting ${#services[@]} affected service(s)."

restart_failed=0
for service in "${services[@]}"; do
  echo "Restarting $service" | tee -a "$log_file"
  if sudo systemctl restart "$service" >>"$log_file" 2>&1; then
    echo "Restarted $service" | tee -a "$log_file"
  else
    echo "FAILED to restart $service" | tee -a "$log_file"
    restart_failed=1
  fi
done

if [ "$restart_failed" -ne 0 ]; then
  status="FAIL"
  summary="One or more affected services failed to restart."
  write_report
  log_event "FAIL" "Post-update restart failed" "$summary"
  echo "ERROR: $summary Report: $report" >&2
  exit 1
fi

if ./runners/post_update_health_recovery.sh >>"$log_file" 2>&1; then
  status="PASS"
  summary="Affected services restarted and health recovery checks passed."
  write_report
  log_event "DONE" "Post-update restart complete" "$summary"
  echo "$summary Report: $report"
else
  status="WARN"
  summary="Affected services restarted, but health recovery reported warnings or failures."
  write_report
  log_event "WARN" "Post-update health recovery warning" "$summary"
  echo "WARN: $summary Report: $report" >&2
  exit 1
fi
