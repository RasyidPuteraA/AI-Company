#!/usr/bin/env bash
set -euo pipefail

PROJECT_KEY="${1:-}"
TASK_KEY="${2:-}"
TITLE="${3:-}"
DESCRIPTION="${4:-}"
PRIORITY="${5:-MEDIUM}"
ASSIGNED_AGENT_KEY="${6:-engineer_agent}"
CURRENT_PHASE="${7:-IMPLEMENTATION}"

ROOT_DIR="/opt/ai-company"
PROJECT_DIR="$ROOT_DIR/projects/sandbox/company-profile-demo"
TASK_FILE="$PROJECT_DIR/$TASK_KEY.md"

if [ -z "$PROJECT_KEY" ] || [ -z "$TASK_KEY" ] || [ -z "$TITLE" ] || [ -z "$DESCRIPTION" ]; then
  echo "Usage: ./runners/create_task.sh <project_key> <task_key> <title> <description> [priority] [assigned_agent_key] [current_phase]"
  exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Project directory not found: $PROJECT_DIR"
  exit 1
fi

docker exec -i ai_company_postgres psql -U ai_company -d ai_company \
  -v project_key="$PROJECT_KEY" \
  -v task_key="$TASK_KEY" \
  -v title="$TITLE" \
  -v description="$DESCRIPTION" \
  -v priority="$PRIORITY" \
  -v assigned_agent_key="$ASSIGNED_AGENT_KEY" \
  -v current_phase="$CURRENT_PHASE" <<'SQL'
INSERT INTO tasks (task_key, project_id, title, description, status, priority, assigned_agent_key, current_phase)
SELECT
  :'task_key',
  p.id,
  :'title',
  :'description',
  'TODO',
  :'priority',
  :'assigned_agent_key',
  :'current_phase'
FROM projects p
WHERE p.project_key = :'project_key'
ON CONFLICT (task_key) DO NOTHING;
SQL

cat > "$TASK_FILE" << TASK
# $TASK_KEY: $TITLE

Project:
Company Profile Demo for fictional EV workshop.

Goal:
$DESCRIPTION

Requirements:
- Implement the requested change in the existing static website.
- Keep the same dark navy and electric green industrial EV workshop style.
- Ensure responsive layout remains clean.
- Update README.md if needed.
- Update AGENT_HANDOVER.md with $TASK_KEY notes.

Rules:
- Work only inside this project folder.
- Do not modify files outside this folder.
- Do not deploy production.
- Do not access secrets.
- Do not use sudo.

Required output:
- Updated website source code
- Build/test result
- Updated AGENT_HANDOVER.md
TASK

./runners/log_event.sh \
  "$PROJECT_KEY" \
  "$TASK_KEY" \
  "pm_agent" \
  "task_created" \
  "TODO" \
  "planning_room" \
  "$TITLE" \
  "PM Agent created $TASK_KEY: $DESCRIPTION"

echo "Task created:"
echo "- DB task: $TASK_KEY"
echo "- Task file: $TASK_FILE"
