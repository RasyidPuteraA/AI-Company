#!/usr/bin/env bash
set -euo pipefail

TASK_KEY="${1:-}"
TITLE="${2:-}"
DESCRIPTION="${3:-}"
PRIORITY="${4:-MEDIUM}"
ASSIGNED_AGENT_KEY="${5:-engineer_agent}"
CATEGORY="${6:-internal_improvement}"
RISK_LEVEL="${7:-safe}"

ROOT_DIR="/opt/ai-company"
PROJECT_KEY="internal-ai-company-os"
PROJECT_DIR="$ROOT_DIR/projects/internal/ai-company-os"
TASK_FILE="$PROJECT_DIR/$TASK_KEY.md"

if [ -z "$TASK_KEY" ] || [ -z "$TITLE" ] || [ -z "$DESCRIPTION" ]; then
  echo "Usage: ./runners/create_internal_task.sh <task_key> <title> <description> [priority] [assigned_agent_key] [category] [risk_level]"
  exit 1
fi

mkdir -p "$PROJECT_DIR"

docker exec -i ai_company_postgres psql -U ai_company -d ai_company << SQL
INSERT INTO projects (project_key, name, client_name, status, phase)
VALUES (
  'internal-ai-company-os',
  'AI Company OS Internal Development',
  'Internal',
  'IN_PROGRESS',
  'INTERNAL_DEVELOPMENT'
)
ON CONFLICT (project_key) DO NOTHING;
SQL

docker exec -i ai_company_postgres psql -U ai_company -d ai_company \
  -v project_key="$PROJECT_KEY" \
  -v task_key="$TASK_KEY" \
  -v title="$TITLE" \
  -v description="$DESCRIPTION" \
  -v priority="$PRIORITY" \
  -v assigned_agent_key="$ASSIGNED_AGENT_KEY" \
  -v current_phase="INTERNAL_DEVELOPMENT" <<'SQL'
INSERT INTO tasks (task_key, project_id, title, description, status, priority, assigned_agent_key, current_phase)
SELECT
  :'task_key',
  p.id,
  :'title',
  :'description',
  'INTERNAL_BACKLOG',
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
AI Company OS Internal Development

Category:
$CATEGORY

Risk Level:
$RISK_LEVEL

Goal:
$DESCRIPTION

Requirements:
- Improve AI Company OS safely.
- Work only inside the allowed project/task scope.
- If the change requires infrastructure, SSH, firewall, Docker daemon, production, secrets, or destructive database changes, create a proposal instead of applying it.
- Update AGENT_HANDOVER.md with $TASK_KEY notes.
- If code/script is changed, describe test result clearly.

Rules:
- Do not access secrets.
- Do not use sudo.
- Do not deploy production.
- Do not modify SSH or firewall.
- Do not delete database, Docker volume, or project files.
- For dangerous infrastructure changes, write a proposal under company/proposals/internal instead of executing.

Required output:
- Implementation or proposal files
- Updated AGENT_HANDOVER.md
- Build/test/check result
TASK

./runners/log_event.sh \
  "$PROJECT_KEY" \
  "$TASK_KEY" \
  "pm_agent" \
  "internal_task_created" \
  "INTERNAL_BACKLOG" \
  "planning_room" \
  "$TITLE" \
  "PM Agent created internal task $TASK_KEY: $DESCRIPTION"

echo "Internal task created:"
echo "- DB task: $TASK_KEY"
echo "- Task file: $TASK_FILE"
