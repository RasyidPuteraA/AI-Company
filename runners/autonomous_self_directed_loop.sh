#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

AGENT="${1:-engineer_agent}"
MODE="${2:---dry-run}"
INTERVAL="${4:-}"
MAX_ITERATIONS="${6:-}"

if [ -f company/config/autonomous_discovery.env ]; then
  # shellcheck disable=SC1091
  source company/config/autonomous_discovery.env
fi

: "${AI_COMPANY_SELF_DIRECTED_CREATE_TASKS:=0}"
: "${AI_COMPANY_SELF_DIRECTED_AUTO_SOLVE:=0}"
: "${AI_COMPANY_SELF_DIRECTED_MAX_TASKS_PER_RUN:=1}"
: "${AI_COMPANY_SELF_DIRECTED_LOOP_INTERVAL:=600}"
: "${AI_COMPANY_SELF_DIRECTED_MAX_ITERATIONS:=3}"

if [ -z "$INTERVAL" ]; then
  INTERVAL="$AI_COMPANY_SELF_DIRECTED_LOOP_INTERVAL"
fi

if [ -z "$MAX_ITERATIONS" ]; then
  MAX_ITERATIONS="$AI_COMPANY_SELF_DIRECTED_MAX_ITERATIONS"
fi

LEDGER="company/runtime/autonomous-discovery/ledger.tsv"
mkdir -p "$(dirname "$LEDGER")"
touch "$LEDGER"

run_once() {
  echo "# Self-Directed Autonomous Discovery"
  echo "- Agent: $AGENT"
  echo "- Mode: $MODE"
  echo "- Create tasks: $AI_COMPANY_SELF_DIRECTED_CREATE_TASKS"
  echo "- Auto solve: $AI_COMPANY_SELF_DIRECTED_AUTO_SOLVE"
  echo "- Max tasks per run: $AI_COMPANY_SELF_DIRECTED_MAX_TASKS_PER_RUN"
  echo "- Time: $(date)"
  echo

  mapfile -t outputs < <(./runners/autonomous_issue_discovery.sh)
  report="${outputs[0]}"
  candidates="${outputs[1]}"

  echo "Discovery report: $report"
  echo "Candidates file: $candidates"
  echo

  if [ ! -s "$candidates" ]; then
    echo "No issue candidates found."
    return 0
  fi

  echo "Candidates:"
  awk -F '\t' '{print "- [" $2 "] " $5 " (" $1 ")"}' "$candidates"
  echo

  if [ "$MODE" = "--dry-run" ]; then
    echo "Dry-run only. No task created."
    return 0
  fi

  if [ "$AI_COMPANY_SELF_DIRECTED_CREATE_TASKS" != "1" ]; then
    echo "Task creation disabled. Set AI_COMPANY_SELF_DIRECTED_CREATE_TASKS=1."
    return 0
  fi

  created=0

  while IFS=$'\t' read -r signature priority assigned_agent phase title description; do
    [ -z "$signature" ] && continue

    if grep -Fq "$signature"$'\t' "$LEDGER"; then
      echo "Skip duplicate candidate: $signature"
      continue
    fi

    created=$((created + 1))
    if [ "$created" -gt "$AI_COMPANY_SELF_DIRECTED_MAX_TASKS_PER_RUN" ]; then
      break
    fi

    task_key="AUTO-$(date +%Y%m%d%H%M%S)-$(printf '%02d' "$created")"

    echo "Creating autonomous task:"
    echo "- key: $task_key"
    echo "- title: $title"
    echo "- priority: $priority"
    echo "- agent: $assigned_agent"
    echo "- phase: $phase"

    ./runners/create_internal_task.sh \
      "$task_key" \
      "$title" \
      "$description" \
      "$priority" \
      "$assigned_agent" \
      "$phase" \
      "guarded-autonomous" || true

    note_file="company/runtime/autodev/task_notes/${task_key}.md"
    mkdir -p "$(dirname "$note_file")"

    {
      echo "# Autonomous Task Note: $task_key"
      echo
      echo "- signature: $signature"
      echo "- title: $title"
      echo "- priority: $priority"
      echo "- assigned_agent: $assigned_agent"
      echo "- phase: $phase"
      echo "- source_report: $report"
      echo
      echo "## Description"
      echo
      echo "$description"
      echo
      echo "## Discovery Evidence"
      echo
      echo "See report: $report"
    } > "$note_file"

    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$signature" "$task_key" "$(date -Iseconds)" "$assigned_agent" "$title" >> "$LEDGER"

    ./runners/log_event.sh \
      internal-ai-company-os \
      "$task_key" \
      "$AGENT" \
      autonomous_issue_task_created \
      READY \
      autonomous_discovery \
      "$title" \
      "Created from autonomous discovery signature: $signature" || true

    if [ "$AI_COMPANY_SELF_DIRECTED_AUTO_SOLVE" = "1" ]; then
      if [ ! -x ./runners/autonomous_code_dev.sh ]; then
        echo "Auto-solve requested, but runners/autonomous_code_dev.sh is missing."
        exit 1
      fi

      echo "Auto-solving task via autonomous_code_dev.sh:"
      AI_COMPANY_ENABLE_AUTO_EDIT="${AI_COMPANY_ENABLE_AUTO_EDIT:-1}" \
      AI_COMPANY_ENABLE_AUTO_COMMIT="${AI_COMPANY_ENABLE_AUTO_COMMIT:-1}" \
      ./runners/autonomous_code_dev.sh "$assigned_agent" "$task_key" --run
    fi

  done < "$candidates"
}

case "$MODE" in
  --dry-run|--once)
    run_once
    ;;
  --loop)
    i=0
    while true; do
      i=$((i + 1))
      echo
      echo "## Self-directed loop iteration $i / $MAX_ITERATIONS"
      run_once
      if [ "$i" -ge "$MAX_ITERATIONS" ]; then
        break
      fi
      sleep "$INTERVAL"
    done
    ;;
  *)
    echo "Usage: $0 [agent_key] [--dry-run|--once|--loop] [--interval N] [--max-iterations N]"
    exit 2
    ;;
esac
