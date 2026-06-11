#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-}"
TASK_FILE="${2:-TASK.md}"

if [ -z "$PROJECT_DIR" ]; then
  echo "Usage: ./runners/run_engineer.sh <project_dir> [task_file]"
  exit 1
fi

ROOT_DIR="/opt/ai-company"
ABS_PROJECT_DIR="$ROOT_DIR/$PROJECT_DIR"
LOG_DIR="$ROOT_DIR/logs/runners"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/engineer-$TIMESTAMP.log"

if [ ! -d "$ABS_PROJECT_DIR" ]; then
  echo "Project directory not found: $ABS_PROJECT_DIR"
  exit 1
fi

if [ ! -f "$ABS_PROJECT_DIR/$TASK_FILE" ]; then
  echo "Task file not found: $ABS_PROJECT_DIR/$TASK_FILE"
  exit 1
fi

mkdir -p "$LOG_DIR"

echo "Engineer Agent Runner"
echo "Project: $ABS_PROJECT_DIR"
echo "Task: $TASK_FILE"
echo "Log: $LOG_FILE"

cd "$ABS_PROJECT_DIR"

codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  "You are the Engineer Agent for AI Company OS.

Read $TASK_FILE and implement the requested work.

Safety rules:
- Work only inside the current folder: $ABS_PROJECT_DIR
- Do not modify /opt/ai-company/docker-compose.yml
- Do not modify /opt/ai-company/company
- Do not modify /etc
- Do not modify SSH, firewall, Docker daemon, PostgreSQL, Redis, or system files
- Do not access secrets
- Do not deploy anything
- Do not use sudo
- Prefer no external dependencies unless the task explicitly requires them

Required output:
- implementation files
- AGENT_HANDOVER.md
- build/test result written in AGENT_HANDOVER.md" | tee "$LOG_FILE"

echo "Engineer run completed. Log saved to $LOG_FILE"
