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
QA_MODE="unknown"

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

if [ -f AGENT_HANDOVER.md ]; then
  HANDOVER_STATUS="PASS"
else
  HANDOVER_STATUS="FAIL"
fi

if [ -f package.json ]; then
  QA_MODE="node_project"
  echo "QA mode: node_project"
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
    QA_RESULT="FAIL"
    QA_NOTES="npm is not installed."
  fi

elif [ -f index.html ] || [ -f styles.css ] || [ -f script.js ]; then
  QA_MODE="static_site"
  echo "QA mode: static_site"

  if [ -f index.html ] && [ -f styles.css ] && [ -f script.js ]; then
    QA_RESULT="PASS"
    QA_NOTES="Static files exist: index.html, styles.css, script.js."
  else
    QA_RESULT="FAIL"
    QA_NOTES="Missing one or more static files."
  fi

elif find . -maxdepth 2 -type f -name "*.md" | grep -q .; then
  QA_MODE="documentation"
  echo "QA mode: documentation"

  MD_COUNT="$(find . -maxdepth 2 -type f -name "*.md" | wc -l)"
  echo "Markdown files found: $MD_COUNT"

  if [ "$HANDOVER_STATUS" = "PASS" ] && [ "$MD_COUNT" -ge 1 ]; then
    QA_RESULT="PASS"
    QA_NOTES="Documentation task passed. Markdown files and AGENT_HANDOVER.md exist."
  else
    QA_RESULT="FAIL"
    QA_NOTES="Documentation task failed. Missing AGENT_HANDOVER.md or markdown output."
  fi

elif find . -maxdepth 2 -type f -name "*.sh" | grep -q .; then
  QA_MODE="shell_scripts"
  echo "QA mode: shell_scripts"

  FAIL_COUNT=0
  while IFS= read -r script; do
    echo "Checking syntax: $script"
    if ! bash -n "$script"; then
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  done < <(find . -maxdepth 2 -type f -name "*.sh")

  if [ "$FAIL_COUNT" -eq 0 ] && [ "$HANDOVER_STATUS" = "PASS" ]; then
    QA_RESULT="PASS"
    QA_NOTES="Shell scripts passed bash syntax check and AGENT_HANDOVER.md exists."
  else
    QA_RESULT="FAIL"
    QA_NOTES="One or more shell scripts failed syntax check or AGENT_HANDOVER.md is missing."
  fi

else
  QA_MODE="generic"
  echo "QA mode: generic"

  if [ "$HANDOVER_STATUS" = "PASS" ]; then
    QA_RESULT="PASS"
    QA_NOTES="Generic QA passed because AGENT_HANDOVER.md exists."
  else
    QA_RESULT="FAIL"
    QA_NOTES="Generic QA failed because AGENT_HANDOVER.md is missing."
  fi
fi

if [ "$HANDOVER_STATUS" != "PASS" ]; then
  QA_RESULT="FAIL"
fi

echo
echo "QA_MODE=$QA_MODE"
echo "QA_RESULT=$QA_RESULT"
echo "HANDOVER_STATUS=$HANDOVER_STATUS"
echo "Log saved to: $LOG_FILE"

cat > qa_report.md << REPORT
# QA Report

Project: $PROJECT_DIR
QA Agent: automated QA runner
Time: $(date)

Checks:
- QA mode detected: $QA_MODE
- package/static/docs/scripts checked based on project shape
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
  if [ "$QA_RESULT" = "PASS" ]; then
    if [[ "$TASK_KEY" == INTERNAL-* ]]; then
      FINAL_TASK_STATUS="DONE"
    else
      FINAL_TASK_STATUS="WAITING_OWNER_ACCEPTANCE"
    fi
  else
    FINAL_TASK_STATUS="QA_FAILED"
  fi

  ./runners/update_task_status.sh \
    "$TASK_KEY" \
    "$FINAL_TASK_STATUS" \
    "QA runner completed for $PROJECT_DIR with result: $QA_RESULT. Mode: $QA_MODE. Notes: $QA_NOTES"

  ./runners/log_event.sh \
    "$PROJECT_KEY" \
    "$TASK_KEY" \
    "qa_agent" \
    "qa_completed" \
    "$QA_RESULT" \
    "qa_room" \
    "Automated QA completed" \
    "QA runner completed for $PROJECT_DIR with result: $QA_RESULT. Mode: $QA_MODE. Notes: $QA_NOTES"
else
  echo "Event/status update skipped. PROJECT_KEY and TASK_KEY were not provided."
fi
