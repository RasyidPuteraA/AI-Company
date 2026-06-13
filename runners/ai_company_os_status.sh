#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

FORMAT="${1:-text}"
CONFIG="company/config/ai_company_os.env"
STATE_DIR="company/runtime/ai-company-os"
STATE_FILE="$STATE_DIR/state.env"

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
: "${AI_COMPANY_OS_MODE:=OFF}"
: "${AI_COMPANY_OS_ACTIVE_AGENT:=}"
: "${AI_COMPANY_OS_LATEST_EVENT:=}"
: "${AI_COMPANY_OS_STATUS_NOTE:=}"
: "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:=}"
: "${AI_COMPANY_OS_UPDATED_AT:=}"
: "${AI_COMPANY_AUTOSOLVE_ENABLED:=1}"
: "${AI_COMPANY_CLIENT_PRIORITY:=1}"
: "${AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED:=1}"
: "${AI_COMPANY_MAX_AUTONOMOUS_ITERATIONS:=1}"
: "${AI_COMPANY_DISCOVERY_ONLY_AFTER_RESOLUTION:=1}"

set +e
work_output="$(./runners/ai_company_work_hours_gate.sh 2>&1)"
work_status=$?
budget_output="$(./runners/ai_company_budget_gate.sh 2>&1)"
budget_status=$?
set -e

work_state="$(printf "%s\n" "$work_output" | awk -F= '$1=="WORK_HOURS_STATE"{print $2}' | tail -1)"
budget_state="$(printf "%s\n" "$budget_output" | awk -F= '$1=="BUDGET_STATE"{print $2}' | tail -1)"
budget_note="$(printf "%s\n" "$budget_output" | awk -F= '$1=="BUDGET_NOTE"{print $2}' | tail -1)"

: "${work_state:=UNKNOWN}"
: "${budget_state:=UNKNOWN}"

effective_mode="$AI_COMPANY_OS_MODE"
effective_active_agent="$AI_COMPANY_OS_ACTIVE_AGENT"
if [ "$AI_COMPANY_OS_OWNER_SWITCH" != "ON" ]; then
  effective_mode="PAUSED_BY_OWNER"
  effective_active_agent=""
elif [ "$work_status" -ne 0 ]; then
  effective_mode="PAUSED_OUTSIDE_WORK_HOURS"
  effective_active_agent=""
elif [ "$budget_status" -eq 2 ] || [ "$budget_state" = "STOP" ]; then
  effective_mode="PAUSED_BUDGET_LIMIT"
  effective_active_agent=""
elif [ -z "$effective_mode" ] || [ "$effective_mode" = "OFF" ] || [[ "$effective_mode" == PAUSED_* ]]; then
  effective_mode="RUNNING"
fi

latest_report="$(find company/reports/autonomous-discovery -maxdepth 1 -type f -name '*-discovery.md' 2>/dev/null | sort | tail -1 || true)"
if [ -z "$AI_COMPANY_OS_LATEST_DISCOVERY_REPORT" ] && [ -n "$latest_report" ]; then
  AI_COMPANY_OS_LATEST_DISCOVERY_REPORT="$latest_report"
fi

latest_event="$AI_COMPANY_OS_LATEST_EVENT"
if [ "$AI_COMPANY_OS_OWNER_SWITCH" = "ON" ] && command -v docker >/dev/null 2>&1; then
  db_event="$(docker exec -i ai_company_postgres psql -U ai_company -d ai_company -t -A -F '|' -c "
    SELECT COALESCE(event_type,''), COALESCE(agent_key,''), COALESCE(state,''), COALESCE(topic,''), created_at
    FROM events
    ORDER BY id DESC
    LIMIT 1;
  " 2>/dev/null || true)"
  if [ -n "$db_event" ]; then
    latest_event="$db_event"
  fi
fi

scheduler_json="{}"
if [ -x ./runners/ai_company_scheduler_status.sh ]; then
  scheduler_json="$(./runners/ai_company_scheduler_status.sh --json 2>/dev/null || printf '{}')"
fi

if [ "$FORMAT" = "--json" ] || [ "$FORMAT" = "json" ]; then
  python3 - "$AI_COMPANY_OS_OWNER_SWITCH" "$effective_mode" "$effective_active_agent" \
    "$work_state" "$budget_state" "$budget_note" "$latest_event" \
    "$AI_COMPANY_OS_STATUS_NOTE" "$AI_COMPANY_OS_LATEST_DISCOVERY_REPORT" "$AI_COMPANY_OS_UPDATED_AT" \
    "$AI_COMPANY_AUTOSOLVE_ENABLED" "$AI_COMPANY_CLIENT_PRIORITY" \
    "$AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED" "$AI_COMPANY_MAX_AUTONOMOUS_ITERATIONS" \
    "$AI_COMPANY_DISCOVERY_ONLY_AFTER_RESOLUTION" "$scheduler_json" <<'PY'
import json
import sys

keys = [
    "owner_switch",
    "mode",
    "active_agent",
    "work_hours_state",
    "budget_state",
    "budget_note",
    "latest_event",
    "status_note",
    "latest_discovery_report",
    "updated_at",
    "autosolve_enabled",
    "client_priority",
    "internal_idle_work_enabled",
    "max_autonomous_iterations",
    "discovery_only_after_resolution",
    "scheduler_raw",
]
data = dict(zip(keys, sys.argv[1:]))
data["enabled"] = data["owner_switch"] == "ON"
try:
    data["scheduler"] = json.loads(data.pop("scheduler_raw") or "{}")
except json.JSONDecodeError:
    data["scheduler"] = {}
print(json.dumps(data, indent=2))
PY
  exit 0
fi

echo "# AI Company OS Status"
echo "- owner_switch: $AI_COMPANY_OS_OWNER_SWITCH"
echo "- mode: $effective_mode"
echo "- active_agent: ${effective_active_agent:-none}"
echo "- work_hours_state: $work_state"
echo "- budget_state: $budget_state"
echo "- budget_note: ${budget_note:-Internal AI Company budget estimate.}"
echo "- latest_event: ${latest_event:-none}"
echo "- status_note: ${AI_COMPANY_OS_STATUS_NOTE:-none}"
echo "- latest_discovery_report: ${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:-none}"
echo "- updated_at: ${AI_COMPANY_OS_UPDATED_AT:-unknown}"
echo
if [ -x ./runners/ai_company_scheduler_status.sh ]; then
  ./runners/ai_company_scheduler_status.sh
fi
