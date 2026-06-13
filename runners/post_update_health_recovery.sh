#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

REPORT_DIR="company/reports/post-update"
mkdir -p "$REPORT_DIR"

timestamp="$(date -Iseconds)"
stamp="$(date +%Y%m%dT%H%M%S%z)"
report="$REPORT_DIR/${stamp}-health-recovery.md"
owner_note=""
status="PASS"

run_check() {
  local name="$1"
  shift
  local output_file="$REPORT_DIR/${stamp}-${name}.log"

  set +e
  "$@" >"$output_file" 2>&1
  local rc=$?
  set -e

  if [ "$rc" -eq 0 ]; then
    printf "%s|PASS|%s|%s\n" "$name" "$rc" "$output_file"
  else
    printf "%s|FAIL|%s|%s\n" "$name" "$rc" "$output_file"
  fi
}

results=()

if [ -x ./runners/dashboard_health_check.sh ]; then
  results+=("$(run_check dashboard ./runners/dashboard_health_check.sh)")
else
  results+=("dashboard|WARN|127|missing runners/dashboard_health_check.sh")
fi

if [ -x ./runners/agent_services_health_check.sh ]; then
  results+=("$(run_check agent-services ./runners/agent_services_health_check.sh)")
else
  results+=("agent-services|WARN|127|missing runners/agent_services_health_check.sh")
fi

if [ -x ./runners/ai_company_scheduler_status.sh ]; then
  results+=("$(run_check scheduler-status ./runners/ai_company_scheduler_status.sh)")
else
  results+=("scheduler-status|WARN|127|missing runners/ai_company_scheduler_status.sh")
fi

for row in "${results[@]}"; do
  state="$(printf "%s" "$row" | cut -d'|' -f2)"
  if [ "$state" = "FAIL" ]; then
    status="FAIL"
  elif [ "$state" = "WARN" ] && [ "$status" != "FAIL" ]; then
    status="WARN"
  fi
done

{
  echo "# Post-Update Health Recovery"
  echo "- generated_at: $timestamp"
  echo "- status: $status"
  echo
  echo "## Checks"
  for row in "${results[@]}"; do
    name="$(printf "%s" "$row" | cut -d'|' -f1)"
    state="$(printf "%s" "$row" | cut -d'|' -f2)"
    rc="$(printf "%s" "$row" | cut -d'|' -f3)"
    output="$(printf "%s" "$row" | cut -d'|' -f4-)"
    echo "- $name: $state (exit=$rc, log=$output)"
  done
  echo
  echo "## Recovery Policy"
  echo "No rollback was attempted. This runner only checks health and writes owner-visible reports."
} > "$report"

if [ "$status" != "PASS" ]; then
  owner_note="$REPORT_DIR/${stamp}-OWNER-NOTE-health-recovery.md"
  {
    echo "# Owner Note: Post-Update Health Recovery Needs Attention"
    echo "- generated_at: $timestamp"
    echo "- status: $status"
    echo "- report: $report"
    echo
    echo "One or more post-update health checks did not pass. Review the linked report and per-check logs before applying more updates."
  } > "$owner_note"
fi

if [ -x ./runners/log_event.sh ]; then
  ./runners/log_event.sh \
    internal-ai-company-os \
    INTERNAL-085 \
    devops_agent \
    post_update_health_recovery \
    "$status" \
    runners/post_update_health_recovery.sh \
    "Post-update health recovery" \
    "Health recovery completed with status $status. Report: $report" >/dev/null 2>&1 || true
fi

echo "# Post-Update Health Recovery"
echo "- status: $status"
echo "- report: $report"
if [ -n "$owner_note" ]; then
  echo "- owner_note: $owner_note"
fi

[ "$status" = "PASS" ]
