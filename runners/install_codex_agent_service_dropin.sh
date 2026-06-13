#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---dry-run}"

if [ "$MODE" != "--dry-run" ] && [ "$MODE" != "--apply" ]; then
  echo "Usage: $0 [--dry-run|--apply]"
  exit 1
fi

DROPIN_DIR="/etc/systemd/system/ai-company-agent@.service.d"
DROPIN_FILE="$DROPIN_DIR/10-codex-loop.conf"

cat <<'CONFIG'
# AI Company OS Codex-enabled agent service drop-in
# This enables the managed agent services to use the Codex-enabled worker loop.
#
# Safety:
# - Codex dispatcher is explicit.
# - Worker loop remains bounded.
# - Existing eligibility gates still apply.
# - No secrets are stored here.
#
# Target drop-in:
# /etc/systemd/system/ai-company-agent@.service.d/10-codex-loop.conf

[Service]
Environment=HOME=/home/ubuntu
Environment=PATH=/home/ubuntu/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=AI_COMPANY_ALLOW_AFTER_HOURS=1
Environment=AI_COMPANY_AGENT_EMERGENCY_STOP=0
Environment=AI_COMPANY_ENABLE_CODEX_DISPATCHER=1
ExecStart=
ExecStart=/opt/ai-company/runners/agent_worker_loop_with_codex.sh %i --loop --interval 10 --max-iterations 1
RestartSec=30
CONFIG

if [ "$MODE" = "--dry-run" ]; then
  echo
  echo "Dry-run only. No systemd files changed."
  exit 0
fi

sudo mkdir -p "$DROPIN_DIR"

if [ -f "$DROPIN_FILE" ]; then
  sudo cp "$DROPIN_FILE" "$DROPIN_FILE.bak.$(date +%Y%m%d%H%M%S)"
fi

sudo tee "$DROPIN_FILE" >/dev/null <<'CONFIG'
# AI Company OS Codex-enabled agent service drop-in
# Managed by runners/install_codex_agent_service_dropin.sh

[Service]
Environment=HOME=/home/ubuntu
Environment=PATH=/home/ubuntu/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=AI_COMPANY_ALLOW_AFTER_HOURS=1
Environment=AI_COMPANY_AGENT_EMERGENCY_STOP=0
Environment=AI_COMPANY_ENABLE_CODEX_DISPATCHER=1
ExecStart=
ExecStart=/opt/ai-company/runners/agent_worker_loop_with_codex.sh %i --loop --interval 10 --max-iterations 1
RestartSec=30
CONFIG

sudo systemctl daemon-reload

echo "Installed:"
echo "$DROPIN_FILE"
