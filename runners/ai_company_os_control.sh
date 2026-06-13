#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ACTION="${1:-status}"
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
: "${AI_COMPANY_OS_MODE:=OFF}"
: "${AI_COMPANY_OS_ACTIVE_AGENT:=}"
: "${AI_COMPANY_OS_LATEST_EVENT:=}"
: "${AI_COMPANY_OS_LATEST_DISCOVERY_REPORT:=}"

shell_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

write_state() {
  local owner_switch="$1"
  local mode="$2"
  local event="$3"
  local updated_at
  updated_at="$(date -Iseconds)"

  {
    printf "AI_COMPANY_OS_OWNER_SWITCH=%s\n" "$(shell_quote "$owner_switch")"
    printf "AI_COMPANY_OS_MODE=%s\n" "$(shell_quote "$mode")"
    printf "AI_COMPANY_OS_ACTIVE_AGENT=%s\n" "$(shell_quote "$AI_COMPANY_OS_ACTIVE_AGENT")"
    printf "AI_COMPANY_OS_LATEST_EVENT=%s\n" "$(shell_quote "$event")"
    printf "AI_COMPANY_OS_LATEST_DISCOVERY_REPORT=%s\n" "$(shell_quote "$AI_COMPANY_OS_LATEST_DISCOVERY_REPORT")"
    printf "AI_COMPANY_OS_UPDATED_AT=%s\n" "$(shell_quote "$updated_at")"
  } > "$STATE_FILE.tmp"

  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

log_control_event() {
  local state="$1"
  local topic="$2"
  local summary="$3"

  if [ -x ./runners/log_event.sh ]; then
    ./runners/log_event.sh \
      "$PROJECT_KEY" \
      "$TASK_KEY" \
      "pm_agent" \
      "ai_company_os_control" \
      "$state" \
      "owner_dashboard" \
      "$topic" \
      "$summary" >/dev/null 2>&1 || true
  fi
}

case "$ACTION" in
  on|ON|enable|start)
    write_state "ON" "RUNNING" "AI Company OS turned ON by owner"
    log_control_event "RUNNING" "AI Company OS ON" "Owner turned AI Company OS master autonomous mode ON."
    ;;
  off|OFF|disable|stop)
    write_state "OFF" "PAUSED_BY_OWNER" "AI Company OS turned OFF by owner"
    log_control_event "PAUSED_BY_OWNER" "AI Company OS OFF" "Owner turned AI Company OS master autonomous mode OFF."
    ;;
  status)
    ;;
  *)
    echo "Usage: $0 on|off|status"
    exit 2
    ;;
esac

exec ./runners/ai_company_os_status.sh
