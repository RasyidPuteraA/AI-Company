#!/usr/bin/env bash
set -euo pipefail

REVIEW_TASK_KEY="${1:-}"
DECISION="${2:-}"
NOTE="${3:-}"

if [[ -z "$REVIEW_TASK_KEY" || -z "$DECISION" ]]; then
  echo "Usage:"
  echo "  ./runners/owner_review_decision.sh <review_task_key> <ACCEPT|REVISE|REJECT> [note]"
  exit 1
fi

if ! [[ "$REVIEW_TASK_KEY" =~ ^[A-Z0-9-]+$ ]]; then
  echo "ERROR: review_task_key must use uppercase letters, numbers, and dashes only."
  exit 1
fi

DECISION="$(echo "$DECISION" | tr '[:lower:]' '[:upper:]')"

if [[ "$DECISION" != "ACCEPT" && "$DECISION" != "REVISE" && "$DECISION" != "REJECT" ]]; then
  echo "ERROR: decision must be ACCEPT, REVISE, or REJECT."
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

psql_exec() {
  docker exec -i ai_company_postgres psql \
    -U ai_company \
    -d ai_company \
    -v ON_ERROR_STOP=1 \
    -c "$1"
}

sql_literal() {
  local value="$1"
  local b64
  b64="$(printf "%s" "$value" | base64 -w0)"
  printf "convert_from(decode('%s', 'base64'), 'UTF8')" "$b64"
}

REVIEW_ROW="$(docker exec -i ai_company_postgres psql \
  -U ai_company \
  -d ai_company \
  -t \
  -A \
  -F "|" \
  -v ON_ERROR_STOP=1 \
  -c "SELECT t.task_key, t.status, p.project_key FROM tasks t JOIN projects p ON p.id = t.project_id WHERE t.task_key = '${REVIEW_TASK_KEY}' LIMIT 1;")"

if [[ -z "$REVIEW_ROW" ]]; then
  echo "ERROR: review task not found: $REVIEW_TASK_KEY"
  exit 1
fi

IFS="|" read -r TASK_KEY CURRENT_STATUS PROJECT_KEY <<< "$REVIEW_ROW"

if [[ "$CURRENT_STATUS" != "WAITING_OWNER_ACCEPTANCE" ]]; then
  echo "ERROR: review task must be WAITING_OWNER_ACCEPTANCE."
  echo "- Task: $REVIEW_TASK_KEY"
  echo "- Current status: $CURRENT_STATUS"
  exit 1
fi

PROJECT_DIR="$ROOT_DIR/projects/clients/$PROJECT_KEY"
HANDOVER_FILE="$PROJECT_DIR/AGENT_HANDOVER.md"
DECISION_FILE="$PROJECT_DIR/OWNER_DECISION-$REVIEW_TASK_KEY.md"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: project directory not found: $PROJECT_DIR"
  exit 1
fi

case "$DECISION" in
  ACCEPT)
    TASK_STATUS="ACCEPTED"
    PROJECT_STATUS="ACCEPTED"
    EVENT_TYPE="owner_accepted_project"
    ;;
  REVISE)
    TASK_STATUS="NEEDS_REVISION"
    PROJECT_STATUS="REVISION_REQUESTED"
    EVENT_TYPE="owner_requested_revision"
    ;;
  REJECT)
    TASK_STATUS="REJECTED"
    PROJECT_STATUS="REJECTED"
    EVENT_TYPE="owner_rejected_project"
    ;;
esac

psql_exec "
UPDATE tasks
SET status = '${TASK_STATUS}', updated_at = now()
WHERE task_key = '${REVIEW_TASK_KEY}';
"

psql_exec "
UPDATE projects
SET status = '${PROJECT_STATUS}', updated_at = now()
WHERE project_key = '${PROJECT_KEY}';
"

cat > "$DECISION_FILE" << DECISION_DOC
# Owner Decision: $REVIEW_TASK_KEY

## Project

$PROJECT_KEY

## Review Task

$REVIEW_TASK_KEY

## Decision

$DECISION

## Resulting Task Status

$TASK_STATUS

## Resulting Project Status

$PROJECT_STATUS

## Owner Note

${NOTE:-No note provided.}

## Next Step

DECISION_DOC

case "$DECISION" in
  ACCEPT)
    cat >> "$DECISION_FILE" << 'DECISION_DOC'
Project accepted by Owner.

Recommended next steps:

- Mark project as completed if no deployment is required.
- Archive or package deliverables.
- Prepare final handover.
DECISION_DOC
    ;;
  REVISE)
    cat >> "$DECISION_FILE" << 'DECISION_DOC'
Revision requested by Owner.

Recommended next steps:

- Create a revision task for engineer_agent.
- QA the revision after implementation.
- Submit again to Owner review.
DECISION_DOC
    ;;
  REJECT)
    cat >> "$DECISION_FILE" << 'DECISION_DOC'
Project rejected by Owner.

Recommended next steps:

- Stop current delivery path.
- Review rejection reason.
- Decide whether to restart intake or close project.
DECISION_DOC
    ;;
esac

python3 - "$HANDOVER_FILE" "$PROJECT_KEY" "$REVIEW_TASK_KEY" "$DECISION" "$TASK_STATUS" "$PROJECT_STATUS" "$DECISION_FILE" "$NOTE" << 'PY2'
from pathlib import Path
import sys

handover_file = Path(sys.argv[1])
project_key = sys.argv[2]
review_task_key = sys.argv[3]
decision = sys.argv[4]
task_status = sys.argv[5]
project_status = sys.argv[6]
decision_file = sys.argv[7]
note = sys.argv[8]

marker = f"\n## Owner Decision for {review_task_key}\n"
text = handover_file.read_text() if handover_file.exists() else ""

if marker in text:
    text = text.split(marker)[0].rstrip() + "\n"

block = f"""
## Owner Decision for {review_task_key}

Project:

    {project_key}

Decision:

    {decision}

Task status:

    {task_status}

Project status:

    {project_status}

Decision file:

    {decision_file}

Owner note:

    {note or 'No note provided.'}
"""

handover_file.write_text(text.rstrip() + "\n\n" + block.strip() + "\n")
PY2

"$ROOT_DIR/runners/log_event.sh" \
  "$PROJECT_KEY" \
  "$REVIEW_TASK_KEY" \
  "owner" \
  "$EVENT_TYPE" \
  "$TASK_STATUS" \
  "owner_inbox" \
  "Owner review decision recorded" \
  "Owner decision ${DECISION} recorded for ${REVIEW_TASK_KEY}. ${NOTE}"

echo "Owner decision recorded:"
echo "- Project: $PROJECT_KEY"
echo "- Review task: $REVIEW_TASK_KEY"
echo "- Decision: $DECISION"
echo "- Task status: $TASK_STATUS"
echo "- Project status: $PROJECT_STATUS"
echo "- Decision file: $DECISION_FILE"
