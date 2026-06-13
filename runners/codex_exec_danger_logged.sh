#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
  cat <<'EOF'
Usage:
  ./runners/codex_exec_danger_logged.sh --prompt-file PATH [--agent-key AGENT] [--task-key TASK] [--mode MODE]
  ./runners/codex_exec_danger_logged.sh --prompt "..." [--agent-key AGENT] [--task-key TASK] [--mode MODE]

Runs Codex with the owner-approved dangerous bypass mode and records internal estimated usage.
EOF
}

PROMPT_FILE=""
PROMPT=""
TASK_KEY=""
AGENT_KEY=""
MODE="direct_danger_logged"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prompt-file)
      PROMPT_FILE="${2:-}"
      shift 2
      ;;
    --prompt)
      PROMPT="${2:-}"
      shift 2
      ;;
    --task-key)
      TASK_KEY="${2:-}"
      shift 2
      ;;
    --agent-key)
      AGENT_KEY="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [ -n "$PROMPT_FILE" ] && [ -n "$PROMPT" ]; then
  echo "FAIL: use either --prompt-file or --prompt, not both." >&2
  exit 64
fi

if [ -n "$PROMPT_FILE" ]; then
  if [ ! -f "$PROMPT_FILE" ]; then
    echo "FAIL: prompt file not found: $PROMPT_FILE" >&2
    exit 66
  fi
  PROMPT="$(<"$PROMPT_FILE")"
fi

if [ -z "$PROMPT" ]; then
  echo "FAIL: --prompt-file or --prompt is required." >&2
  usage >&2
  exit 64
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "FAIL: codex CLI not found" >&2
  exit 1
fi

AGENT_KEY="${AGENT_KEY:-unknown_agent}"
TASK_KEY="${TASK_KEY:-unknown_task}"
LEDGER="company/runtime/codex_usage.jsonl"
RUN_DIR="company/runtime/codex_runs/$(date +%F)"
mkdir -p "$RUN_DIR" "$(dirname "$LEDGER")"

safe_part() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_' | cut -c1-80
}

RUN_ID="$(date +%Y%m%d%H%M%S)-$(safe_part "$AGENT_KEY")-$(safe_part "$TASK_KEY")-$(safe_part "$MODE")"
OUT="$RUN_DIR/$RUN_ID.out"
START_TS="$(date +%s)"
CREATED_AT="$(date +%Y-%m-%dT%H:%M:%S)"

echo "# Dangerous Codex Exec Logged Run"
echo "- Agent: $AGENT_KEY"
echo "- Task: $TASK_KEY"
echo "- Mode: $MODE"
echo "- Command: codex exec --dangerously-bypass-approvals-and-sandbox"
echo "- Output: $OUT"
echo "- Token counts: internal chars/4 estimates, not official OpenAI usage or remaining quota."
echo

set +e
codex exec --dangerously-bypass-approvals-and-sandbox "$PROMPT" 2>&1 | tee "$OUT"
STATUS="${PIPESTATUS[0]}"
set -e

END_TS="$(date +%s)"
RUN_SECONDS="$((END_TS - START_TS))"

python3 - "$LEDGER" "$CREATED_AT" "$AGENT_KEY" "$TASK_KEY" "$MODE" "$STATUS" "$RUN_SECONDS" "$OUT" "$PROMPT" <<'PY'
import json
import sys
from pathlib import Path

ledger = Path(sys.argv[1])
created_at = sys.argv[2]
agent_key = sys.argv[3]
task_key = sys.argv[4]
mode = sys.argv[5] or "direct_danger_logged"
status = int(sys.argv[6] or 0)
run_seconds = int(sys.argv[7] or 0)
out = Path(sys.argv[8])
prompt = sys.argv[9]

output_text = out.read_text(encoding="utf-8", errors="replace") if out.exists() else ""
prompt_chars = len(prompt)
output_chars = len(output_text)
estimated_prompt_tokens = (prompt_chars + 3) // 4
estimated_output_tokens = (output_chars + 3) // 4
estimated_total_tokens = estimated_prompt_tokens + estimated_output_tokens

item = {
    "created_at": created_at,
    "agent_key": agent_key,
    "task_key": task_key,
    "mode": mode,
    "command": "codex exec --dangerously-bypass-approvals-and-sandbox",
    "dangerously_bypass_approvals_and_sandbox": True,
    "prompt_chars": prompt_chars,
    "output_chars": output_chars,
    "estimated_prompt_tokens": estimated_prompt_tokens,
    "estimated_output_tokens": estimated_output_tokens,
    "estimated_total_tokens": estimated_total_tokens,
    "tokens_used": estimated_total_tokens,
    "token_source": "estimate_chars_div_4",
    "token_estimate": True,
    "estimate_note": "Internal AI Company chars/4 estimate, not official OpenAI billing or remaining quota.",
    "exit_status": status,
    "run_seconds": run_seconds,
    "output_path": str(out),
    "prompt_preview": prompt[:180],
}

ledger.parent.mkdir(parents=True, exist_ok=True)
with ledger.open("a", encoding="utf-8") as f:
    f.write(json.dumps(item, ensure_ascii=False) + "\n")

print()
print("Dangerous Codex usage logged:")
print(f"- estimated_prompt_tokens: {estimated_prompt_tokens}")
print(f"- estimated_output_tokens: {estimated_output_tokens}")
print(f"- estimated_total_tokens: {estimated_total_tokens}")
print("- estimate_note: Internal estimate only, not official OpenAI usage or remaining quota.")
PY

exit "$STATUS"
