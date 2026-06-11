#!/usr/bin/env bash
set -euo pipefail

AGENT_KEY="${1:-}"
ACTION="${2:-status}"
LINES="${3:-60}"

if [ -z "$AGENT_KEY" ]; then
  echo "Usage:"
  echo "  ./runners/worker_service_control.sh <agent_key> status"
  echo "  ./runners/worker_service_control.sh <agent_key> start"
  echo "  ./runners/worker_service_control.sh <agent_key> stop"
  echo "  ./runners/worker_service_control.sh <agent_key> logs"
  echo "  ./runners/worker_service_control.sh <agent_key> reset-failed"
  echo "  ./runners/worker_service_control.sh <agent_key> enabled"
  echo "  ./runners/worker_service_control.sh <agent_key> config"
  exit 1
fi

SERVICE="ai-company-agent-worker@${AGENT_KEY}.service"
PROJECT_KEY="internal-ai-company-os"

print_header() {
  echo "# AI Company Worker Service Control"
  echo "- Agent: $AGENT_KEY"
  echo "- Service: $SERVICE"
  echo "- Action: $ACTION"
  echo "- Time: $(date)"
  echo
}

show_safety_note() {
  echo "Safety note:"
  echo "- This wrapper does not enable autonomous startup."
  echo "- Service remains disabled unless Owner explicitly enables it."
  echo "- Start may be blocked outside work hours by agent_worker_loop.sh."
  echo
}

case "$ACTION" in
  status)
    print_header
    systemctl status "$SERVICE" --no-pager || true
    echo
    systemctl is-enabled "$SERVICE" || true
    ;;

  start)
    print_header
    show_safety_note

    if sudo systemctl start "$SERVICE"; then
      echo "Service start completed."
      ./runners/log_event.sh \
        "$PROJECT_KEY" \
        "INTERNAL-018" \
        "devops_agent" \
        "worker_service_started" \
        "STARTED" \
        "server_room" \
        "Worker service start requested" \
        "Owner started $SERVICE through worker_service_control.sh"
    else
      echo
      echo "Service start failed or was blocked by safety guard."
      echo "Recent logs:"
      sudo journalctl -u "$SERVICE" -n 40 --no-pager || true
      exit 2
    fi
    ;;

  stop)
    print_header
    sudo systemctl stop "$SERVICE" || true
    echo "Service stopped or already inactive."
    ./runners/log_event.sh \
      "$PROJECT_KEY" \
      "INTERNAL-018" \
      "devops_agent" \
      "worker_service_stopped" \
      "STOPPED" \
      "server_room" \
      "Worker service stop requested" \
      "Owner stopped $SERVICE through worker_service_control.sh"
    ;;

  logs)
    print_header
    sudo journalctl -u "$SERVICE" -n "$LINES" --no-pager || true
    ;;

  reset-failed)
    print_header
    sudo systemctl reset-failed "$SERVICE"
    echo "Failed state reset for $SERVICE"
    ;;

  enabled)
    print_header
    systemctl is-enabled "$SERVICE" || true
    ;;

  config)
    print_header
    echo "Systemd template:"
    systemctl cat ai-company-agent-worker@.service
    echo
    echo "Environment file:"
    sudo cat /etc/ai-company/agent-worker.env
    ;;

  *)
    echo "Unknown action: $ACTION"
    echo "Allowed actions: status, start, stop, logs, reset-failed, enabled, config"
    exit 1
    ;;
esac
