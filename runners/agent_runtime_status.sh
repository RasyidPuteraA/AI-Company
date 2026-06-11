#!/usr/bin/env bash
set -euo pipefail

AGENT_KEY="${1:-}"

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
  docker exec ai_company_postgres \
    psql -U ai_company -d ai_company -P pager=off -v agent_key="$AGENT_KEY" -c "
SELECT
  ars.agent_key,
  ars.runtime_status,
  COALESCE(ars.current_task_key, '') AS current_task_key,
  ars.location,
  ars.status_note,
  ars.updated_at
FROM agent_runtime_status ars
WHERE ars.agent_key = :'agent_key'
ORDER BY ars.updated_at DESC;
"
fi
