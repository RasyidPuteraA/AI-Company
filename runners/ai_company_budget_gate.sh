#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/codex_budget.env"
LEDGER="company/runtime/codex_usage.jsonl"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

: "${CODEX_DAILY_SOFT_LIMIT_TOKENS:=300000}"
: "${CODEX_DAILY_HARD_LIMIT_TOKENS:=500000}"
: "${CODEX_WEEKLY_SOFT_LIMIT_TOKENS:=2000000}"
: "${CODEX_MONTHLY_SOFT_LIMIT_TOKENS:=8000000}"

python3 - "$LEDGER" \
  "$CODEX_DAILY_SOFT_LIMIT_TOKENS" \
  "$CODEX_DAILY_HARD_LIMIT_TOKENS" \
  "$CODEX_WEEKLY_SOFT_LIMIT_TOKENS" \
  "$CODEX_MONTHLY_SOFT_LIMIT_TOKENS" <<'PY'
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path

ledger = Path(sys.argv[1])
daily_soft = int(sys.argv[2])
daily_hard = int(sys.argv[3])
weekly_soft = int(sys.argv[4])
monthly_soft = int(sys.argv[5])

now = datetime.now()
today = now.date()
week_start = today - timedelta(days=today.weekday())
month_start = today.replace(day=1)

items = []
if ledger.exists():
    for line in ledger.read_text(errors="ignore").splitlines():
        try:
            items.append(json.loads(line))
        except Exception:
            pass

def item_date(item):
    try:
        return datetime.fromisoformat(item.get("created_at", "")).date()
    except Exception:
        return None

def total_since(start):
    return sum(int(item.get("tokens_used") or 0) for item in items if item_date(item) and item_date(item) >= start)

today_used = total_since(today)
week_used = total_since(week_start)
month_used = total_since(month_start)

if today_used >= daily_hard:
    state = "STOP"
elif today_used >= daily_soft or week_used >= weekly_soft or month_used >= monthly_soft:
    state = "WARN"
else:
    state = "OK"

print(f"BUDGET_STATE={state}")
print(f"BUDGET_TODAY_USED={today_used}")
print(f"BUDGET_DAILY_SOFT_LIMIT={daily_soft}")
print(f"BUDGET_DAILY_HARD_LIMIT={daily_hard}")
print(f"BUDGET_WEEK_USED={week_used}")
print(f"BUDGET_WEEKLY_SOFT_LIMIT={weekly_soft}")
print(f"BUDGET_MONTH_USED={month_used}")
print(f"BUDGET_MONTHLY_SOFT_LIMIT={monthly_soft}")
print("BUDGET_NOTE=Internal AI Company Codex CLI budget estimate, not official OpenAI remaining quota.")

raise SystemExit(2 if state == "STOP" else 0)
PY
