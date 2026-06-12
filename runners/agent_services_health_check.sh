#!/usr/bin/env bash
set -euo pipefail

AGENTS=(
  pm_agent
  engineer_agent
  qa_agent
  devops_agent
)

echo "# Agent Services Health Check"

echo
echo "## Script syntax checks"
bash -n runners/agent_worker_loop.sh
bash -n runners/agent_autonomous_loop.sh
bash -n runners/autonomous_agent_dispatcher.sh
bash -n runners/update_agent_runtime_status.sh
bash -n runners/agent_runtime_status.sh
bash -n runners/agent_queue.sh

echo
echo "## Emergency stop"
if [ "${AI_COMPANY_AGENT_EMERGENCY_STOP:-0}" = "1" ]; then
  echo "FAIL: AI_COMPANY_AGENT_EMERGENCY_STOP=1 in current shell."
  exit 1
fi
echo "Emergency stop is not active in current shell."

check_service_health() {
  local service="$1"
  local active_state sub_state result exec_status

  active_state="$(systemctl show "$service" -p ActiveState --value 2>/dev/null || true)"
  sub_state="$(systemctl show "$service" -p SubState --value 2>/dev/null || true)"
  result="$(systemctl show "$service" -p Result --value 2>/dev/null || true)"
  exec_status="$(systemctl show "$service" -p ExecMainStatus --value 2>/dev/null || true)"

  if [ "$active_state" = "active" ]; then
    echo "- $service: active"
    return 0
  fi

  if [ "$active_state" = "activating" ] && [ "$sub_state" = "auto-restart" ]; then
    if [ "$exec_status" = "0" ] || [ "$result" = "success" ]; then
      echo "- $service: healthy auto-restart after successful bounded loop"
      return 0
    fi
  fi

  echo "- $service: NOT healthy active_state=$active_state sub_state=$sub_state result=$result exec_status=$exec_status"
  systemctl status "$service" --no-pager -l || true
  return 1
}

echo
echo "## Service status"
FAILED=0

for agent in "${AGENTS[@]}"; do
  service="ai-company-agent@${agent}.service"
  check_service_health "$service" || FAILED=1
done

echo
echo "## Runtime status"
./runners/agent_runtime_status.sh || FAILED=1

echo
echo "## Queue readability"
for agent in "${AGENTS[@]}"; do
  echo
  echo "### Queue: $agent"
  ./runners/agent_queue.sh "$agent" || FAILED=1
done

echo
echo "## Recent crash indicators"
for agent in "${AGENTS[@]}"; do
  service="ai-company-agent@${agent}.service"
  recent="$(journalctl -u "$service" --since "10 minutes ago" --no-pager 2>/dev/null || true)"

  if printf "%s\n" "$recent" | grep -Eiq "Failed with result|status=2|status=1|Traceback|ReferenceError|SyntaxError"; then
    echo "- $service: recent error detected"
    printf "%s\n" "$recent" | tail -40
    FAILED=1
  else
    echo "- $service: no recent crash indicators"
  fi
done

if [ "$FAILED" -ne 0 ]; then
  echo
  echo "Agent services health check FAILED."
  exit 1
fi

echo
echo "Agent services health check passed."
