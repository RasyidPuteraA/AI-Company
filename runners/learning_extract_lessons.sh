#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/ai_company_scheduler.env"
LESSON_DIR="company/learning/lessons"
REPORT_DIR="company/reports/learning"
TMP_DIR="company/runtime/learning"
EVENTS_FILE="$TMP_DIR/recent-events.tsv"

mkdir -p "$LESSON_DIR" "$REPORT_DIR" "$TMP_DIR"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

: "${AI_COMPANY_LEARNING_ENABLED:=1}"
: "${AI_COMPANY_LEARNING_MAX_LESSONS_PER_RUN:=10}"
: "${AI_COMPANY_LEARNING_LOOKBACK_EVENTS:=50}"

if [ "$AI_COMPANY_LEARNING_ENABLED" != "1" ]; then
  echo "Learning disabled by config."
  exit 0
fi

if ! [[ "$AI_COMPANY_LEARNING_MAX_LESSONS_PER_RUN" =~ ^[0-9]+$ ]]; then
  AI_COMPANY_LEARNING_MAX_LESSONS_PER_RUN=10
fi
if ! [[ "$AI_COMPANY_LEARNING_LOOKBACK_EVENTS" =~ ^[0-9]+$ ]]; then
  AI_COMPANY_LEARNING_LOOKBACK_EVENTS=50
fi

: > "$EVENTS_FILE"
if command -v docker >/dev/null 2>&1; then
  docker exec -i ai_company_postgres psql \
    -U ai_company \
    -d ai_company \
    -t \
    -A \
    -F $'\t' \
    -v ON_ERROR_STOP=1 \
    -c "
SELECT
  e.id,
  COALESCE(e.created_at::text, ''),
  COALESCE(e.agent_key, ''),
  COALESCE(t.task_key, ''),
  COALESCE(e.event_type, ''),
  COALESCE(e.state, ''),
  COALESCE(e.topic, ''),
  COALESCE(e.summary, '')
FROM events e
LEFT JOIN tasks t ON t.id = e.task_id
ORDER BY e.id DESC
LIMIT $AI_COMPANY_LEARNING_LOOKBACK_EVENTS;
" > "$EVENTS_FILE" 2>/dev/null || true
fi

python3 - "$EVENTS_FILE" "$LESSON_DIR" "$REPORT_DIR" "$AI_COMPANY_LEARNING_MAX_LESSONS_PER_RUN" <<'PY'
import datetime as dt
import hashlib
import os
import re
import sys
from pathlib import Path

events_file = Path(sys.argv[1])
lesson_dir = Path(sys.argv[2])
report_dir = Path(sys.argv[3])
max_lessons = int(sys.argv[4])

SECRET_PATTERNS = [
    re.compile(r"(?i)(api[_-]?key|token|secret|password|passwd|authorization|bearer)\s*[:=]\s*\S+"),
    re.compile(r"sk-[A-Za-z0-9_-]{12,}"),
]

def sanitize(text, limit=240):
    text = (text or "").replace("\r", " ").replace("\n", " ")
    for pattern in SECRET_PATTERNS:
      text = pattern.sub("[REDACTED]", text)
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > limit:
        text = text[: limit - 3].rstrip() + "..."
    return text

def infer_problem(event_type, state, topic, summary):
    joined = " ".join([event_type, state, topic, summary]).lower()
    if "budget" in joined:
        return "Budget gate or usage threshold affected autonomous work."
    if "work hour" in joined or "outside work" in joined or "overtime" in joined:
        return "Work-hours policy affected when autonomous work could run."
    if "pre-commit" in joined or "syntax" in joined or "bash -n" in joined:
        return "Verification or syntax checks failed during automation."
    if "dashboard" in joined:
        return "Dashboard health or integration check reported a problem."
    if "lock" in joined:
        return "A shared-resource lock constrained or blocked work."
    if "qa" in joined and ("fail" in joined or "failed" in joined):
        return "QA verification reported a failed outcome."
    if "blocked" in joined:
        return "Task progress was blocked and needs follow-up."
    if "error" in joined or "fail" in joined:
        return "An agent or runner reported an error/failure."
    return "Operational event should be converted into reusable learning."

def infer_resolution(state):
    if state.upper() in {"DONE", "PASS", "ACCEPTED"}:
        return "Keep the successful workflow as reference context."
    return "Create a proposal or internal follow-up before changing code or policy."

def infer_prevention(problem):
    if "Budget" in problem:
        return "Check budget status before starting expensive Codex or multi-agent cycles."
    if "Work-hours" in problem:
        return "Check work-hours mode and overtime rules before creating new work."
    if "Verification" in problem:
        return "Run syntax and pre-commit checks before marking implementation complete."
    if "Dashboard" in problem:
        return "Run dashboard health checks after dashboard API or UI changes."
    if "lock" in problem.lower():
        return "Use the existing lock runner around shared repo, dashboard, database, QA, and DevOps operations."
    if "QA" in problem:
        return "Keep QA failures in a visible queue and require a targeted remediation task."
    return "Summarize the lesson and provide it in future agent context before similar work starts."

def existing_sources():
    seen = set()
    for path in lesson_dir.glob("*.md"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        match = re.search(r"^- source: (.+)$", text, re.MULTILINE)
        if match:
            seen.add(match.group(1).strip())
    return seen

def read_events():
    rows = []
    if events_file.exists():
        for line in events_file.read_text(encoding="utf-8", errors="replace").splitlines():
            parts = line.split("\t")
            if len(parts) < 8:
                continue
            rows.append({
                "id": parts[0],
                "created_at": parts[1],
                "agent_key": parts[2],
                "task_key": parts[3],
                "event_type": parts[4],
                "state": parts[5],
                "topic": parts[6],
                "summary": parts[7],
            })
    return rows

def is_learning_candidate(row):
    joined = " ".join([row["event_type"], row["state"], row["topic"], row["summary"]]).lower()
    return any(word in joined for word in [
        "error", "failed", "failure", "blocked", "qa_failed", "needs_revision",
        "budget", "outside work", "pre-commit", "syntax", "lock"
    ])

now = dt.datetime.now(dt.timezone.utc).astimezone().replace(microsecond=0).isoformat()
seen = existing_sources()
created = []

for row in read_events():
    if len(created) >= max_lessons:
        break
    if not is_learning_candidate(row):
        continue
    source = f"event:{row['id']}"
    if source in seen:
        continue
    raw = "|".join(row.values())
    digest = hashlib.sha1(raw.encode("utf-8")).hexdigest()[:10]
    lesson_id = f"LESSON-{dt.datetime.now().strftime('%Y%m%d%H%M%S')}-{digest}"
    problem = infer_problem(row["event_type"], row["state"], row["topic"], row["summary"])
    lesson_path = lesson_dir / f"{lesson_id}.md"
    task_file = f"projects/internal/ai-company-os/{row['task_key']}.md" if row["task_key"].startswith(("INTERNAL-", "AUTO-")) else ""
    content = f"""# {lesson_id}

- lesson_id: {lesson_id}
- created_at: {now}
- source: {source}
- agent_key: {sanitize(row['agent_key'], 80) or 'unknown'}
- task_key: {sanitize(row['task_key'], 80) or 'unknown'}
- event_type: {sanitize(row['event_type'], 80) or 'unknown'}
- problem: {problem}
- likely_cause: {sanitize(row['topic'] or row['summary']) or 'Recent operational event indicated a repeatable risk.'}
- resolution: {infer_resolution(row['state'])}
- prevention_rule: {infer_prevention(problem)}
- confidence: medium
- linked_files_or_commits: {task_file or 'none'}
- status: proposed

## Sanitized Evidence

- state: {sanitize(row['state'], 80) or 'unknown'}
- topic: {sanitize(row['topic']) or 'none'}
- summary: {sanitize(row['summary']) or 'none'}
"""
    lesson_path.write_text(content, encoding="utf-8")
    created.append(str(lesson_path))

report_path = report_dir / f"{dt.datetime.now().strftime('%Y-%m-%d')}-lesson-extraction.md"
report_path.write_text(
    "# Learning Lesson Extraction\n\n"
    f"- generated_at: {now}\n"
    f"- created_lessons: {len(created)}\n"
    f"- source_events_file: {events_file}\n\n"
    "## Created Lessons\n\n"
    + ("\n".join(f"- {path}" for path in created) if created else "- No new lesson candidates found.\n"),
    encoding="utf-8",
)

print(f"created_lessons={len(created)}")
for path in created:
    print(path)
print(f"report={report_path}")
PY
