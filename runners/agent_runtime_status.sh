#!/usr/bin/env bash
set -euo pipefail

AGENT_KEY="${1:-}"

SQL_ESCAPE() {
  printf "%s" "$1" | sed "s/'/''/g"
}

echo "# Agent Runtime Status"
echo
echo "Generated at: $(date)"
echo

if [ -z "$AGENT_KEY" ]; then
  docker exec ai_company_postgres \
    psql -U ai_company -d ai_company -P pager=off -c "
SELECT
  ars.agent_key,
  ars.runtime_status,
  COALESCE(ars.current_task_key, '') AS current_task_key,
  ars.location,
  ars.status_note,
  ars.updated_at
FROM agent_runtime_status ars
ORDER BY ars.updated_at DESC, ars.agent_key ASC;
"
else
  AGENT_KEY_SQL="$(SQL_ESCAPE "$AGENT_KEY")"

  docker exec ai_company_postgres \
    psql -U ai_company -d ai_company -P pager=off -c "
SELECT
  ars.agent_key,
  ars.runtime_status,
  COALESCE(ars.current_task_key, '') AS current_task_key,
  ars.location,
  ars.status_note,
  ars.updated_at
FROM agent_runtime_status ars
WHERE ars.agent_key = '$AGENT_KEY_SQL'
ORDER BY ars.updated_at DESC;
"
fi
