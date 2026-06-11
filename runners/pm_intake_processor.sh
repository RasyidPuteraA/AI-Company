#!/usr/bin/env bash
set -euo pipefail

PROJECT_KEY="${1:-}"
TASK_KEY="${2:-}"

if [[ -z "$PROJECT_KEY" || -z "$TASK_KEY" ]]; then
  echo "Usage:"
  echo "  ./runners/pm_intake_processor.sh <project_key> <task_key>"
  echo
  echo "Example:"
  echo "  ./runners/pm_intake_processor.sh client-company-profile-demo CLIENT-1-001"
  exit 1
fi

if ! [[ "$PROJECT_KEY" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: project_key must use lowercase letters, numbers, and dashes only."
  exit 1
fi

if ! [[ "$TASK_KEY" =~ ^[A-Z0-9-]+$ ]]; then
  echo "ERROR: task_key must use uppercase letters, numbers, and dashes only."
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/projects/clients/$PROJECT_KEY"
TASK_FILE="$PROJECT_DIR/$TASK_KEY.md"
HANDOVER_FILE="$PROJECT_DIR/AGENT_HANDOVER.md"
OUTPUT_FILE="$PROJECT_DIR/PM_INTAKE_ANALYSIS-$TASK_KEY.md"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: project directory not found: $PROJECT_DIR"
  exit 1
fi

if [[ ! -f "$TASK_FILE" ]]; then
  echo "ERROR: task file not found: $TASK_FILE"
  exit 1
fi

psql_rows() {
  docker exec -i ai_company_postgres psql \
    -U ai_company \
    -d ai_company \
    -t \
    -A \
    -F "|" \
    -v ON_ERROR_STOP=1 \
    -c "$1"
}

TASK_ROW="$(psql_rows "
SELECT
  t.task_key,
  t.title,
  t.status,
  COALESCE(t.assigned_agent_key, ''),
  COALESCE(t.current_phase, ''),
  COALESCE(p.project_key, '')
FROM tasks t
JOIN projects p ON p.id = t.project_id
WHERE t.task_key = '$TASK_KEY'
LIMIT 1;
")"

if [[ -z "$TASK_ROW" ]]; then
  echo "ERROR: task not found in database: $TASK_KEY"
  exit 1
fi

UPLOAD_ROWS="$(psql_rows "
SELECT
  id,
  original_filename,
  relative_path,
  COALESCE(mime_type, ''),
  COALESCE(size_bytes, 0),
  created_at
FROM project_uploads
WHERE project_key = '$PROJECT_KEY'
ORDER BY id ASC;
")"

TASK_TITLE="$(echo "$TASK_ROW" | cut -d '|' -f 2)"
TASK_STATUS="$(echo "$TASK_ROW" | cut -d '|' -f 3)"
TASK_AGENT="$(echo "$TASK_ROW" | cut -d '|' -f 4)"
TASK_PHASE="$(echo "$TASK_ROW" | cut -d '|' -f 5)"

cat > "$OUTPUT_FILE" << REPORT
# PM Intake Analysis: $TASK_KEY

## Project

$PROJECT_KEY

## Source Task

- Task key: $TASK_KEY
- Title: $TASK_TITLE
- Status: $TASK_STATUS
- Assigned agent: $TASK_AGENT
- Phase: $TASK_PHASE

## Intake Source

The PM intake processor read:

- $TASK_FILE
- project upload metadata from project_uploads
- project handover file if present

## Requirement Summary

This project was created from an Owner Command Inbox requirement.

Current known requirement source:

REPORT

python3 - "$TASK_FILE" "$OUTPUT_FILE" << 'PY2'
from pathlib import Path
import sys

task_file = Path(sys.argv[1])
output_file = Path(sys.argv[2])

text = task_file.read_text()
lines = text.splitlines()

capture = False
collected = []
for line in lines:
    if line.strip() == "## Requirement":
        capture = True
        continue
    if capture and line.startswith("## "):
        break
    if capture:
        collected.append(line)

requirement = "\n".join(collected).strip()
if not requirement:
    requirement = "Requirement text not found in the task file. PM should ask Owner for clarification."

with output_file.open("a") as f:
    f.write("\n")
    for line in requirement.splitlines():
        f.write(f"> {line}\n")
    f.write("\n")
PY2

cat >> "$OUTPUT_FILE" << REPORT

## Uploaded Files

REPORT

if [[ -z "$UPLOAD_ROWS" ]]; then
  cat >> "$OUTPUT_FILE" << REPORT
No uploaded files are currently linked to this project.

REPORT
else
  while IFS="|" read -r id original_filename relative_path mime_type size_bytes created_at; do
    [[ -z "${id:-}" ]] && continue
    cat >> "$OUTPUT_FILE" << REPORT
- Upload #$id
  - File: $original_filename
  - Path: $relative_path
  - MIME: ${mime_type:-unknown}
  - Size: $size_bytes bytes
  - Uploaded at: $created_at

REPORT
  done <<< "$UPLOAD_ROWS"
fi

cat >> "$OUTPUT_FILE" << REPORT

## Initial PM Assessment

### What is clear

- The owner/client wants this requirement to become an executable client project.
- The project has a PM intake task.
- Uploaded files, if any, are now listed as project context.
- The next step is to convert this requirement into implementation tasks.

### What still needs clarification

- Final design direction and references.
- Exact pages or deliverables.
- Content/copywriting availability.
- Brand assets and logo status.
- Deployment target and deadline.
- Approval criteria from Owner/client.

## Suggested Implementation Plan

1. Confirm requirement scope with Owner.
2. Review all uploaded files and extract relevant context.
3. Create an implementation task for engineer_agent.
4. Create a QA verification task for qa_agent.
5. Produce a preview/staging result.
6. Submit result to Owner for acceptance or revision.

## Suggested Task Breakdown

### Suggested Engineer Task

- Task type: implementation
- Suggested agent: engineer_agent
- Goal: build the requested deliverable based on PM intake analysis and uploaded files.
- Required output:
  - changed files
  - build/test result
  - implementation summary
  - handover notes

### Suggested QA Task

- Task type: quality assurance
- Suggested agent: qa_agent
- Goal: verify implementation against requirement, uploaded assets, and Owner acceptance criteria.
- Required output:
  - QA result
  - defects if any
  - acceptance recommendation

## PM Recommendation

Proceed after Owner confirms the scope or accepts the initial interpretation.

If Owner wants automation to continue without clarification, PM can generate Engineer and QA tasks from this analysis.
REPORT

python3 - "$HANDOVER_FILE" "$OUTPUT_FILE" "$TASK_KEY" << 'PY3'
from pathlib import Path
import sys

handover_file = Path(sys.argv[1])
output_file = sys.argv[2]
task_key = sys.argv[3]

marker = f"\n## PM Intake Analysis Generated for {task_key}\n"
text = handover_file.read_text() if handover_file.exists() else ""

if marker in text:
    text = text.split(marker)[0].rstrip() + "\n"

block = f"""
## PM Intake Analysis Generated for {task_key}

Generated file:

    {output_file}

Summary:

- PM intake processor created requirement analysis.
- Suggested engineer and QA task breakdown is available.
- Owner may approve continuing into implementation task generation.
"""

handover_file.write_text(text.rstrip() + "\n\n" + block.strip() + "\n")
PY3

"$ROOT_DIR/runners/log_event.sh" \
  "$PROJECT_KEY" \
  "$TASK_KEY" \
  "pm_agent" \
  "pm_intake_analysis_generated" \
  "READY" \
  "planning_room" \
  "PM intake analysis generated" \
  "PM intake processor generated analysis and suggested task breakdown for $TASK_KEY."

echo "PM intake analysis generated:"
echo "- Project: $PROJECT_KEY"
echo "- Task: $TASK_KEY"
echo "- Output: $OUTPUT_FILE"
