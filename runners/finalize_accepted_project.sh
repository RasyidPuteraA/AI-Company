#!/usr/bin/env bash
set -euo pipefail

PROJECT_KEY="${1:-}"
REVIEW_TASK_KEY="${2:-}"

if [[ -z "$PROJECT_KEY" || -z "$REVIEW_TASK_KEY" ]]; then
  echo "Usage:"
  echo "  ./runners/finalize_accepted_project.sh <project_key> <review_task_key>"
  echo
  echo "Example:"
  echo "  ./runners/finalize_accepted_project.sh client-company-profile-demo CLIENT-1-REVIEW-001"
  exit 1
fi

if ! [[ "$PROJECT_KEY" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: project_key must use lowercase letters, numbers, and dashes only."
  exit 1
fi

if ! [[ "$REVIEW_TASK_KEY" =~ ^[A-Z0-9-]+$ ]]; then
  echo "ERROR: review_task_key must use uppercase letters, numbers, and dashes only."
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/projects/clients/$PROJECT_KEY"
HANDOVER_FILE="$PROJECT_DIR/AGENT_HANDOVER.md"
FINAL_HANDOVER_FILE="$PROJECT_DIR/FINAL_HANDOVER.md"
SITE_DIR="$PROJECT_DIR/site"
OWNER_DECISION_FILE="$PROJECT_DIR/OWNER_DECISION-$REVIEW_TASK_KEY.md"

SOURCE_ID="$(echo "$REVIEW_TASK_KEY" | sed -E 's/^CLIENT-([0-9]+)-.*/\1/')"
PM_TASK_KEY="CLIENT-${SOURCE_ID}-001"
ENG_TASK_KEY="CLIENT-${SOURCE_ID}-ENG-001"
QA_TASK_KEY="CLIENT-${SOURCE_ID}-QA-001"
QA_REPORT_FILE="$PROJECT_DIR/QA_REPORT-$QA_TASK_KEY.md"
PM_ANALYSIS_FILE="$PROJECT_DIR/PM_INTAKE_ANALYSIS-$PM_TASK_KEY.md"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: project directory not found: $PROJECT_DIR"
  exit 1
fi

if [[ ! -d "$SITE_DIR" ]]; then
  echo "ERROR: implementation output folder not found: $SITE_DIR"
  exit 1
fi

if [[ ! -f "$OWNER_DECISION_FILE" ]]; then
  echo "ERROR: owner decision file not found: $OWNER_DECISION_FILE"
  exit 1
fi

if [[ ! -f "$QA_REPORT_FILE" ]]; then
  echo "ERROR: QA report file not found: $QA_REPORT_FILE"
  exit 1
fi

PROJECT_STATUS="$(docker exec -i ai_company_postgres psql -U ai_company -d ai_company -t -A -v ON_ERROR_STOP=1 -c "SELECT status FROM projects WHERE project_key='${PROJECT_KEY}' LIMIT 1;" | tr -d '[:space:]')"
REVIEW_STATUS="$(docker exec -i ai_company_postgres psql -U ai_company -d ai_company -t -A -v ON_ERROR_STOP=1 -c "SELECT status FROM tasks WHERE task_key='${REVIEW_TASK_KEY}' LIMIT 1;" | tr -d '[:space:]')"

if [[ "$PROJECT_STATUS" != "ACCEPTED" && "$PROJECT_STATUS" != "COMPLETED" ]]; then
  echo "ERROR: project must be ACCEPTED before completion."
  echo "- Project: $PROJECT_KEY"
  echo "- Current status: ${PROJECT_STATUS:-not_found}"
  exit 1
fi

if [[ "$REVIEW_STATUS" != "ACCEPTED" ]]; then
  echo "ERROR: review task must be ACCEPTED before project completion."
  echo "- Review task: $REVIEW_TASK_KEY"
  echo "- Current status: ${REVIEW_STATUS:-not_found}"
  exit 1
fi

cat > "$FINAL_HANDOVER_FILE" << FINAL
# Final Handover: $PROJECT_KEY

## Final Status

COMPLETED

## Project

$PROJECT_KEY

## Source Tasks

- PM intake task: $PM_TASK_KEY
- Engineer task: $ENG_TASK_KEY
- QA task: $QA_TASK_KEY
- Owner review task: $REVIEW_TASK_KEY

## Key Files

- PM analysis: $PM_ANALYSIS_FILE
- Implementation output: $SITE_DIR
- QA report: $QA_REPORT_FILE
- Owner decision: $OWNER_DECISION_FILE

## Deliverables

- site/index.html
- site/styles.css
- site/app.js
- site/README.md

## Completion Summary

This project has completed the AI Company OS delivery workflow:

1. Owner requirement was converted into a client project.
2. PM analysis was generated.
3. Engineer implementation output was created.
4. QA verification passed.
5. Owner accepted the output.
6. Project was finalized as COMPLETED.

## Next Operational Step

The project can now be archived, packaged, deployed, or used as a reference demo for the AI Company OS workflow.
FINAL

docker exec -i ai_company_postgres psql \
  -U ai_company \
  -d ai_company \
  -v ON_ERROR_STOP=1 \
  -c "UPDATE projects SET status='COMPLETED', phase='completed', updated_at=now() WHERE project_key='${PROJECT_KEY}';"

python3 - "$HANDOVER_FILE" "$PROJECT_KEY" "$REVIEW_TASK_KEY" "$FINAL_HANDOVER_FILE" << 'PY'
from pathlib import Path
import sys

handover_file = Path(sys.argv[1])
project_key = sys.argv[2]
review_task_key = sys.argv[3]
final_handover_file = sys.argv[4]

marker = f"\n## Project Finalized: {project_key}\n"
text = handover_file.read_text() if handover_file.exists() else ""

if marker in text:
    text = text.split(marker)[0].rstrip() + "\n"

block = f"""
## Project Finalized: {project_key}

Review task:

    {review_task_key}

Final handover:

    {final_handover_file}

Final project status:

    COMPLETED

Final project phase:

    completed

Result:

- Owner accepted the project.
- Final handover was generated.
- Project was marked completed.
"""

handover_file.write_text(text.rstrip() + "\n\n" + block.strip() + "\n")
PY

"$ROOT_DIR/runners/log_event.sh" \
  "$PROJECT_KEY" \
  "$REVIEW_TASK_KEY" \
  "owner" \
  "project_completed" \
  "COMPLETED" \
  "final_handover" \
  "Project finalized as completed" \
  "Accepted project ${PROJECT_KEY} finalized with final handover."

echo "Project finalized:"
echo "- Project: $PROJECT_KEY"
echo "- Review task: $REVIEW_TASK_KEY"
echo "- Final handover: $FINAL_HANDOVER_FILE"
echo "- Status: COMPLETED"
