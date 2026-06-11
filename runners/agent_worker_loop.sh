#!/usr/bin/env bash
set -euo pipefail

AGENT_KEY="${1:-}"
MODE="${2:---dry-run}"
INTERVAL=60
MAX_ITERATIONS=1

PROJECT_ROOT="/opt/ai-company"

# Safety defaults
TZ_NAME="${AI_COMPANY_TZ:-Asia/Jakarta}"
WORK_START_HOUR="${AI_COMPANY_WORK_START_HOUR:-08}"
WORK_END_HOUR="${AI_COMPANY_WORK_END_HOUR:-19}"
ALLOW_AFTER_HOURS="${AI_COMPANY_ALLOW_AFTER_HOURS:-0}"
EMERGENCY_STOP="${AI_COMPANY_AGENT_EMERGENCY_STOP:-0}"
MAX_ALLOWED_ITERATIONS="${AI_COMPANY_MAX_WORKER_ITERATIONS:-20}"
MIN_ALLOWED_INTERVAL="${AI_COMPANY_MIN_WORKER_INTERVAL:-3}"

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

is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

safety_check() {
  if [ "$EMERGENCY_STOP" = "1" ]; then
    echo "SAFETY BLOCK: AI_COMPANY_AGENT_EMERGENCY_STOP=1"
    exit 2
  fi

  if ! is_number "$INTERVAL"; then
    echo "SAFETY BLOCK: interval must be a number"
    exit 2
  fi

  if ! is_number "$MAX_ITERATIONS"; then
    echo "SAFETY BLOCK: max iterations must be a number"
    exit 2
  fi

  if [ "$MAX_ITERATIONS" -gt "$MAX_ALLOWED_ITERATIONS" ]; then
    echo "SAFETY BLOCK: max iterations $MAX_ITERATIONS exceeds limit $MAX_ALLOWED_ITERATIONS"
    exit 2
  fi

  if [ "$MODE" = "--loop" ] && [ "$INTERVAL" -lt "$MIN_ALLOWED_INTERVAL" ]; then
    echo "SAFETY BLOCK: interval $INTERVAL is below minimum $MIN_ALLOWED_INTERVAL seconds"
    exit 2
  fi

  # Dry-run is read-only, so it is allowed anytime.
  if [ "$MODE" = "--dry-run" ]; then
    return 0
  fi

  if [ "$ALLOW_AFTER_HOURS" = "1" ]; then
    echo "SAFETY OVERRIDE: after-hours execution allowed by AI_COMPANY_ALLOW_AFTER_HOURS=1"
    return 0
  fi

  local dow
  local hour
  dow="$(TZ="$TZ_NAME" date +%u)"
  hour="$(TZ="$TZ_NAME" date +%H)"

  if [ "$dow" -gt 5 ]; then
    echo "SAFETY BLOCK: outside workdays in $TZ_NAME. Set AI_COMPANY_ALLOW_AFTER_HOURS=1 to override manually."
    exit 2
  fi

  if [ "$hour" -lt "$WORK_START_HOUR" ] || [ "$hour" -ge "$WORK_END_HOUR" ]; then
    echo "SAFETY BLOCK: outside work hours ${WORK_START_HOUR}:00-${WORK_END_HOUR}:00 $TZ_NAME."
    echo "Current hour: $hour"
    echo "Set AI_COMPANY_ALLOW_AFTER_HOURS=1 to override manually."
    exit 2
  fi
}

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
  echo "- Time: $(TZ="$TZ_NAME" date)"
  echo

  safety_check

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
  echo "- Time: $(TZ="$TZ_NAME" date)"
  echo

  safety_check

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
