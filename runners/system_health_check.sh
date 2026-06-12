#!/usr/bin/env bash
set -euo pipefail

echo "# AI Company OS System Health Check"
echo "Generated at: $(date)"

FAILED=0

run_check() {
  local name="$1"
  shift

  echo
  echo "## $name"

  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    FAILED=1
  fi
}

run_check "Dashboard health" ./runners/dashboard_health_check.sh
run_check "Agent services health" ./runners/agent_services_health_check.sh
run_check "Company status readability" ./runners/company_status.sh
run_check "Owner inbox readability" ./runners/owner_inbox.sh

echo
echo "## Final result"

if [ "$FAILED" -ne 0 ]; then
  echo "AI Company OS system health check FAILED."
  exit 1
fi

echo "AI Company OS system health check passed."
