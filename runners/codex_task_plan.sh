#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 AGENT_KEY TASK_KEY"
  exit 1
fi

AGENT_KEY="$1"
TASK_KEY="$2"

PROMPT="$(./runners/codex_task_brief.sh "$AGENT_KEY" "$TASK_KEY")

Create a short implementation plan for this task.
Do not modify files.
Return:
1. understanding
2. proposed files
3. safety checks
4. next command recommendation"

./runners/codex_agent_run.sh "$AGENT_KEY" "$TASK_KEY" plan "$PROMPT"
