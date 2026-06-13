#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

FORMAT="${1:-text}"
CONFIG="company/config/ai_company_scheduler.env"
STATE_DIR="company/runtime/ai-company-scheduler"
STATE_FILE="$STATE_DIR/state.env"
ROLE_DIR="$STATE_DIR/roles"
LOCK_DIR="company/runtime/locks"

mkdir -p "$STATE_DIR" "$ROLE_DIR" "$LOCK_DIR"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

if [ -f "$STATE_FILE" ] && bash -n "$STATE_FILE" 2>/dev/null; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

: "${AI_COMPANY_SCHEDULER_ENABLED:=1}"
: "${AI_COMPANY_SCHEDULER_STATE:=UNKNOWN}"
: "${AI_COMPANY_SCHEDULER_MODE:=unknown}"
: "${AI_COMPANY_SCHEDULER_ACTIVE_AGENTS:=}"
: "${AI_COMPANY_SCHEDULER_LATEST_EVENT:=}"
: "${AI_COMPANY_SCHEDULER_UPDATED_AT:=}"
: "${AI_COMPANY_MAX_PARALLEL_AGENTS:=2}"

lock_state() {
  local name="$1"
  local file="$LOCK_DIR/$name.lock"
  local holder="$file.holder"

  mkdir -p "$LOCK_DIR"
  exec {fd}>"$file"
  if flock -n "$fd"; then
    flock -u "$fd"
    if [ -f "$holder" ]; then
      echo "stale-holder:$(tr '\n' ' ' < "$holder")"
    else
      echo "free"
    fi
  else
    if [ -f "$holder" ]; then
      echo "held:$(tr '\n' ' ' < "$holder")"
    else
      echo "held"
    fi
  fi
  eval "exec ${fd}>&-"
}

role_row() {
  local role="$1"
  local file="$ROLE_DIR/$role.env"
  ROLE_STATE="never_run"
  ROLE_AGENT=""
  ROLE_TASK=""
  ROLE_EVENT=""
  ROLE_UPDATED_AT=""
  if [ -f "$file" ] && bash -n "$file" 2>/dev/null; then
    # shellcheck disable=SC1090
    source "$file"
  fi
  printf "%s|%s|%s|%s|%s|%s\n" "$role" "$ROLE_AGENT" "$ROLE_STATE" "$ROLE_TASK" "$ROLE_EVENT" "$ROLE_UPDATED_AT"
}

roles_text="$(
  for role in pm engineer qa devops; do
    role_row "$role"
  done
)"

locks_text="$(
  for lock in repo_write dashboard devops database qa; do
    printf "%s|%s\n" "$lock" "$(lock_state "$lock")"
  done
)"

if [ "$FORMAT" = "--json" ] || [ "$FORMAT" = "json" ]; then
  python3 - "$AI_COMPANY_SCHEDULER_ENABLED" "$AI_COMPANY_SCHEDULER_STATE" \
    "$AI_COMPANY_SCHEDULER_MODE" "$AI_COMPANY_SCHEDULER_ACTIVE_AGENTS" \
    "$AI_COMPANY_SCHEDULER_LATEST_EVENT" "$AI_COMPANY_SCHEDULER_UPDATED_AT" \
    "$AI_COMPANY_MAX_PARALLEL_AGENTS" "$roles_text" "$locks_text" <<'PY'
import json
import sys

enabled, state, mode, active_agents, latest_event, updated_at, max_parallel, roles_text, locks_text = sys.argv[1:]

roles = []
for line in roles_text.splitlines():
    role, agent, role_state, task, event, role_updated_at = (line.split("|") + [""] * 6)[:6]
    roles.append({
        "role": role,
        "agent": agent,
        "state": role_state,
        "task": task,
        "event": event,
        "updated_at": role_updated_at,
    })

locks = []
for line in locks_text.splitlines():
    name, lock_state = (line.split("|", 1) + [""])[:2]
    locks.append({"name": name, "state": lock_state})

print(json.dumps({
    "enabled": enabled == "1",
    "state": state,
    "mode": mode,
    "active_agents": [item for item in active_agents.split(",") if item],
    "latest_event": latest_event,
    "updated_at": updated_at,
    "max_parallel_agents": int(max_parallel or "2"),
    "roles": roles,
    "locks": locks,
}, indent=2))
PY
  exit 0
fi

echo "# AI Company Scheduler Status"
echo "- enabled: $AI_COMPANY_SCHEDULER_ENABLED"
echo "- state: $AI_COMPANY_SCHEDULER_STATE"
echo "- mode: $AI_COMPANY_SCHEDULER_MODE"
echo "- active_agents: ${AI_COMPANY_SCHEDULER_ACTIVE_AGENTS:-none}"
echo "- max_parallel_agents: $AI_COMPANY_MAX_PARALLEL_AGENTS"
echo "- latest_event: ${AI_COMPANY_SCHEDULER_LATEST_EVENT:-none}"
echo "- updated_at: ${AI_COMPANY_SCHEDULER_UPDATED_AT:-unknown}"
echo
echo "## Roles"
printf "%s\n" "$roles_text" | awk -F'|' '{printf "- %s: %s task=%s event=%s updated_at=%s\n", $1, $3, ($4 ? $4 : "none"), ($5 ? $5 : "none"), ($6 ? $6 : "unknown")}'
echo
echo "## Locks"
printf "%s\n" "$locks_text" | awk -F'|' '{printf "- %s: %s\n", $1, $2}'
