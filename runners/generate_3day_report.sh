#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

REPORT_DIR="company/reports/3day"
mkdir -p "$REPORT_DIR"

OUT="$REPORT_DIR/$(date +%F)-3day-report.md"
SNAP="/tmp/ai-company-3day-report-$(date +%F).json"

python3 - "$OUT" "$SNAP" "3" "AI Company OS 3-Day Review Report" <<'INNERPY'
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

out = Path(sys.argv[1])
snap = Path(sys.argv[2])
period_days = int(sys.argv[3])
title = sys.argv[4]

def run_psql(sql, fail=True):
    cmd = [
        "docker", "exec", "ai_company_postgres",
        "psql", "-U", "ai_company", "-d", "ai_company",
        "-At", "-F", "\t", "-c", sql
    ]
    result = subprocess.run(cmd, text=True, capture_output=True)
    if result.returncode != 0:
        if fail:
            raise SystemExit("psql failed:\n" + result.stderr + "\nSQL:\n" + sql)
        return []
    rows = []
    for line in result.stdout.splitlines():
        if line.strip():
            rows.append(line.split("\t"))
    return rows

def esc(value):
    return str(value or "").replace("\n", " ").replace("|", "\\|").strip()

def md_table(headers, rows):
    if not rows:
        return "_None._"
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in rows:
        padded = list(row) + [""] * (len(headers) - len(row))
        lines.append("| " + " | ".join(esc(x) for x in padded[:len(headers)]) + " |")
    return "\n".join(lines)

summary = run_psql("""
SELECT
  count(*) FILTER (WHERE task_key LIKE 'CLIENT-%' OR task_key LIKE 'TASK-%')::text,
  count(*) FILTER (WHERE task_key LIKE 'INTERNAL-%')::text,
  count(*) FILTER (WHERE status = 'WAITING_OWNER_ACCEPTANCE')::text,
  count(*) FILTER (WHERE status = 'ACCEPTED')::text,
  count(*) FILTER (WHERE status = 'DONE')::text,
  count(*) FILTER (WHERE status IN ('BLOCKED','QA_FAILED','NEEDS_REVISION'))::text
FROM tasks;
""")

owner_attention = run_psql("""
SELECT task_key, title, status, coalesce(handover_note,''), updated_at::text
FROM tasks
WHERE status IN ('WAITING_OWNER_ACCEPTANCE','NEEDS_REVISION','QA_FAILED','BLOCKED')
ORDER BY updated_at DESC
LIMIT 20;
""")

active_work = run_psql("""
SELECT task_key, title, status, coalesce(assigned_agent_key,''), priority, updated_at::text
FROM tasks
WHERE status IN ('TODO','IN_PROGRESS','INTERNAL_BACKLOG')
ORDER BY
  CASE priority WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
  updated_at DESC
LIMIT 30;
""")

completed_work = run_psql(f"""
SELECT task_key, title, status, coalesce(assigned_agent_key,''), coalesce(handover_note,''), updated_at::text
FROM tasks
WHERE updated_at >= now() - interval '{period_days} days'
  AND status IN ('DONE','ACCEPTED','IMPLEMENTED','QA_PASSED')
ORDER BY updated_at DESC
LIMIT 40;
""")

event_table_rows = run_psql("""
SELECT table_name
FROM information_schema.columns
WHERE table_schema='public'
  AND column_name IN ('event_type','agent_key','state','location','topic','created_at')
GROUP BY table_name
HAVING count(DISTINCT column_name)=6
ORDER BY table_name
LIMIT 1;
""", fail=False)

events = []
event_table = event_table_rows[0][0] if event_table_rows else ""

if event_table:
    events = run_psql(f"""
    SELECT event_type, agent_key, state, location, topic, created_at::text
    FROM {event_table}
    WHERE created_at >= now() - interval '{period_days} days'
    ORDER BY created_at DESC
    LIMIT 30;
    """, fail=False)

data = {
    "summary": summary,
    "owner_attention": owner_attention,
    "active_work": active_work,
    "completed_work": completed_work,
    "event_table": event_table,
    "events": events,
}

snap.write_text(json.dumps(data, indent=2))

summary_row = summary[0] if summary else ["0","0","0","0","0","0"]

lines = []
lines.append(f"# {title}")
lines.append("")
lines.append(f"Generated at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
lines.append(f"Period: last {period_days} days")
lines.append("")
lines.append("## Executive Summary")
lines.append("")
lines.append(md_table(
    ["Client Tasks", "Internal Tasks", "Waiting Owner", "Accepted", "Done", "Needs Attention"],
    [summary_row],
))
lines.append("")
lines.append("## Owner Decisions / Attention")
lines.append("")
lines.append(md_table(["Task", "Title", "Status", "Note", "Updated At"], owner_attention))
lines.append("")
lines.append("## Active Work")
lines.append("")
lines.append(md_table(["Task", "Title", "Status", "Agent", "Priority", "Updated At"], active_work))
lines.append("")
lines.append("## Completed Work In Period")
lines.append("")
lines.append(md_table(["Task", "Title", "Status", "Agent", "Handover", "Updated At"], completed_work))
lines.append("")
lines.append("## Recent Agent Events")
lines.append("")
if event_table:
    lines.append(f"Event table: `{event_table}`")
    lines.append("")
lines.append(md_table(["Event Type", "Agent", "State", "Location", "Topic", "Created At"], events))
lines.append("")
lines.append("## Suggested Next Actions")
lines.append("")
if owner_attention:
    lines.append("- Review Owner attention queue first.")
else:
    lines.append("- No Owner approval is currently waiting.")
if active_work:
    lines.append("- Continue active internal/client tasks by priority.")
else:
    lines.append("- No active work found; agents may plan safe internal improvements.")
lines.append("- Run `./runners/health.sh` before operational decisions.")
lines.append("- Run `./runners/pre_commit_check.sh` before committing changes.")
lines.append("")

out.write_text("\n".join(lines))
print(f"Report generated:\n{out}")
print(f"Input snapshot:\n{snap}")
INNERPY
