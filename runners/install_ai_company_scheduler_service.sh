#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SERVICE_FILE="/etc/systemd/system/ai-company-multi-agent-scheduler.service"
ROOT_DIR="$(pwd)"
USER_NAME="${AI_COMPANY_SERVICE_USER:-$(id -un)}"
GROUP_NAME="${AI_COMPANY_SERVICE_GROUP:-$(id -gn)}"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run with sudo to install the systemd service file."
  echo "Example: sudo ./runners/install_ai_company_scheduler_service.sh"
  exit 1
fi

tmp_file="$(mktemp)"
cat > "$tmp_file" <<SERVICE
[Unit]
Description=AI Company OS Multi-Agent Autonomous Scheduler
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER_NAME
Group=$GROUP_NAME
WorkingDirectory=$ROOT_DIR
Environment=AI_COMPANY_SCHEDULER_MAX_ITERATIONS=1
ExecStart=/bin/bash -lc 'while true; do ./runners/ai_company_multi_agent_scheduler.sh; sleep \${AI_COMPANY_SCHEDULER_INTERVAL_SECONDS:-60}; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

install -m 0644 "$tmp_file" "$SERVICE_FILE"
rm -f "$tmp_file"
systemctl daemon-reload

echo "Installed: $SERVICE_FILE"
echo
echo "The service was not enabled or started."
echo "Owner commands:"
echo "  sudo systemctl enable ai-company-multi-agent-scheduler.service"
echo "  sudo systemctl start ai-company-multi-agent-scheduler.service"
echo "  systemctl status ai-company-multi-agent-scheduler.service --no-pager"
