#!/usr/bin/env bash
set -euo pipefail

AGENT_KEY="${1:-}"
MODE="${2:---dry-run}"
INTERVAL=60
MAX_ITERATIONS=1

shift || true
shift || true

while [ "$#" -gt 0 ]; do
  case "$1" in
    --interval)
      INTERVAL="${2:-60}"
      shift 2
      ;;
    --max-iterations)
      MAX_ITERATIONS="${2:-1}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ -z "$AGENT_KEY" ]; then
  echo "Usage:"
  echo "  ./runners/agent_worker_loop.sh <agent_key> --dry-run"
  echo "  ./runners/agent_worker_loop.sh <agent_key> --once"
  echo "  ./runners/agent_worker_loop.sh <agent_key> --loop --interval 60 --max-iterations 5"
  exit 1
fi

case "$MODE" in
  --dry-run|--once|--loop)
    ;;
  *)
    echo "Invalid mode: $MODE"
    echo "Use --dry-run, --once, or --loop"
    exit 1
    ;;
esac

show_next_task() {
  docker exec ai_company_postgres \
    psql -U ai_company -d ai_company -P pager=off -c "
SELECT
  task_key,
  title,
  status,
  current_phase,
  priority,
  updated_at
FROM tasks
WHERE assigned_agent_key = '$AGENT_KEY'
  AND status IN ('TODO', 'INTERNAL_BACKLOG', 'NEEDS_REVISION', 'QA_FAILED')
ORDER BY priority DESC NULLS LAST, id ASC
LIMIT 1;
"
}

run_once() {
  echo "# Agent Worker Loop"
  echo "- Agent: $AGENT_KEY"
  echo "- Mode: $MODE"
  echo "- Time: $(date)"
  echo

  if [ "$MODE" = "--dry-run" ]; then
    echo "Dry run: next claimable task would be:"
    show_next_task
    return 0
  fi

  ./runners/claim_next_task.sh "$AGENT_KEY"
}

if [ "$MODE" = "--loop" ]; then
  echo "# Agent Worker Loop"
  echo "- Agent: $AGENT_KEY"
  echo "- Mode: --loop"
  echo "- Interval: $INTERVAL seconds"
  echo "- Max iterations: $MAX_ITERATIONS"
  echo

  i=1
  while [ "$i" -le "$MAX_ITERATIONS" ]; do
    echo "## Iteration $i / $MAX_ITERATIONS"
    ./runners/claim_next_task.sh "$AGENT_KEY" || true
    echo
    if [ "$i" -lt "$MAX_ITERATIONS" ]; then
      sleep "$INTERVAL"
    fi
    i=$((i + 1))
  done

  echo "Loop finished."
else
  run_once
fi
