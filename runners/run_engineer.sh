#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-}"
TASK_FILE="${2:-TASK.md}"
PROJECT_KEY="${3:-}"
TASK_KEY="${4:-}"

if [ -z "$PROJECT_DIR" ]; then
  echo "Usage: ./runners/run_engineer.sh <project_dir> [task_file] [project_key] [task_key]"
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

exec > >(tee "$LOG_FILE") 2>&1

echo "Engineer Agent Runner"
echo "Project: $ABS_PROJECT_DIR"
echo "Task: $TASK_FILE"
echo "Time: $(date)"
echo "Log: $LOG_FILE"
echo

cd "$ROOT_DIR"

if [ -n "$PROJECT_KEY" ] && [ -n "$TASK_KEY" ]; then
  ./runners/update_task_status.sh \
    "$TASK_KEY" \
    "IN_PROGRESS" \
    "Engineer runner started for $PROJECT_DIR using $TASK_FILE."

  ./runners/log_event.sh \
    "$PROJECT_KEY" \
    "$TASK_KEY" \
    "engineer_agent" \
    "engineering_started" \
    "IN_PROGRESS" \
    "engineering_desk" \
    "Engineer runner started" \
    "Engineer runner started for $PROJECT_DIR using $TASK_FILE."
else
  echo "Start event/status update skipped. PROJECT_KEY and TASK_KEY were not provided."
fi

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
- build/test result written in AGENT_HANDOVER.md"

ENGINEER_RESULT="DONE"

if [ ! -f "$ABS_PROJECT_DIR/AGENT_HANDOVER.md" ]; then
  ENGINEER_RESULT="FAIL"
fi

echo
echo "ENGINEER_RESULT=$ENGINEER_RESULT"

cd "$ROOT_DIR"

if [ -n "$PROJECT_KEY" ] && [ -n "$TASK_KEY" ]; then
  ./runners/update_task_status.sh \
    "$TASK_KEY" \
    "$ENGINEER_RESULT" \
    "Engineer runner completed for $PROJECT_DIR with result: $ENGINEER_RESULT. Log: $LOG_FILE"

  ./runners/log_event.sh \
    "$PROJECT_KEY" \
    "$TASK_KEY" \
    "engineer_agent" \
    "engineering_completed" \
    "$ENGINEER_RESULT" \
    "engineering_desk" \
    "Engineer runner completed" \
    "Engineer runner completed for $PROJECT_DIR with result: $ENGINEER_RESULT. Log: $LOG_FILE"
else
  echo "Completion event/status update skipped. PROJECT_KEY and TASK_KEY were not provided."
fi

echo
echo "Engineer run completed. Log saved to $LOG_FILE"
