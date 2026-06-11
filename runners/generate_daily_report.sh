#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GENERATOR="${PROJECT_ROOT}/scripts/generate_daily_report.py"
REPORT_DIR="${PROJECT_ROOT}/company/reports/daily"
REPORT_DATE="$(date +%F)"
REPORT_FILE="${REPORT_DIR}/${REPORT_DATE}-daily-report.md"
INPUT_FILE="/tmp/ai-company-daily-report-${REPORT_DATE}.json"

mkdir -p "$REPORT_DIR"

if [ ! -f "$GENERATOR" ]; then
  echo "Generator not found: $GENERATOR"
  exit 1
fi

python3 - << PY
import json
import subprocess
from datetime import date

report_date = "${REPORT_DATE}"
input_file = "${INPUT_FILE}"

def psql_json(sql):
    cmd = [
        "docker", "exec", "ai_company_postgres",
        "psql", "-U", "ai_company", "-d", "ai_company",
        "-t", "-A", "-c", sql
    ]
    result = subprocess.run(cmd, check=True, text=True, capture_output=True)
    text = result.stdout.strip()
    if not text:
        return []
    return json.loads(text)

client_tasks = psql_json("""
SELECT COALESCE(jsonb_agg(
  jsonb_build_object(
    'title', task_key || ' - ' || title,
    'owner', COALESCE(assigned_agent_key, 'unassigned'),
    'status', status,
    'due', COALESCE(to_char(updated_at::date, 'YYYY-MM-DD'), to_char(now()::date, 'YYYY-MM-DD'))
  )
  ORDER BY id DESC
), '[]'::jsonb)
FROM tasks
WHERE task_key NOT LIKE 'INTERNAL-%';
""")

internal_tasks = psql_json("""
SELECT COALESCE(jsonb_agg(
  jsonb_build_object(
    'title', task_key || ' - ' || title,
    'owner', COALESCE(assigned_agent_key, 'unassigned'),
    'status', status
  )
  ORDER BY id DESC
), '[]'::jsonb)
FROM tasks
WHERE task_key LIKE 'INTERNAL-%';
""")

recent_events = psql_json("""
SELECT COALESCE(jsonb_agg(
  jsonb_build_object(
    'date', to_char(created_at::date, 'YYYY-MM-DD'),
    'description', event_type || ' | ' || COALESCE(agent_key, '-') || ' | ' || COALESCE(topic, '-'),
    'impact', COALESCE(summary, state, 'No summary')
  )
  ORDER BY id DESC
), '[]'::jsonb)
FROM (
  SELECT *
  FROM events
  ORDER BY id DESC
  LIMIT 12
) recent;
""")

qa_status = psql_json("""
SELECT COALESCE(jsonb_agg(
  jsonb_build_object(
    'name', COALESCE(topic, 'Automated QA'),
    'status', COALESCE(state, 'UNKNOWN'),
    'notes', COALESCE(summary, 'No QA notes')
  )
  ORDER BY id DESC
), '[]'::jsonb)
FROM (
  SELECT *
  FROM events
  WHERE event_type = 'qa_completed'
  ORDER BY id DESC
  LIMIT 8
) qa;
""")

open_failures = psql_json("""
SELECT COALESCE(jsonb_agg(
  jsonb_build_object(
    'title', task_key || ' - ' || title,
    'owner', COALESCE(assigned_agent_key, 'Project Owner'),
    'by', 'Next owner review',
    'recommendation', 'Review task status: ' || status || '. Handover: ' || COALESCE(handover_note, 'No handover note')
  )
  ORDER BY id DESC
), '[]'::jsonb)
FROM tasks
WHERE status IN ('QA_FAILED', 'WAITING_OWNER_ACCEPTANCE', 'BLOCKED', 'NEEDS_REVISION');
""")

if not open_failures:
    open_failures = [
        {
            "title": "Review completed work",
            "owner": "Project Owner",
            "by": "Next reporting cycle",
            "recommendation": "All recent tracked tasks are done. Review latest client delivery and decide whether to accept, revise, or move to staging."
        }
    ]

data = {
    "date": report_date,
    "summary": "Daily snapshot generated from PostgreSQL tasks, events, QA activity, and internal development records.",
    "client_tasks": client_tasks,
    "internal_tasks": internal_tasks,
    "recent_events": recent_events,
    "qa_status": qa_status,
    "recommended_owner_decisions": open_failures,
}

with open(input_file, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PY

python3 "$GENERATOR" "$INPUT_FILE" -o "$REPORT_FILE"

echo "Daily report generated:"
echo "$REPORT_FILE"
echo "Input snapshot:"
echo "$INPUT_FILE"
