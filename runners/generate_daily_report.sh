#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/opt/ai-company"
REPORT_DIR="$ROOT_DIR/company/reports/daily"
REPORT_DATE="$(date +%F)"
REPORT_FILE="$REPORT_DIR/$REPORT_DATE-daily-report.md"

mkdir -p "$REPORT_DIR"

TMP_TASKS="$(mktemp)"
TMP_EVENTS="$(mktemp)"
TMP_AGENT_SUMMARY="$(mktemp)"

cleanup() {
  rm -f "$TMP_TASKS" "$TMP_EVENTS" "$TMP_AGENT_SUMMARY"
}
trap cleanup EXIT

docker exec -i ai_company_postgres psql -U ai_company -d ai_company -P pager=off -A -F ' | ' -c "
SELECT
  task_key,
  title,
  status,
  assigned_agent_key,
  current_phase,
  COALESCE(handover_note, '')
FROM tasks
ORDER BY updated_at DESC
LIMIT 20;
" > "$TMP_TASKS"

docker exec -i ai_company_postgres psql -U ai_company -d ai_company -P pager=off -A -F ' | ' -c "
SELECT
  event_type,
  agent_key,
  state,
  location,
  topic,
  created_at
FROM events
ORDER BY created_at DESC
LIMIT 20;
" > "$TMP_EVENTS"

docker exec -i ai_company_postgres psql -U ai_company -d ai_company -P pager=off -A -F ' | ' -c "
SELECT
  agent_key,
  COUNT(*) AS event_count,
  MAX(created_at) AS last_activity
FROM events
GROUP BY agent_key
ORDER BY event_count DESC;
" > "$TMP_AGENT_SUMMARY"

cat > "$REPORT_FILE" << REPORT
# AI Company OS Daily Report

Date: $REPORT_DATE
Timezone: Asia/Jakarta
Generated at: $(date)

## Executive Summary

Today the AI Company OS pipeline is operational.

Completed capabilities:
- Engineer runner can execute implementation tasks.
- QA runner can run tests and generate QA reports.
- Events are logged to PostgreSQL.
- Task statuses are updated in PostgreSQL.
- Work is committed into Git.

## Latest Tasks

\`\`\`text
$(cat "$TMP_TASKS")
\`\`\`

## Latest Events

\`\`\`text
$(cat "$TMP_EVENTS")
\`\`\`

## Agent Activity Summary

\`\`\`text
$(cat "$TMP_AGENT_SUMMARY")
\`\`\`

## QA Status

Latest QA events should show whether the latest task passed or failed.

Current observed pattern:
- engineering_started
- engineering_completed
- qa_completed

## Notes

This is the first generated daily report script. Future versions should:
- filter only today's events
- summarize by project
- summarize failures/blockers
- include budget/fatigue estimates
- create recommendations automatically

## Recommended Next Action

Build the next layer:
- create project/task creation runner
- create web dashboard or terminal dashboard
- add automatic daily report event logging
REPORT

echo "Daily report generated:"
echo "$REPORT_FILE"
