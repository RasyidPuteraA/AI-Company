#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

STAMP="$(date +%Y%m%d%H%M%S)"
REPORT_DIR="company/reports/autonomous-discovery"
RUNTIME_DIR="company/runtime/autonomous-discovery"
mkdir -p "$REPORT_DIR" "$RUNTIME_DIR"

REPORT="$REPORT_DIR/${STAMP}-discovery.md"
CANDIDATES="$RUNTIME_DIR/${STAMP}-candidates.tsv"

touch "$CANDIDATES"

add_candidate() {
  local signature="$1"
  local title="$2"
  local description="$3"
  local priority="${4:-MEDIUM}"
  local agent="${5:-engineer_agent}"
  local phase="${6:-autonomous_development}"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$signature" \
    "$priority" \
    "$agent" \
    "$phase" \
    "$title" \
    "$description" >> "$CANDIDATES"
}

run_check() {
  local name="$1"
  shift

  echo "## Check: $name" >> "$REPORT"
  echo >> "$REPORT"
  echo '```text' >> "$REPORT"

  set +e
  "$@" >> "$REPORT" 2>&1
  local status=$?
  set -e

  echo '```' >> "$REPORT"
  echo >> "$REPORT"
  echo "- exit_status: $status" >> "$REPORT"
  echo >> "$REPORT"

  return "$status"
}

{
  echo "# Autonomous Issue Discovery Report"
  echo
  echo "- generated_at: $(date)"
  echo "- repo: $(pwd)"
  echo "- branch: $(git branch --show-current 2>/dev/null || true)"
  echo "- commit: $(git log -1 --oneline 2>/dev/null || true)"
  echo
} > "$REPORT"

# 1. Git cleanliness signal
if [ -n "$(git status --porcelain)" ]; then
  add_candidate \
    "git_dirty_worktree" \
    "Review dirty working tree" \
    "The repository has uncommitted changes. Review whether these are expected, commit them, or clean them before autonomous development continues." \
    "HIGH" \
    "engineer_agent" \
    "repo_hygiene"
fi

echo "## Git Status" >> "$REPORT"
echo '```text' >> "$REPORT"
git status --short >> "$REPORT" 2>&1 || true
echo '```' >> "$REPORT"
echo >> "$REPORT"

# 2. Health checks
if [ -x ./runners/dashboard_health_check.sh ]; then
  if ! run_check "dashboard_health_check" ./runners/dashboard_health_check.sh; then
    add_candidate \
      "dashboard_health_check_failed" \
      "Fix dashboard health check failure" \
      "The dashboard health check failed. Inspect dashboard service, local endpoint, routes, and recent changes." \
      "HIGH" \
      "engineer_agent" \
      "dashboard"
  fi
fi

if [ -x ./runners/agent_services_health_check.sh ]; then
  if ! run_check "agent_services_health_check" ./runners/agent_services_health_check.sh; then
    add_candidate \
      "agent_services_health_check_failed" \
      "Fix AI agent service health failure" \
      "One or more AI agent systemd services are unhealthy. Inspect service status and managed worker loop logs." \
      "HIGH" \
      "devops_agent" \
      "infrastructure"
  fi
fi

if [ -x ./runners/pixel_office_asset_check.sh ]; then
  if ! run_check "pixel_office_asset_check" ./runners/pixel_office_asset_check.sh; then
    add_candidate \
      "pixel_office_asset_check_failed" \
      "Fix Pixel Office asset configuration" \
      "Pixel Office asset folders or config validation failed. Inspect assets/office/config.json and ignored asset folders." \
      "MEDIUM" \
      "engineer_agent" \
      "dashboard"
  fi
fi

# 3. Pre-commit health signal
if [ -x ./runners/pre_commit_check.sh ]; then
  if ! run_check "pre_commit_check" ./runners/pre_commit_check.sh; then
    add_candidate \
      "pre_commit_check_failed" \
      "Fix pre-commit check failure" \
      "The pre-commit check failed. Inspect shell syntax, dashboard health, service health, and repository consistency." \
      "HIGH" \
      "qa_agent" \
      "quality"
  fi
fi

# 4. Source code TODO/FIXME scan
TODO_OUT="$RUNTIME_DIR/${STAMP}-todo-scan.txt"
git grep -nE 'TODO|FIXME|HACK|XXX' -- apps runners projects/internal company/config 2>/dev/null \
  | grep -v 'autonomous_issue_discovery.sh' \
  | head -50 > "$TODO_OUT" || true

echo "## TODO/FIXME/HACK Scan" >> "$REPORT"
echo '```text' >> "$REPORT"
cat "$TODO_OUT" >> "$REPORT" || true
echo '```' >> "$REPORT"
echo >> "$REPORT"

if [ -s "$TODO_OUT" ]; then
  add_candidate \
    "repo_todo_fixme_scan" \
    "Review and resolve TODO/FIXME findings" \
    "The repository contains TODO/FIXME/HACK markers. Review $TODO_OUT and convert actionable items into safe implementation improvements." \
    "LOW" \
    "engineer_agent" \
    "code_quality"
fi

# 5. Stale internal task guard signal, if available
if [ -x ./runners/stale_internal_task_guard.sh ]; then
  if ! run_check "stale_internal_task_guard" ./runners/stale_internal_task_guard.sh; then
    add_candidate \
      "stale_internal_task_guard_failed" \
      "Review stale internal tasks" \
      "Stale internal task guard reported issues. Review stuck tasks and recover or close them safely." \
      "MEDIUM" \
      "pm_agent" \
      "operations"
  fi
fi

# 6. Summary
{
  echo "## Candidate Summary"
  echo
  if [ -s "$CANDIDATES" ]; then
    awk -F '\t' '{print "- [" $2 "] " $5 " -> " $1}' "$CANDIDATES"
  else
    echo "No candidate issues found."
  fi
  echo
  echo "## Output Files"
  echo
  echo "- report: $REPORT"
  echo "- candidates: $CANDIDATES"
} >> "$REPORT"

echo "$REPORT"
echo "$CANDIDATES"
