#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 AGENT_KEY TASK_KEY"
  exit 1
fi

AGENT_KEY="$1"
TASK_KEY="$2"

TASK_ROW="$(docker exec ai_company_postgres psql -U ai_company -d ai_company -At -F $'\t' -c "
SELECT
  task_key,
  title,
  status,
  current_phase,
  priority,
  coalesce(handover_note, '')
FROM tasks
WHERE task_key='${TASK_KEY}'
LIMIT 1;
")"

if [ -z "$TASK_ROW" ]; then
  echo "FAIL: task not found: $TASK_KEY"
  exit 1
fi

IFS=$'\t' read -r KEY TITLE STATUS PHASE PRIORITY NOTE <<< "$TASK_ROW"

cat <<BRIEF
You are ${AGENT_KEY} in AI Company OS.

Task:
- key: ${KEY}
- title: ${TITLE}
- status: ${STATUS}
- phase: ${PHASE}
- priority: ${PRIORITY}
- note: ${NOTE}

Operating rules:
- Do not expose secrets.
- Do not edit Codex auth files.
- Do not finalize client work without Owner approval.
- Prefer safe, minimal, auditable changes.
- If implementation is needed, propose exact files and commands.
- If this is an internal improvement, keep it bounded and reversible.
- End with a concise handover summary.

Repository context:
- repo: /opt/ai-company
- use pre-commit check before commits:
  ./runners/pre_commit_check.sh
BRIEF
