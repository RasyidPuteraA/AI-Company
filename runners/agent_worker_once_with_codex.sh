#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 AGENT_KEY"
  exit 1
fi

AGENT_KEY="$1"
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

AI_COMPANY_ALLOW_AFTER_HOURS="${AI_COMPANY_ALLOW_AFTER_HOURS:-0}" \
./runners/agent_worker_loop.sh "$AGENT_KEY" --once 2>&1 | tee "$TMP_OUT"

TASK_KEY="$(awk -F': ' '/^- Task:/ {print $2; exit}' "$TMP_OUT" | tr -d '[:space:]')"

if [ -z "$TASK_KEY" ]; then
  echo "No claimed task detected for Codex dispatcher hook."
  exit 0
fi

echo
echo "# Codex post-claim hook"
echo "- Agent: $AGENT_KEY"
echo "- Task: $TASK_KEY"

if [ "${AI_COMPANY_ENABLE_CODEX_DISPATCHER:-0}" != "1" ]; then
  echo "Codex dispatcher disabled. Set AI_COMPANY_ENABLE_CODEX_DISPATCHER=1 to enable plan generation."
  exit 0
fi

./runners/autonomous_codex_dispatcher_hook.sh "$AGENT_KEY" "$TASK_KEY" --plan
