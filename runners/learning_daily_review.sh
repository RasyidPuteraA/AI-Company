#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/ai_company_scheduler.env"
REPORT_DIR="company/reports/learning"
TASK_PROPOSAL_FILE="$REPORT_DIR/proposed-internal-tasks.md"

mkdir -p "$REPORT_DIR"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

: "${AI_COMPANY_LEARNING_ENABLED:=1}"
: "${AI_COMPANY_LEARNING_AUTO_APPLY:=0}"
: "${AI_COMPANY_LEARNING_CREATE_TASKS:=1}"

timestamp="$(date -Iseconds)"
report_path="$REPORT_DIR/$(date +%F)-daily-learning-review.md"

if [ "$AI_COMPANY_LEARNING_ENABLED" != "1" ]; then
  {
    echo "# Daily Learning Review"
    echo
    echo "- generated_at: $timestamp"
    echo "- status: disabled"
  } > "$report_path"
  echo "Learning disabled by config."
  echo "report=$report_path"
  exit 0
fi

run_step() {
  local label="$1"
  shift
  echo "## $label"
  echo
  set +e
  "$@" 2>&1
  local status=$?
  set -e
  echo
  echo "- exit_status: $status"
  echo
  return 0
}

{
  echo "# Daily Learning Review"
  echo
  echo "- generated_at: $timestamp"
  echo "- auto_apply: $AI_COMPANY_LEARNING_AUTO_APPLY"
  echo "- create_tasks: $AI_COMPANY_LEARNING_CREATE_TASKS"
  echo "- safety: no model fine-tuning, no automatic code/policy application, no raw secret log dumps"
  echo
  run_step "Lesson Extraction" ./runners/learning_extract_lessons.sh
  run_step "Failure Pattern Detection" ./runners/learning_failure_patterns.sh
  run_step "Agent Scorecards" ./runners/learning_agent_scorecard.sh
  run_step "Learning Context Builder" ./runners/learning_context_builder.sh
} > "$report_path"

if [ "$AI_COMPANY_LEARNING_CREATE_TASKS" = "1" ]; then
  latest_pattern="$(find company/learning/patterns -maxdepth 1 -type f -name 'PATTERN-*.md' 2>/dev/null | sort | tail -1 || true)"
  {
    echo "# Proposed Internal Learning Tasks"
    echo
    echo "- generated_at: $timestamp"
    echo "- source_report: $report_path"
    echo "- auto_apply: $AI_COMPANY_LEARNING_AUTO_APPLY"
    echo
    if [ -n "$latest_pattern" ]; then
      echo "## Proposal"
      echo
      echo "- title: Reduce repeated pattern from $latest_pattern"
      echo "- status: proposed"
      echo "- risk_level: safe/proposal-only"
      echo "- action: Review pattern and create a scoped INTERNAL task only after approval."
      echo "- note: This runner does not modify code or policy automatically."
    else
      echo "No repeated pattern currently requires a proposed internal task."
    fi
  } > "$TASK_PROPOSAL_FILE"
fi

echo "report=$report_path"
if [ -f "$TASK_PROPOSAL_FILE" ]; then
  echo "task_proposals=$TASK_PROPOSAL_FILE"
fi
