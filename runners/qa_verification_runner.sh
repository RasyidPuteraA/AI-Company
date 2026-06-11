#!/usr/bin/env bash
set -euo pipefail

PROJECT_KEY="${1:-}"
QA_TASK_KEY="${2:-}"

if [[ -z "$PROJECT_KEY" || -z "$QA_TASK_KEY" ]]; then
  echo "Usage:"
  echo "  ./runners/qa_verification_runner.sh <project_key> <qa_task_key>"
  echo
  echo "Example:"
  echo "  ./runners/qa_verification_runner.sh client-company-profile-demo CLIENT-1-QA-001"
  exit 1
fi

if ! [[ "$PROJECT_KEY" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: project_key must use lowercase letters, numbers, and dashes only."
  exit 1
fi

if ! [[ "$QA_TASK_KEY" =~ ^[A-Z0-9-]+$ ]]; then
  echo "ERROR: qa_task_key must use uppercase letters, numbers, and dashes only."
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/projects/clients/$PROJECT_KEY"
QA_TASK_FILE="$PROJECT_DIR/$QA_TASK_KEY.md"
HANDOVER_FILE="$PROJECT_DIR/AGENT_HANDOVER.md"
SITE_DIR="$PROJECT_DIR/site"
REPORT_FILE="$PROJECT_DIR/QA_REPORT-$QA_TASK_KEY.md"

SOURCE_ID="$(echo "$QA_TASK_KEY" | sed -E 's/^CLIENT-([0-9]+)-.*/\1/')"
PM_TASK_KEY="CLIENT-${SOURCE_ID}-001"
ENGINEER_TASK_KEY="CLIENT-${SOURCE_ID}-ENG-001"
PM_ANALYSIS_FILE="$PROJECT_DIR/PM_INTAKE_ANALYSIS-${PM_TASK_KEY}.md"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: project directory not found: $PROJECT_DIR"
  exit 1
fi

if [[ ! -f "$QA_TASK_FILE" ]]; then
  echo "ERROR: QA task file not found: $QA_TASK_FILE"
  exit 1
fi

if [[ ! -f "$PM_ANALYSIS_FILE" ]]; then
  echo "ERROR: PM analysis file not found: $PM_ANALYSIS_FILE"
  exit 1
fi

PASS=true
ISSUES=()

check_file() {
  local file_path="$1"
  local label="$2"
  if [[ ! -f "$file_path" ]]; then
    PASS=false
    ISSUES+=("Missing ${label}: ${file_path}")
  fi
}

check_file "$SITE_DIR/index.html" "site index.html"
check_file "$SITE_DIR/styles.css" "site styles.css"
check_file "$SITE_DIR/app.js" "site app.js"
check_file "$SITE_DIR/README.md" "site README.md"

NODE_CHECK_OUTPUT=""
if [[ -f "$SITE_DIR/app.js" ]]; then
  if NODE_CHECK_OUTPUT="$(node --check "$SITE_DIR/app.js" 2>&1)"; then
    true
  else
    PASS=false
    ISSUES+=("node --check failed for site/app.js")
  fi
fi

CONTENT_CHECK_OUTPUT="$(mktemp)"

python3 - "$SITE_DIR/index.html" "$CONTENT_CHECK_OUTPUT" << 'PY'
from pathlib import Path
import sys

index_file = Path(sys.argv[1])
out_file = Path(sys.argv[2])

checks = []
if index_file.exists():
    text = index_file.read_text().lower()
    checks.append(("has html document", "<!doctype html" in text or "<html" in text))
    checks.append(("has hero section", "hero" in text))
    checks.append(("has services section", "services" in text))
    checks.append(("has contact section", "contact" in text))
else:
    checks.append(("index.html exists", False))

with out_file.open("w") as f:
    for name, ok in checks:
        f.write(f"{name}|{'PASS' if ok else 'FAIL'}\n")
PY

while IFS="|" read -r check_name check_result; do
  [[ -z "${check_name:-}" ]] && continue
  if [[ "$check_result" != "PASS" ]]; then
    PASS=false
    ISSUES+=("Content check failed: $check_name")
  fi
done < "$CONTENT_CHECK_OUTPUT"

rm -f "$CONTENT_CHECK_OUTPUT"

if [[ "$PASS" == true ]]; then
  QA_STATUS="QA_PASSED"
  QA_SUMMARY="QA verification passed for initial implementation output."
else
  QA_STATUS="QA_FAILED"
  QA_SUMMARY="QA verification failed. Issues found."
fi

cat > "$REPORT_FILE" << REPORT
# QA Report: $QA_TASK_KEY

## Project

$PROJECT_KEY

## QA Task

$QA_TASK_KEY

## Source Tasks

- PM task: $PM_TASK_KEY
- Engineer task: $ENGINEER_TASK_KEY

## Files Reviewed

- $QA_TASK_FILE
- $PM_ANALYSIS_FILE
- $SITE_DIR/index.html
- $SITE_DIR/styles.css
- $SITE_DIR/app.js
- $SITE_DIR/README.md

## Verification Checks

### Required Files

- site/index.html: $(if [[ -f "$SITE_DIR/index.html" ]]; then echo "PASS"; else echo "FAIL"; fi)
- site/styles.css: $(if [[ -f "$SITE_DIR/styles.css" ]]; then echo "PASS"; else echo "FAIL"; fi)
- site/app.js: $(if [[ -f "$SITE_DIR/app.js" ]]; then echo "PASS"; else echo "FAIL"; fi)
- site/README.md: $(if [[ -f "$SITE_DIR/README.md" ]]; then echo "PASS"; else echo "FAIL"; fi)

### JavaScript Syntax

Result:

    ${NODE_CHECK_OUTPUT:-PASS}

### Content Checks

REPORT

python3 - "$SITE_DIR/index.html" "$REPORT_FILE" << 'PY'
from pathlib import Path
import sys

index_file = Path(sys.argv[1])
report_file = Path(sys.argv[2])

checks = []
if index_file.exists():
    text = index_file.read_text().lower()
    checks.append(("HTML document exists", "<!doctype html" in text or "<html" in text))
    checks.append(("Hero section present", "hero" in text))
    checks.append(("Services section present", "services" in text))
    checks.append(("Contact section present", "contact" in text))
else:
    checks.append(("index.html exists", False))

with report_file.open("a") as f:
    for name, ok in checks:
        f.write(f"- {name}: {'PASS' if ok else 'FAIL'}\n")
PY

cat >> "$REPORT_FILE" << REPORT

## Issues

REPORT

if [[ ${#ISSUES[@]} -eq 0 ]]; then
  echo "- No blocking issues found." >> "$REPORT_FILE"
else
  for issue in "${ISSUES[@]}"; do
    echo "- $issue" >> "$REPORT_FILE"
  done
fi

cat >> "$REPORT_FILE" << REPORT

## QA Result

$QA_STATUS

## Recommendation

$QA_SUMMARY

If this result is acceptable, the project can move to Owner review.
REPORT

python3 - "$HANDOVER_FILE" "$PROJECT_KEY" "$QA_TASK_KEY" "$REPORT_FILE" "$QA_STATUS" << 'PY'
from pathlib import Path
import sys

handover_file = Path(sys.argv[1])
project_key = sys.argv[2]
qa_task_key = sys.argv[3]
report_file = sys.argv[4]
qa_status = sys.argv[5]

marker = f"\n## QA Verification Completed for {qa_task_key}\n"
text = handover_file.read_text() if handover_file.exists() else ""

if marker in text:
    text = text.split(marker)[0].rstrip() + "\n"

block = f"""
## QA Verification Completed for {qa_task_key}

Project:

    {project_key}

QA report:

    {report_file}

Result:

    {qa_status}

Next step:

- If QA_PASSED, submit project output to Owner review.
- If QA_FAILED, assign revision task to engineer_agent.
"""

handover_file.write_text(text.rstrip() + "\n\n" + block.strip() + "\n")
PY

"$ROOT_DIR/runners/log_event.sh" \
  "$PROJECT_KEY" \
  "$QA_TASK_KEY" \
  "qa_agent" \
  "qa_verification_completed" \
  "$QA_STATUS" \
  "qa_room" \
  "QA verification completed" \
  "$QA_SUMMARY"

"$ROOT_DIR/runners/update_task_status.sh" \
  "$QA_TASK_KEY" \
  "$QA_STATUS" \
  "$QA_SUMMARY"

echo "QA verification completed:"
echo "- Project: $PROJECT_KEY"
echo "- QA task: $QA_TASK_KEY"
echo "- Result: $QA_STATUS"
echo "- Report: $REPORT_FILE"
