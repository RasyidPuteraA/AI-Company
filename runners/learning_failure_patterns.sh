#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/ai_company_scheduler.env"
LESSON_DIR="company/learning/lessons"
PATTERN_DIR="company/learning/patterns"
REPORT_DIR="company/reports/learning"

mkdir -p "$LESSON_DIR" "$PATTERN_DIR" "$REPORT_DIR"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

: "${AI_COMPANY_LEARNING_ENABLED:=1}"
: "${AI_COMPANY_LEARNING_MIN_PATTERN_COUNT:=2}"

if [ "$AI_COMPANY_LEARNING_ENABLED" != "1" ]; then
  echo "Learning disabled by config."
  exit 0
fi

if ! [[ "$AI_COMPANY_LEARNING_MIN_PATTERN_COUNT" =~ ^[0-9]+$ ]]; then
  AI_COMPANY_LEARNING_MIN_PATTERN_COUNT=2
fi

python3 - "$LESSON_DIR" "$PATTERN_DIR" "$REPORT_DIR" "$AI_COMPANY_LEARNING_MIN_PATTERN_COUNT" <<'PY'
import datetime as dt
import re
import sys
from collections import defaultdict
from pathlib import Path

lesson_dir = Path(sys.argv[1])
pattern_dir = Path(sys.argv[2])
report_dir = Path(sys.argv[3])
min_count = int(sys.argv[4])
now = dt.datetime.now(dt.timezone.utc).astimezone().replace(microsecond=0).isoformat()

def field(text, name):
    match = re.search(rf"^- {re.escape(name)}: (.*)$", text, re.MULTILINE)
    return match.group(1).strip() if match else ""

def classify(text):
    lower = text.lower()
    if "budget" in lower:
        return "budget-gate", "Budget gate interruptions"
    if "work-hour" in lower or "work hours" in lower or "outside work" in lower or "overtime" in lower:
        return "work-hours", "Work-hours scheduling interruptions"
    if "pre-commit" in lower or "syntax" in lower or "bash -n" in lower:
        return "verification", "Verification check failures"
    if "dashboard" in lower:
        return "dashboard-health", "Dashboard health regressions"
    if "lock" in lower:
        return "lock-contention", "Shared lock contention"
    if "qa" in lower and "fail" in lower:
        return "qa-failures", "Repeated QA failures"
    if "blocked" in lower:
        return "blocked-work", "Blocked work items"
    if "error" in lower or "fail" in lower:
        return "runner-errors", "Runner or agent errors"
    return "general-risk", "General operational risk"

groups = defaultdict(list)
for path in sorted(lesson_dir.glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True):
    text = path.read_text(encoding="utf-8", errors="replace")
    problem = field(text, "problem")
    topic = field(text, "likely_cause")
    key, title = classify(problem + " " + topic + " " + text)
    groups[key].append({
        "path": str(path),
        "title": title,
        "created_at": field(text, "created_at") or now,
        "agent": field(text, "agent_key") or "unknown",
        "task": field(text, "task_key") or "unknown",
        "problem": problem or "unknown",
        "prevention": field(text, "prevention_rule") or "Review related lesson before starting similar work.",
    })

written = []
for key, items in sorted(groups.items()):
    if len(items) < min_count:
        continue
    first_seen = min(item["created_at"] for item in items)
    last_seen = max(item["created_at"] for item in items)
    agents = sorted({item["agent"] for item in items if item["agent"]})
    title = items[0]["title"]
    pattern_id = f"PATTERN-{key}"
    examples = items[:5]
    suggested_task = f"Review and reduce {title.lower()} using existing gates and non-destructive checks."
    content = f"""# {pattern_id}: {title}

- pattern_id: {pattern_id}
- title: {title}
- count: {len(items)}
- first_seen: {first_seen}
- last_seen: {last_seen}
- affected_agents: {', '.join(agents) if agents else 'unknown'}
- suggested_prevention: {examples[0]['prevention']}
- suggested_internal_task: {suggested_task}

## Examples

"""
    for item in examples:
        content += f"- {item['path']} | agent={item['agent']} | task={item['task']} | problem={item['problem']}\n"
    path = pattern_dir / f"{pattern_id}.md"
    path.write_text(content, encoding="utf-8")
    written.append(str(path))

report_path = report_dir / f"{dt.datetime.now().strftime('%Y-%m-%d')}-failure-patterns.md"
report_path.write_text(
    "# Learning Failure Pattern Review\n\n"
    f"- generated_at: {now}\n"
    f"- min_pattern_count: {min_count}\n"
    f"- patterns_written: {len(written)}\n\n"
    "## Patterns\n\n"
    + ("\n".join(f"- {path}" for path in written) if written else "- No repeated failure patterns met the threshold.\n"),
    encoding="utf-8",
)
print(f"patterns_written={len(written)}")
for path in written:
    print(path)
print(f"report={report_path}")
PY
