#!/usr/bin/env bash
set -euo pipefail

PROJECT_KEY="${1:-}"
SOURCE_TASK_KEY="${2:-}"

if [[ -z "$PROJECT_KEY" || -z "$SOURCE_TASK_KEY" ]]; then
  echo "Usage:"
  echo "  ./runners/generate_tasks_from_pm_analysis.sh <project_key> <source_pm_task_key>"
  echo
  echo "Example:"
  echo "  ./runners/generate_tasks_from_pm_analysis.sh client-company-profile-demo CLIENT-1-001"
  exit 1
fi

if ! [[ "$PROJECT_KEY" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: project_key must use lowercase letters, numbers, and dashes only."
  exit 1
fi

if ! [[ "$SOURCE_TASK_KEY" =~ ^[A-Z0-9-]+$ ]]; then
  echo "ERROR: source task key must use uppercase letters, numbers, and dashes only."
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/projects/clients/$PROJECT_KEY"
ANALYSIS_FILE="$PROJECT_DIR/PM_INTAKE_ANALYSIS-$SOURCE_TASK_KEY.md"
HANDOVER_FILE="$PROJECT_DIR/AGENT_HANDOVER.md"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: project directory not found: $PROJECT_DIR"
  exit 1
fi

if [[ ! -f "$ANALYSIS_FILE" ]]; then
  echo "ERROR: PM analysis file not found: $ANALYSIS_FILE"
  exit 1
fi

psql_scalar() {
  docker exec -i ai_company_postgres psql \
    -U ai_company \
    -d ai_company \
    -t \
    -A \
    -v ON_ERROR_STOP=1 \
    -c "$1"
}

SOURCE_ID="$(echo "$SOURCE_TASK_KEY" | sed -E 's/^CLIENT-([0-9]+)-.*/\1/')"
ENGINEER_TASK_KEY="CLIENT-${SOURCE_ID}-ENG-001"
QA_TASK_KEY="CLIENT-${SOURCE_ID}-QA-001"

ENGINEER_TITLE="Implement client project from PM analysis"
QA_TITLE="QA client project implementation"

ENGINEER_DESCRIPTION="Implement the client project based on PM intake analysis.

Project: ${PROJECT_KEY}
Source PM task: ${SOURCE_TASK_KEY}
PM analysis file: ${ANALYSIS_FILE}

Required:
- Read PM intake analysis
- Review uploaded files listed in the analysis
- Build the requested deliverable
- Keep work inside projects/clients/${PROJECT_KEY}
- Update AGENT_HANDOVER.md
- Provide test/build result"

QA_DESCRIPTION="Verify the client project implementation based on PM intake analysis.

Project: ${PROJECT_KEY}
Source PM task: ${SOURCE_TASK_KEY}
PM analysis file: ${ANALYSIS_FILE}

Required:
- Read PM intake analysis
- Verify implementation against requirement
- Check uploaded files/context were considered
- Report defects or acceptance recommendation
- Update AGENT_HANDOVER.md"

echo "# Generate Engineer and QA Tasks from PM Analysis"
echo "- Project: $PROJECT_KEY"
echo "- Source PM task: $SOURCE_TASK_KEY"
echo "- PM analysis: $ANALYSIS_FILE"
echo "- Engineer task: $ENGINEER_TASK_KEY"
echo "- QA task: $QA_TASK_KEY"

EXISTING_ENGINEER="$(psql_scalar "SELECT task_key FROM tasks WHERE task_key = '${ENGINEER_TASK_KEY}' LIMIT 1;")"
EXISTING_QA="$(psql_scalar "SELECT task_key FROM tasks WHERE task_key = '${QA_TASK_KEY}' LIMIT 1;")"

if [[ -z "$EXISTING_ENGINEER" ]]; then
  "$ROOT_DIR/runners/create_task.sh" \
    "$PROJECT_KEY" \
    "$ENGINEER_TASK_KEY" \
    "$ENGINEER_TITLE" \
    "$ENGINEER_DESCRIPTION" \
    HIGH \
    engineer_agent \
    implementation
else
  echo "Engineer task already exists: $ENGINEER_TASK_KEY"
fi

if [[ -z "$EXISTING_QA" ]]; then
  "$ROOT_DIR/runners/create_task.sh" \
    "$PROJECT_KEY" \
    "$QA_TASK_KEY" \
    "$QA_TITLE" \
    "$QA_DESCRIPTION" \
    MEDIUM \
    qa_agent \
    qa
else
  echo "QA task already exists: $QA_TASK_KEY"
fi

python3 - "$HANDOVER_FILE" "$PROJECT_KEY" "$SOURCE_TASK_KEY" "$ENGINEER_TASK_KEY" "$QA_TASK_KEY" << 'PY'
from pathlib import Path
import sys

handover_file = Path(sys.argv[1])
project_key = sys.argv[2]
source_task_key = sys.argv[3]
engineer_task_key = sys.argv[4]
qa_task_key = sys.argv[5]

marker = f"\n## Generated Engineer and QA Tasks from {source_task_key}\n"
text = handover_file.read_text() if handover_file.exists() else ""

if marker in text:
    text = text.split(marker)[0].rstrip() + "\n"

block = f"""
## Generated Engineer and QA Tasks from {source_task_key}

Project:

    {project_key}

Generated tasks:

- {engineer_task_key}
  - Agent: engineer_agent
  - Phase: implementation
- {qa_task_key}
  - Agent: qa_agent
  - Phase: qa

Source:

    {source_task_key}

Next step:

- Engineer agent can claim the implementation task.
- QA agent should verify after implementation output is ready.
"""

handover_file.write_text(text.rstrip() + "\n\n" + block.strip() + "\n")
PY

"$ROOT_DIR/runners/log_event.sh" \
  "$PROJECT_KEY" \
  "$SOURCE_TASK_KEY" \
  "pm_agent" \
  "pm_generated_engineer_qa_tasks" \
  "READY" \
  "planning_room" \
  "PM generated Engineer and QA tasks" \
  "Generated ${ENGINEER_TASK_KEY} and ${QA_TASK_KEY} from PM analysis."

echo
echo "Generated task summary:"
docker exec -i ai_company_postgres psql -U ai_company -d ai_company -P pager=off -c "SELECT task_key, title, status, assigned_agent_key, current_phase FROM tasks WHERE task_key IN ('${ENGINEER_TASK_KEY}', '${QA_TASK_KEY}') ORDER BY task_key;"
