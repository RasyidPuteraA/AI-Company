#!/usr/bin/env bash
set -euo pipefail

COMMAND_ID="${1:-}"
PROJECT_KEY="${2:-}"
PROJECT_TITLE="${3:-}"

if [[ -z "$COMMAND_ID" || -z "$PROJECT_KEY" || -z "$PROJECT_TITLE" ]]; then
  echo "Usage:"
  echo "  ./runners/convert_owner_command_to_project.sh <owner_command_id> <project_key> <project_title>"
  echo
  echo "Example:"
  echo "  ./runners/convert_owner_command_to_project.sh 1 client-company-profile-demo \"Client Company Profile Demo\""
  exit 1
fi

if ! [[ "$COMMAND_ID" =~ ^[0-9]+$ ]]; then
  echo "ERROR: owner_command_id must be numeric."
  exit 1
fi

if ! [[ "$PROJECT_KEY" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: project_key must use lowercase letters, numbers, and dashes only."
  echo "Example: client-company-profile-demo"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

psql_scalar() {
  docker exec -i ai_company_postgres psql \
    -U ai_company \
    -d ai_company \
    -t \
    -A \
    -v ON_ERROR_STOP=1 \
    -c "$1"
}

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

COMMAND_STATUS="$(psql_scalar "SELECT status FROM owner_commands WHERE id = ${COMMAND_ID} LIMIT 1;")"

if [[ -z "$COMMAND_STATUS" ]]; then
  echo "ERROR: owner command not found: ${COMMAND_ID}"
  exit 1
fi

if [[ "$COMMAND_STATUS" == "CONVERTED" ]]; then
  echo "Owner command ${COMMAND_ID} is already CONVERTED."
  psql_exec "SELECT id, status, project_key, task_key, converted_at FROM owner_commands WHERE id = ${COMMAND_ID};"
  exit 0
fi

COMMAND_B64="$(psql_scalar "SELECT encode(convert_to(command_text, 'UTF8'), 'base64') FROM owner_commands WHERE id = ${COMMAND_ID} LIMIT 1;")"
COMMAND_TEXT="$(printf "%s" "$COMMAND_B64" | base64 -d)"

TASK_KEY="CLIENT-${COMMAND_ID}-001"
TASK_TITLE="PM intake: ${PROJECT_TITLE}"
TASK_DESCRIPTION="Owner command #${COMMAND_ID}

Project: ${PROJECT_TITLE}
Project key: ${PROJECT_KEY}

Requirement:

${COMMAND_TEXT}

Goal:
PM agent should analyze this owner/client requirement and turn it into an implementation plan and task breakdown."

PROJECT_KEY_SQL="$(sql_literal "$PROJECT_KEY")"
PROJECT_TITLE_SQL="$(sql_literal "$PROJECT_TITLE")"
CLIENT_NAME_SQL="$(sql_literal "Owner Command Inbox")"
TASK_KEY_SQL="$(sql_literal "$TASK_KEY")"

echo "# Convert Owner Command to Client Project"
echo "- Owner command: ${COMMAND_ID}"
echo "- Project key: ${PROJECT_KEY}"
echo "- Project title: ${PROJECT_TITLE}"
echo "- Initial task: ${TASK_KEY}"

psql_exec "
INSERT INTO projects (project_key, name, client_name, status, phase)
VALUES (${PROJECT_KEY_SQL}, ${PROJECT_TITLE_SQL}, ${CLIENT_NAME_SQL}, 'ACTIVE', 'intake')
ON CONFLICT (project_key) DO NOTHING;
"

PROJECT_EXISTS="$(psql_scalar "SELECT project_key FROM projects WHERE project_key = '${PROJECT_KEY}' LIMIT 1;")"

if [[ -z "$PROJECT_EXISTS" ]]; then
  echo "ERROR: failed to create project row: ${PROJECT_KEY}"
  exit 1
fi

EXISTING_TASK="$(psql_scalar "SELECT task_key FROM tasks WHERE task_key = '${TASK_KEY}' LIMIT 1;")"

if [[ -z "$EXISTING_TASK" ]]; then
  ./runners/create_task.sh \
    "$PROJECT_KEY" \
    "$TASK_KEY" \
    "$TASK_TITLE" \
    "$TASK_DESCRIPTION" \
    HIGH \
    pm_agent \
    intake \
    safe
else
  echo "Task already exists: ${TASK_KEY}"
fi

TASK_EXISTS="$(psql_scalar "SELECT task_key FROM tasks WHERE task_key = '${TASK_KEY}' LIMIT 1;")"

if [[ -z "$TASK_EXISTS" ]]; then
  echo "ERROR: task was not created in database: ${TASK_KEY}"
  echo "Owner command remains NEW for retry."
  exit 1
fi

psql_exec "
UPDATE owner_commands
SET
  status = 'CONVERTED',
  project_key = ${PROJECT_KEY_SQL},
  task_key = ${TASK_KEY_SQL},
  converted_at = now(),
  updated_at = now()
WHERE id = ${COMMAND_ID};
"

./runners/log_event.sh \
  "$PROJECT_KEY" \
  "$TASK_KEY" \
  pm_agent \
  owner_command_converted \
  NEW \
  owner_dashboard \
  "Owner command converted to client project" \
  "Owner command ${COMMAND_ID} converted to project ${PROJECT_KEY} with initial task ${TASK_KEY}."

echo
echo "Converted owner command:"
psql_exec "SELECT id, status, project_key, task_key, converted_at FROM owner_commands WHERE id = ${COMMAND_ID};"

echo
echo "Initial client task:"
psql_exec "SELECT task_key, title, status, assigned_agent_key FROM tasks WHERE task_key = '${TASK_KEY}';"
