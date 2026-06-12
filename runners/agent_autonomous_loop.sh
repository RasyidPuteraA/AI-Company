#!/usr/bin/env bash
set -euo pipefail

AGENT="${1:-}"
shift || true

INTERVAL=15
MAX_ITERATIONS=20

while [ $# -gt 0 ]; do
  case "$1" in
    --interval)
      INTERVAL="${2:-15}"
      shift 2
      ;;
    --max-iterations)
      MAX_ITERATIONS="${2:-20}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1"
      exit 2
      ;;
  esac
done

if [ -z "$AGENT" ]; then
  echo "Usage: $0 AGENT_KEY [--interval N] [--max-iterations N]"
  exit 1
fi

if [ "$MAX_ITERATIONS" -gt 20 ]; then
  echo "SAFETY BLOCK: max iterations $MAX_ITERATIONS exceeds limit 20"
  exit 2
fi

echo "# Autonomous Agent Loop"
echo "- Agent: $AGENT"
echo "- Interval: $INTERVAL"
echo "- Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  if [ "${AI_COMPANY_AGENT_EMERGENCY_STOP:-0}" = "1" ]; then
    echo "EMERGENCY STOP active. Autonomous loop halted."
    exit 0
  fi

  echo "## Autonomous iteration $i / $MAX_ITERATIONS"

  AI_COMPANY_ALLOW_AFTER_HOURS="${AI_COMPANY_ALLOW_AFTER_HOURS:-0}" \
    ./runners/agent_worker_loop.sh "$AGENT" --once || true

  ./runners/autonomous_agent_dispatcher.sh "$AGENT" || true

  sleep "$INTERVAL"
done
