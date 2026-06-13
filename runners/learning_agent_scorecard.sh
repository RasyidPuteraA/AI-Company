#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/ai_company_scheduler.env"
SCORECARD_DIR="company/learning/agent-scorecards"
REPORT_DIR="company/reports/learning"
TMP_DIR="company/runtime/learning"
TASKS_FILE="$TMP_DIR/tasks.tsv"
EVENTS_FILE="$TMP_DIR/scorecard-events.tsv"
REPORTS_FILE="$TMP_DIR/reports.txt"

mkdir -p "$SCORECARD_DIR" "$REPORT_DIR" "$TMP_DIR"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

: "${AI_COMPANY_LEARNING_ENABLED:=1}"
: "${AI_COMPANY_LEARNING_LOOKBACK_EVENTS:=50}"

if [ "$AI_COMPANY_LEARNING_ENABLED" != "1" ]; then
  echo "Learning disabled by config."
  exit 0
fi

: > "$TASKS_FILE"
: > "$EVENTS_FILE"
find company/reports -type f -name '*.md' 2>/dev/null | sort > "$REPORTS_FILE" || true

if command -v docker >/dev/null 2>&1; then
  docker exec -i ai_company_postgres psql \
    -U ai_company \
    -d ai_company \
    -t \
    -A \
    -F $'\t' \
    -v ON_ERROR_STOP=1 \
    -c "
SELECT COALESCE(assigned_agent_key,''), COALESCE(task_key,''), COALESCE(status,''), COALESCE(updated_at::text,'')
FROM tasks
ORDER BY updated_at DESC NULLS LAST, id DESC
LIMIT 250;
" > "$TASKS_FILE" 2>/dev/null || true

  docker exec -i ai_company_postgres psql \
    -U ai_company \
    -d ai_company \
    -t \
    -A \
    -F $'\t' \
    -v ON_ERROR_STOP=1 \
    -c "
SELECT COALESCE(agent_key,''), COALESCE(event_type,''), COALESCE(state,''), COALESCE(topic,''), COALESCE(created_at::text,'')
FROM events
ORDER BY id DESC
LIMIT $AI_COMPANY_LEARNING_LOOKBACK_EVENTS;
" > "$EVENTS_FILE" 2>/dev/null || true
fi

python3 - "$TASKS_FILE" "$EVENTS_FILE" "$REPORTS_FILE" "$SCORECARD_DIR" "$REPORT_DIR" <<'PY'
import datetime as dt
import sys
from collections import defaultdict
from pathlib import Path

tasks_file, events_file, reports_file, scorecard_dir, report_dir = [Path(arg) for arg in sys.argv[1:]]
agents = ["pm_agent", "engineer_agent", "qa_agent", "devops_agent", "budget_manager"]
stats = {
    agent: {
        "completed_tasks": 0,
        "failed_error_events": 0,
        "blocked_tasks": 0,
        "in_progress_stale_tasks": 0,
        "successful_reports": 0,
        "examples": [],
    }
    for agent in agents
}
now = dt.datetime.now(dt.timezone.utc).astimezone().replace(microsecond=0)

def parse_timestamp(value):
    value = (value or "").strip()
    if not value:
        return None
    normalized = value.replace(" ", "T")
    if normalized.endswith("+00"):
        normalized += ":00"
    try:
        parsed = dt.datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=now.tzinfo)
    return parsed.astimezone(now.tzinfo)

def add_agent(agent):
    if agent not in stats:
        stats[agent] = {
            "completed_tasks": 0,
            "failed_error_events": 0,
            "blocked_tasks": 0,
            "in_progress_stale_tasks": 0,
            "successful_reports": 0,
            "examples": [],
        }
    return stats[agent]

if tasks_file.exists():
    for line in tasks_file.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        agent, task, status, updated_at = parts[:4]
        if not agent:
            agent = "unknown_agent"
        row = add_agent(agent)
        upper = status.upper()
        if upper in {"DONE", "ACCEPTED", "PASS"}:
            row["completed_tasks"] += 1
        if "BLOCKED" in upper:
            row["blocked_tasks"] += 1
        updated = parse_timestamp(updated_at)
        if upper == "IN_PROGRESS" and (updated is None or (now - updated) > dt.timedelta(hours=24)):
            row["in_progress_stale_tasks"] += 1
        if len(row["examples"]) < 5:
            row["examples"].append(f"{task or 'unknown'}:{status or 'unknown'}")

if events_file.exists():
    for line in events_file.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.split("\t")
        if len(parts) < 5:
            continue
        agent, event_type, state, topic, created_at = parts[:5]
        if not agent:
            agent = "unknown_agent"
        row = add_agent(agent)
        joined = " ".join([event_type, state, topic]).lower()
        if any(word in joined for word in ["error", "fail", "blocked", "needs_revision"]):
            row["failed_error_events"] += 1

report_paths = reports_file.read_text(encoding="utf-8", errors="replace").splitlines() if reports_file.exists() else []
for report in report_paths:
    lower = report.lower()
    if "qa" in lower:
        add_agent("qa_agent")["successful_reports"] += 1
    elif "codex" in lower or "ops" in lower or "weekly" in lower or "3day" in lower:
        add_agent("devops_agent")["successful_reports"] += 1
    elif "daily" in lower:
        add_agent("pm_agent")["successful_reports"] += 1

def suggestions(row):
    items = []
    if row["failed_error_events"] > 0:
        items.append("Review recent failure lessons before similar work.")
    if row["blocked_tasks"] > 0:
        items.append("Resolve blocked task causes or escalate with a proposal.")
    if row["in_progress_stale_tasks"] > 0:
        items.append("Check in-progress work for stale ownership or missing handoff.")
    if row["successful_reports"] == 0:
        items.append("Produce a concise report after meaningful work completes.")
    if not items:
        items.append("Continue using existing gates and handover conventions.")
    return items

written = []
for agent, row in sorted(stats.items()):
    content = f"""# Agent Learning Scorecard: {agent}

- generated_at: {now.isoformat()}
- agent_key: {agent}
- completed_tasks: {row['completed_tasks']}
- failed_error_events: {row['failed_error_events']}
- blocked_tasks: {row['blocked_tasks']}
- in_progress_stale_tasks: {row['in_progress_stale_tasks']}
- successful_reports: {row['successful_reports']}

## Suggested Improvement Areas

"""
    for item in suggestions(row):
        content += f"- {item}\n"
    content += "\n## Recent Examples\n\n"
    content += "\n".join(f"- {example}" for example in row["examples"]) if row["examples"] else "- No task examples available."
    content += "\n"
    path = scorecard_dir / f"{agent}.md"
    path.write_text(content, encoding="utf-8")
    written.append(str(path))

report_path = report_dir / f"{now.strftime('%Y-%m-%d')}-agent-scorecards.md"
report_path.write_text(
    "# Learning Agent Scorecard Review\n\n"
    f"- generated_at: {now.isoformat()}\n"
    f"- scorecards_written: {len(written)}\n\n"
    "## Scorecards\n\n" + "\n".join(f"- {path}" for path in written) + "\n",
    encoding="utf-8",
)
print(f"scorecards_written={len(written)}")
for path in written:
    print(path)
print(f"report={report_path}")
PY
