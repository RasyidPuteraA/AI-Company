#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-}"
PROJECT_KEY="${2:-}"
TASK_KEY="${3:-}"

if [ -z "$PROJECT_DIR" ]; then
  echo "Usage: ./runners/run_qa.sh <project_dir> [project_key] [task_key]"
  exit 1
fi

ROOT_DIR="/opt/ai-company"
ABS_PROJECT_DIR="$ROOT_DIR/$PROJECT_DIR"
LOG_DIR="$ROOT_DIR/logs/runners"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/qa-$TIMESTAMP.log"
QA_RESULT="FAIL"
QA_NOTES=""

if [ ! -d "$ABS_PROJECT_DIR" ]; then
  echo "Project directory not found: $ABS_PROJECT_DIR"
  exit 1
fi

mkdir -p "$LOG_DIR"

exec > >(tee "$LOG_FILE") 2>&1

cd "$ABS_PROJECT_DIR"

echo "# QA Runner Log"
echo "Project: $ABS_PROJECT_DIR"
echo "Time: $(date)"
echo

if [ -f package.json ]; then
  echo "package.json found."

  if command -v npm >/dev/null 2>&1; then
    echo "Running npm test..."
    if npm test; then
      QA_RESULT="PASS"
      QA_NOTES="npm test passed."
    else
      QA_RESULT="FAIL"
      QA_NOTES="npm test failed."
    fi
  else
    echo "npm not found."
    QA_RESULT="FAIL"
    QA_NOTES="npm is not installed."
  fi
else
  echo "No package.json found. Checking static files..."

  if [ -f index.html ] && [ -f styles.css ] && [ -f script.js ]; then
    QA_RESULT="PASS"
    QA_NOTES="Static files exist: index.html, styles.css, script.js."
  else
    QA_RESULT="FAIL"
    QA_NOTES="Missing one or more static files."
  fi
fi

if [ -f AGENT_HANDOVER.md ]; then
  HANDOVER_STATUS="PASS"
else
  HANDOVER_STATUS="FAIL"
  QA_RESULT="FAIL"
fi

echo
echo "QA_RESULT=$QA_RESULT"
echo "HANDOVER_STATUS=$HANDOVER_STATUS"
echo "Log saved to: $LOG_FILE"

cat > qa_report.md << REPORT
# QA Report

Project: $PROJECT_DIR
QA Agent: automated QA runner
Time: $(date)

Checks:
- package/static files checked
- build/test command executed when available
- AGENT_HANDOVER.md presence checked: $HANDOVER_STATUS

Result:
$QA_RESULT

Notes:
$QA_NOTES

Runner log:
$LOG_FILE
REPORT

echo
echo "QA report written to $ABS_PROJECT_DIR/qa_report.md"

cd "$ROOT_DIR"

if [ -n "$PROJECT_KEY" ] && [ -n "$TASK_KEY" ]; then
  ./runners/log_event.sh \
    "$PROJECT_KEY" \
    "$TASK_KEY" \
    "qa_agent" \
    "qa_completed" \
    "$QA_RESULT" \
    "qa_room" \
    "Automated QA completed" \
    "QA runner completed for $PROJECT_DIR with result: $QA_RESULT. Notes: $QA_NOTES"
else
  echo "Event logging skipped. PROJECT_KEY and TASK_KEY were not provided."
fi
