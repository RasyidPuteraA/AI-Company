#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 AGENT_KEY TASK_KEY MODE PROMPT..."
  exit 1
fi

AGENT_KEY="$1"
TASK_KEY="$2"
MODE="$3"
shift 3
PROMPT="$*"

CONFIG="company/config/codex_budget.env"
LEDGER="company/runtime/codex_usage.jsonl"
RUN_DIR="company/runtime/codex_runs/$(date +%F)"
mkdir -p "$RUN_DIR" "$(dirname "$LEDGER")"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG"
fi

CODEX_DAILY_HARD_LIMIT_TOKENS="${CODEX_DAILY_HARD_LIMIT_TOKENS:-500000}"
CODEX_RUN_TIMEOUT_SECONDS="${CODEX_RUN_TIMEOUT_SECONDS:-240}"

if ! command -v codex >/dev/null 2>&1; then
  echo "FAIL: codex CLI not found"
  exit 1
fi

TODAY_USED="$(python3 - "$LEDGER" << 'PY'
import json, sys
from datetime import datetime
from pathlib import Path

ledger = Path(sys.argv[1])
today = datetime.now().date()
total = 0

if ledger.exists():
    for line in ledger.read_text().splitlines():
        try:
            item = json.loads(line)
            if datetime.fromisoformat(item["created_at"]).date() == today:
                total += int(item.get("tokens_used") or 0)
        except Exception:
            pass

print(total)
PY
)"

echo "# Codex Agent Run"
echo "- Agent: $AGENT_KEY"
echo "- Task: $TASK_KEY"
echo "- Mode: $MODE"
echo "- Today used before run: $TODAY_USED / $CODEX_DAILY_HARD_LIMIT_TOKENS"

if [ "$TODAY_USED" -ge "$CODEX_DAILY_HARD_LIMIT_TOKENS" ] && [ "${AI_COMPANY_CODEX_ALLOW_OVER_BUDGET:-0}" != "1" ]; then
  echo "FAIL: Codex internal daily hard limit reached."
  exit 2
fi

case "$MODE" in
  code|engineering|engineer|write)
    SANDBOX="workspace-write"
    ;;
  *)
    SANDBOX="read-only"
    ;;
esac

RUN_ID="$(date +%Y%m%d%H%M%S)-${AGENT_KEY}-${TASK_KEY}-${MODE}"
OUT="$RUN_DIR/$RUN_ID.out"
START_TS="$(date +%s)"

set +e
timeout "${CODEX_RUN_TIMEOUT_SECONDS}s" codex exec --cd /opt/ai-company --sandbox "$SANDBOX" "$PROMPT" 2>&1 | tee "$OUT"
STATUS="${PIPESTATUS[0]}"
set -e

END_TS="$(date +%s)"
RUN_SECONDS="$((END_TS - START_TS))"

TOKENS_USED="$(python3 - "$OUT" << 'PY'
import re, sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text(errors="ignore").splitlines()

for i, line in enumerate(lines):
    if line.strip().lower().startswith("tokens used"):
        for next_line in lines[i+1:i+5]:
            m = re.search(r"([0-9][0-9,]*)", next_line)
            if m:
                print(m.group(1).replace(",", ""))
                raise SystemExit

print(0)
PY
)"

python3 - "$LEDGER" "$AGENT_KEY" "$TASK_KEY" "$MODE" "$SANDBOX" "$TOKENS_USED" "$STATUS" "$RUN_SECONDS" "$OUT" "$PROMPT" << 'PY'
import json, sys
from datetime import datetime
from pathlib import Path

ledger = Path(sys.argv[1])
ledger.parent.mkdir(parents=True, exist_ok=True)

item = {
    "created_at": datetime.now().isoformat(timespec="seconds"),
    "agent_key": sys.argv[2],
    "task_key": sys.argv[3],
    "mode": sys.argv[4],
    "sandbox": sys.argv[5],
    "tokens_used": int(sys.argv[6] or 0),
    "exit_status": int(sys.argv[7] or 0),
    "run_seconds": int(sys.argv[8] or 0),
    "output_path": sys.argv[9],
    "prompt_preview": sys.argv[10][:180],
}

with ledger.open("a") as f:
    f.write(json.dumps(item, ensure_ascii=False) + "\n")
PY

echo
echo "Codex usage logged:"
echo "- tokens_used: $TOKENS_USED"
echo "- exit_status: $STATUS"
echo "- run_seconds: $RUN_SECONDS"
echo "- output_path: $OUT"

exit "$STATUS"
