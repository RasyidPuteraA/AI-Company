#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

AGENT="${1:-}"
TASK_KEY="${2:-}"
MODE="${3:---dry-run}"

if [ -z "$AGENT" ] || [ -z "$TASK_KEY" ]; then
  echo "Usage: $0 <agent_key> <task_key> [--dry-run|--run]"
  exit 2
fi

if [ -f company/config/autonomous_development.env ]; then
  # shellcheck disable=SC1091
  source company/config/autonomous_development.env
fi

: "${AI_COMPANY_ENABLE_AUTO_EDIT:=0}"
: "${AI_COMPANY_ENABLE_AUTO_COMMIT:=0}"
: "${AI_COMPANY_AUTO_PUSH:=0}"
: "${AI_COMPANY_AUTO_MARK_DONE:=0}"
: "${AI_COMPANY_AUTO_BRANCH_PREFIX:=autodev}"

CODEX_BIN="${CODEX_BIN:-/home/ubuntu/.local/bin/codex}"

mkdir -p company/runtime/autodev/prompts
mkdir -p company/runtime/autodev/runs

safe_task="$(printf '%s' "$TASK_KEY" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-')"
stamp="$(date +%Y%m%d%H%M%S)"
branch="${AI_COMPANY_AUTO_BRANCH_PREFIX}/${safe_task}-${stamp}"
prompt_file="company/runtime/autodev/prompts/${stamp}-${AGENT}-${TASK_KEY}.md"
run_file="company/runtime/autodev/runs/${stamp}-${AGENT}-${TASK_KEY}.out"

echo "# Autonomous Code Developer"
echo "- Agent: $AGENT"
echo "- Task: $TASK_KEY"
echo "- Mode: $MODE"
echo "- Auto edit: $AI_COMPANY_ENABLE_AUTO_EDIT"
echo "- Auto commit: $AI_COMPANY_ENABLE_AUTO_COMMIT"
echo "- Auto push: $AI_COMPANY_AUTO_PUSH"
echo "- Auto mark done: $AI_COMPANY_AUTO_MARK_DONE"
echo

context_file="$(./runners/autonomous_code_context.sh)"
echo "- Context file: $context_file"

task_note_file="company/runtime/autodev/task_notes/${TASK_KEY}.md"
if [ -f "$task_note_file" ]; then
  echo "- Task note file: $task_note_file"
fi

cat > "$prompt_file" << EOF_PROMPT
You are $AGENT in AI Company OS.

You are allowed to edit the repository for task: $TASK_KEY.

Mission:
- Understand the repository context from the provided context file.
- Make the smallest safe implementation needed for task $TASK_KEY.
- Prefer code, tests, docs, and runner changes that are auditable.
- Do not touch secrets, auth files, tokens, passwords, .env files, Codex credentials, SSH files, or company/runtime.
- Do not add binary assets, archives, databases, PNG/JPG/WebP/GIF files.
- Do not finalize client work without Owner approval.
- If uncertain, implement a safe bounded foundation and document the remaining manual step.
- Run relevant syntax checks if possible.
- End with a concise handover.

Repository context file:
$context_file

Autonomous task note, if available:
$(if [ -f "$task_note_file" ]; then cat "$task_note_file"; else echo "No autonomous task note file found."; fi)
EOF_PROMPT

if [ "$MODE" = "--dry-run" ]; then
  echo
  echo "Dry-run only. Prompt prepared:"
  echo "$prompt_file"
  echo
  echo "Next run example:"
  echo "AI_COMPANY_ENABLE_AUTO_EDIT=1 AI_COMPANY_ENABLE_AUTO_COMMIT=1 $0 $AGENT $TASK_KEY --run"
  exit 0
fi

if [ "$MODE" != "--run" ]; then
  echo "Unknown mode: $MODE"
  exit 2
fi

if [ "$AI_COMPANY_ENABLE_AUTO_EDIT" != "1" ]; then
  echo "Refusing to edit: AI_COMPANY_ENABLE_AUTO_EDIT is not 1."
  exit 1
fi

if [ ! -x "$CODEX_BIN" ]; then
  echo "Codex binary not executable: $CODEX_BIN"
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Refusing to start auto-edit because working tree is not clean."
  git status --short
  exit 1
fi

base_branch="$(git branch --show-current)"
git checkout -b "$branch"

set +e
"$CODEX_BIN" exec --cd "$(pwd)" --sandbox workspace-write "$(cat "$prompt_file")" | tee "$run_file"
codex_status="${PIPESTATUS[0]}"
set -e

echo
echo "- Codex exit status: $codex_status"

if [ "$codex_status" -ne 0 ]; then
  echo "Codex failed. Leaving branch for inspection: $branch"
  exit "$codex_status"
fi

if [ -z "$(git status --porcelain)" ]; then
  echo "No repository changes produced by Codex."
  git checkout "$base_branch"
  git branch -D "$branch"
  exit 0
fi

./runners/autonomous_code_guard.sh
./runners/pre_commit_check.sh

if [ "$AI_COMPANY_ENABLE_AUTO_COMMIT" = "1" ]; then
  git add -A
  ./runners/autonomous_code_guard.sh
  git commit -m "Auto-dev: ${TASK_KEY}"

  if [ "$AI_COMPANY_AUTO_PUSH" = "1" ]; then
    git push -u origin "$branch"
  fi

  if [ "$AI_COMPANY_AUTO_MARK_DONE" = "1" ]; then
    ./runners/update_agent_runtime_status.sh "$AGENT" done "$TASK_KEY" engineering_room "Autonomous code development completed and committed."
    ./runners/update_task_status.sh "$TASK_KEY" DONE "Autonomous code development completed and committed on branch $branch."
    ./runners/log_event.sh internal-ai-company-os "$TASK_KEY" "$AGENT" autonomous_code_committed DONE engineering_room "Autonomous code committed" "Branch: $branch"
  fi

  echo
  echo "Autonomous code development committed on branch:"
  echo "$branch"
else
  echo
  echo "Auto-commit disabled. Changes are left on branch:"
  echo "$branch"
  git status --short
fi
