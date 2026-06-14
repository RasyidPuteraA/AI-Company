#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/codex_budget.env"
LEDGER="company/runtime/codex_usage.jsonl"
REPORT_DIR="company/reports/ops"
mkdir -p "$REPORT_DIR"

OUT="$REPORT_DIR/$(date +%F)-codex-usage.md"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG"
fi

limit_status="$(./runners/codex_limit_status.sh 2>/dev/null || true)"

python3 - "$LEDGER" "$OUT" \
  "${CODEX_DAILY_SOFT_LIMIT_TOKENS:-300000}" \
  "${CODEX_DAILY_HARD_LIMIT_TOKENS:-500000}" \
  "${CODEX_WEEKLY_SOFT_LIMIT_TOKENS:-2000000}" \
  "${CODEX_MONTHLY_SOFT_LIMIT_TOKENS:-8000000}" \
  "${CODEX_INTERNAL_BUDGET_ENFORCEMENT:-warn}" \
  "${CODEX_INTERNAL_BUDGET_NOTE:-Internal estimate only, not official Codex limit}" \
  "$limit_status" << 'PY'
import json, sys
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

ledger = Path(sys.argv[1])
out = Path(sys.argv[2])
daily_soft = int(sys.argv[3])
daily_hard = int(sys.argv[4])
weekly_soft = int(sys.argv[5])
monthly_soft = int(sys.argv[6])
internal_enforcement = sys.argv[7]
internal_note = sys.argv[8]
limit_status_text = sys.argv[9]

def parse_kv(text):
    result = {}
    for line in text.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key] = value
    return result

limit_status = parse_kv(limit_status_text)

now = datetime.now()
today = now.date()
week_start = today - timedelta(days=today.weekday())
month_start = today.replace(day=1)

items = []
if ledger.exists():
    for line in ledger.read_text().splitlines():
        try:
            items.append(json.loads(line))
        except Exception:
            pass

def date_of(item):
    try:
        return datetime.fromisoformat(item.get("created_at", "")).date()
    except Exception:
        return None

def item_tokens(item):
    return int(item.get("tokens_used") or item.get("estimated_total_tokens") or 0)

def total_since(start):
    return sum(item_tokens(i) for i in items if date_of(i) and date_of(i) >= start)

today_total = total_since(today)
week_total = total_since(week_start)
month_total = total_since(month_start)

by_agent = defaultdict(int)
by_source = defaultdict(int)
for item in items:
    tokens = item_tokens(item)
    by_agent[item.get("agent_key", "unknown")] += tokens
    source = "direct_danger_logged" if item.get("mode") == "direct_danger_logged" or item.get("dangerously_bypass_approvals_and_sandbox") is True else "wrapper"
    by_source[source] += tokens

if today_total >= daily_hard:
    state = "STOP"
elif today_total >= daily_soft:
    state = "WARN"
else:
    state = "OK"

def table(headers, rows):
    if not rows:
        return "_None._"
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(str(x).replace("|", "\\|") for x in row) + " |")
    return "\n".join(lines)

recent = list(reversed(items[-20:]))

lines = []
lines.append("# AI Company OS Codex CLI Usage Report")
lines.append("")
lines.append(f"Generated at: {now.strftime('%Y-%m-%d %H:%M:%S')}")
lines.append("")
lines.append("> Internal Codex CLI token usage is an audit estimate. It is not official remaining quota unless values are captured from Codex CLI `/status` by the owner.")
lines.append("")
lines.append("## Internal Estimated Token Usage")
lines.append("")
lines.append(table(
    ["Window", "Used Tokens", "Internal Soft Estimate", "State"],
    [
        ["Today", today_total, f"soft {daily_soft} / hard {daily_hard}", state],
        ["This Week", week_total, weekly_soft, "WARN" if week_total >= weekly_soft else "OK"],
        ["This Month", month_total, monthly_soft, "WARN" if month_total >= monthly_soft else "OK"],
    ],
))
lines.append("")
lines.append("## Codex Real Limit Snapshot")
lines.append("")
lines.append(table(
    ["Field", "Value"],
    [
        ["source", limit_status.get("source", "")],
        ["observed_at", limit_status.get("observed_at", "")],
        ["stale", limit_status.get("stale", "")],
        ["recommended_state", limit_status.get("recommended_state", "")],
        ["5h left percent", limit_status.get("five_hour_left_percent", "")],
        ["5h reset", limit_status.get("five_hour_reset_at", "")],
        ["weekly left percent", limit_status.get("weekly_left_percent", "")],
        ["weekly reset", limit_status.get("weekly_reset_at", "")],
        ["note", limit_status.get("note", "")],
    ],
))
lines.append("")
lines.append("## Budget Enforcement")
lines.append("")
lines.append(table(
    ["Setting", "Value"],
    [
        ["CODEX_INTERNAL_BUDGET_ENFORCEMENT", internal_enforcement],
        ["Internal note", internal_note],
        ["Official quota note", "Not official remaining quota unless captured from Codex CLI /status by owner."],
    ],
))
lines.append("")
lines.append("## Usage By Agent")
lines.append("")
lines.append(table(["Agent", "Tokens Used"], sorted(by_agent.items(), key=lambda x: x[1], reverse=True)))
lines.append("")
lines.append("## Source Breakdown")
lines.append("")
lines.append(table(
    ["Source", "Estimated Tokens"],
    [
        ["wrapper", by_source.get("wrapper", 0)],
        ["direct_danger_logged", by_source.get("direct_danger_logged", 0)],
    ],
))
lines.append("")
lines.append("## Recent Codex Runs")
lines.append("")
lines.append(table(
    ["Created At", "Agent", "Task", "Mode", "Tokens", "Exit", "Seconds", "Output"],
    [[
        i.get("created_at", ""),
        i.get("agent_key", ""),
        i.get("task_key", ""),
        i.get("mode", ""),
        item_tokens(i),
        i.get("exit_status", ""),
        i.get("run_seconds", ""),
        i.get("output_path", ""),
    ] for i in recent],
))
lines.append("")
lines.append("## Policy")
lines.append("")
lines.append("- Agents should use `./runners/codex_agent_run.sh`, not raw `codex exec`.")
lines.append("- Owner-approved dangerous bypass runs should use `./runners/codex_exec_danger_logged.sh` so broad access is preserved and usage is visible.")
lines.append("- Client work has priority over idle internal improvement.")
lines.append("- Internal 500k/day is a soft estimate by default; set `CODEX_INTERNAL_BUDGET_ENFORCEMENT=stop` only when intentionally enforcing it.")
lines.append("- If budget state is `STOP`, it should come from a fresh real Codex limit snapshot unless internal enforcement is explicitly set to `stop`.")
lines.append("- Codex credentials must never be logged, committed, pasted, or shown in dashboard.")
lines.append("")

out.write_text("\n".join(lines))
print(f"Codex usage report generated:\n{out}")
PY
