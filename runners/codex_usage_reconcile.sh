#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

LEDGER="company/runtime/codex_usage.jsonl"
REPORT_DIR="company/reports/codex-usage"
mkdir -p "$REPORT_DIR"

OUT="$REPORT_DIR/$(date +%F)-codex-usage-reconciled.md"

python3 - "$LEDGER" "$OUT" <<'PY'
import json
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

ledger = Path(sys.argv[1])
out = Path(sys.argv[2])
now = datetime.now()

items = []
seen = set()
if ledger.exists():
    for line in ledger.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            item = json.loads(line)
        except Exception:
            continue

        dedupe_key = (
            item.get("created_at", ""),
            item.get("agent_key", ""),
            item.get("task_key", ""),
            item.get("mode", ""),
            item.get("output_path", ""),
        )
        if dedupe_key in seen:
            continue
        seen.add(dedupe_key)
        items.append(item)

def token_count(item):
    return int(
        item.get("tokens_used")
        or item.get("estimated_total_tokens")
        or item.get("estimated_tokens_used")
        or 0
    )

def source_of(item):
    if item.get("mode") == "direct_danger_logged":
        return "direct_danger_logged"
    if item.get("dangerously_bypass_approvals_and_sandbox") is True:
        return "direct_danger_logged"
    return "wrapper"

by_source = defaultdict(int)
by_agent = defaultdict(int)
by_mode = defaultdict(int)

for item in items:
    tokens = token_count(item)
    by_source[source_of(item)] += tokens
    by_agent[item.get("agent_key") or "unknown"] += tokens
    by_mode[item.get("mode") or "unknown"] += tokens

def table(headers, rows):
    if not rows:
        return "_None._"
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(str(value).replace("|", "\\|") for value in row) + " |")
    return "\n".join(lines)

recent = sorted(items, key=lambda item: item.get("created_at", ""), reverse=True)[:25]
total = sum(by_source.values())

lines = [
    "# AI Company OS Codex Usage Reconciliation",
    "",
    f"Generated at: {now.strftime('%Y-%m-%d %H:%M:%S')}",
    f"Ledger: `{ledger}`",
    "",
    "> Internal AI Company Codex CLI budget estimate, not official OpenAI billing usage or remaining quota.",
    "",
    "## Source Breakdown",
    "",
    table(
        ["Source", "Estimated Tokens"],
        [
            ["wrapper", by_source.get("wrapper", 0)],
            ["direct_danger_logged", by_source.get("direct_danger_logged", 0)],
            ["estimated/reconciled total", total],
        ],
    ),
    "",
    "## Usage By Agent",
    "",
    table(["Agent", "Estimated Tokens"], sorted(by_agent.items(), key=lambda row: row[1], reverse=True)),
    "",
    "## Usage By Mode",
    "",
    table(["Mode", "Estimated Tokens"], sorted(by_mode.items(), key=lambda row: row[1], reverse=True)),
    "",
    "## Recent Runs",
    "",
    table(
        ["Created At", "Agent", "Task", "Mode", "Source", "Estimated Tokens", "Exit", "Output"],
        [
            [
                item.get("created_at", ""),
                item.get("agent_key", ""),
                item.get("task_key", ""),
                item.get("mode", ""),
                source_of(item),
                token_count(item),
                item.get("exit_status", ""),
                item.get("output_path", ""),
            ]
            for item in recent
        ],
    ),
    "",
    "## Historical Limitation",
    "",
    "- Future dangerous direct runs are tracked when launched through `./runners/codex_exec_danger_logged.sh`.",
    "- Old raw `codex exec --dangerously-bypass-approvals-and-sandbox ...` runs that bypassed the ledger may not be exactly recoverable.",
    "- This reconciliation avoids double counting duplicate ledger records by created time, agent, task, mode, and output path.",
    "- Token counts are chars/4 estimates for dangerous logged runs unless the original wrapper recorded Codex CLI token output.",
    "",
]

out.write_text("\n".join(lines), encoding="utf-8")
print(f"Codex usage reconciliation generated:\n{out}")
PY
