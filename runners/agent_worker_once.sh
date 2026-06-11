#!/usr/bin/env bash
set -euo pipefail

AGENT_KEY="${1:-}"

if [ -z "$AGENT_KEY" ]; then
  echo "Usage:"
  echo "  ./runners/agent_worker_once.sh <agent_key>"
  exit 1
fi

echo "# Agent Worker Once"
echo "- Agent: $AGENT_KEY"
echo "- Time: $(date)"
echo

./runners/claim_next_task.sh "$AGENT_KEY"

echo
echo "Current queue:"
./runners/agent_queue.sh "$AGENT_KEY"
