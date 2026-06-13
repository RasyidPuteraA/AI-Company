#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/ai_company_scheduler.env"
CONTEXT_DIR="company/learning/context"
LESSON_DIR="company/learning/lessons"
PATTERN_DIR="company/learning/patterns"
SCORECARD_DIR="company/learning/agent-scorecards"
REPORT_DIR="company/reports/learning"

mkdir -p "$CONTEXT_DIR" "$LESSON_DIR" "$PATTERN_DIR" "$SCORECARD_DIR" "$REPORT_DIR"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

: "${AI_COMPANY_LEARNING_ENABLED:=1}"

if [ "$AI_COMPANY_LEARNING_ENABLED" != "1" ]; then
  echo "Learning disabled by config."
  exit 0
fi

python3 - "$CONTEXT_DIR" "$LESSON_DIR" "$PATTERN_DIR" "$SCORECARD_DIR" "$REPORT_DIR" <<'PY'
import datetime as dt
import re
import sys
from pathlib import Path

context_dir, lesson_dir, pattern_dir, scorecard_dir, report_dir = [Path(arg) for arg in sys.argv[1:]]
now = dt.datetime.now(dt.timezone.utc).astimezone().replace(microsecond=0).isoformat()

def field(text, name):
    match = re.search(rf"^- {re.escape(name)}: (.*)$", text, re.MULTILINE)
    return match.group(1).strip() if match else ""

def latest(paths, limit):
    return sorted(paths, key=lambda p: p.stat().st_mtime, reverse=True)[:limit]

lessons = []
prevention_rules = []
for path in latest(list(lesson_dir.glob("*.md")), 10):
    text = path.read_text(encoding="utf-8", errors="replace")
    lessons.append((path, field(text, "problem") or path.stem, field(text, "status") or "proposed"))
    rule = field(text, "prevention_rule")
    if rule and rule not in prevention_rules:
        prevention_rules.append(rule)

patterns = []
for path in latest(list(pattern_dir.glob("*.md")), 5):
    text = path.read_text(encoding="utf-8", errors="replace")
    patterns.append((path, field(text, "title") or path.stem, field(text, "count") or "unknown"))

scorecards = []
for path in latest(list(scorecard_dir.glob("*.md")), 8):
    text = path.read_text(encoding="utf-8", errors="replace")
    agent = field(text, "agent_key") or path.stem
    failed = field(text, "failed_error_events") or "0"
    blocked = field(text, "blocked_tasks") or "0"
    stale = field(text, "in_progress_stale_tasks") or "0"
    scorecards.append((agent, failed, blocked, stale))

risks = []
if patterns:
    risks.append("Repeated failure patterns exist; review pattern notes before starting similar work.")
if any(item[1] != "0" or item[2] != "0" for item in scorecards):
    risks.append("Some agents have failure or blocked-work signals in their scorecards.")
if not lessons:
    risks.append("Learning memory is still sparse; agents should continue writing explicit handovers.")
if not risks:
    risks.append("No major learning risk detected from current memory files.")

content = f"""# Latest Learning Context

- generated_at: {now}
- purpose: Compact operational memory for future AI Company OS agents and Codex prompts.
- safety: Operational self-learning only. Do not fine-tune models, expose secrets, or auto-apply risky changes.

## Top Recent Lessons

"""
content += "\n".join(f"- {path}: {problem} (status={status})" for path, problem, status in lessons) if lessons else "- No lessons recorded yet."
content += "\n\n## Repeated Failure Patterns\n\n"
content += "\n".join(f"- {path}: {title} (count={count})" for path, title, count in patterns) if patterns else "- No repeated patterns over threshold."
content += "\n\n## Agent-Specific Notes\n\n"
content += "\n".join(f"- {agent}: failed/error events={failed}, blocked tasks={blocked}, stale in-progress tasks={stale}" for agent, failed, blocked, stale in scorecards) if scorecards else "- No scorecards generated yet."
content += "\n\n## Prevention Rules\n\n"
content += "\n".join(f"- {rule}" for rule in prevention_rules[:12]) if prevention_rules else "- Keep using work-hours, budget, lock, and pre-commit gates."
content += "\n\n## Current Known Risks\n\n"
content += "\n".join(f"- {risk}" for risk in risks)
content += "\n"

context_path = context_dir / "latest-learning-context.md"
context_path.write_text(content, encoding="utf-8")
report_path = report_dir / f"{dt.datetime.now().strftime('%Y-%m-%d')}-context-builder.md"
report_path.write_text(
    "# Learning Context Builder\n\n"
    f"- generated_at: {now}\n"
    f"- context_path: {context_path}\n"
    f"- lessons_included: {len(lessons)}\n"
    f"- patterns_included: {len(patterns)}\n"
    f"- scorecards_included: {len(scorecards)}\n",
    encoding="utf-8",
)
print(f"context={context_path}")
print(f"report={report_path}")
PY
