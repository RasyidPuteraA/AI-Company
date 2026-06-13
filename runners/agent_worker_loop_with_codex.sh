#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 AGENT_KEY [--loop --interval N --max-iterations N]"
  exit 1
fi

AGENT_KEY="$1"
shift || true

MODE="${1:---once}"
INTERVAL=5
MAX_ITERATIONS=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --once)
      MODE="--once"
      shift
      ;;
    --loop)
      MODE="--loop"
      shift
      ;;
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --max-iterations)
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

echo "# Codex-enabled Agent Worker Loop"
echo "- Agent: $AGENT_KEY"
echo "- Mode: $MODE"
echo "- Codex dispatcher: ${AI_COMPANY_ENABLE_CODEX_DISPATCHER:-0}"
echo "- Time: $(date)"
echo

if [ "$MODE" = "--once" ]; then
  ./runners/agent_worker_once_with_codex.sh "$AGENT_KEY"
  exit 0
fi

i=1
while [ "$i" -le "$MAX_ITERATIONS" ]; do
  echo
  echo "## Iteration $i / $MAX_ITERATIONS"
  ./runners/agent_worker_once_with_codex.sh "$AGENT_KEY" || true

  if [ "$i" -lt "$MAX_ITERATIONS" ]; then
    sleep "$INTERVAL"
  fi

  i="$((i + 1))"
done
