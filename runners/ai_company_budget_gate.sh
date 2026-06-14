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
: "${CODEX_INTERNAL_BUDGET_ENFORCEMENT:=warn}"
: "${CODEX_INTERNAL_BUDGET_NOTE:=Internal estimate only, not official Codex limit}"
: "${CODEX_HARD_STOP_ON_REAL_LIMIT:=1}"

internal_output="$(python3 - "$LEDGER" \
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

print(f"BUDGET_INTERNAL_RAW_STATE={state}")
print(f"BUDGET_TODAY_USED={today_used}")
print(f"BUDGET_DAILY_SOFT_LIMIT={daily_soft}")
print(f"BUDGET_DAILY_HARD_LIMIT={daily_hard}")
print(f"BUDGET_WEEK_USED={week_used}")
print(f"BUDGET_WEEKLY_SOFT_LIMIT={weekly_soft}")
print(f"BUDGET_MONTH_USED={month_used}")
print(f"BUDGET_MONTHLY_SOFT_LIMIT={monthly_soft}")
PY
)"

get_field() {
  local text="$1"
  local key="$2"
  printf "%s\n" "$text" | awk -F= -v key="$key" '$1==key {print substr($0, length(key) + 2)}' | tail -1
}

internal_raw_state="$(get_field "$internal_output" "BUDGET_INTERNAL_RAW_STATE")"
: "${internal_raw_state:=OK}"

case "$CODEX_INTERNAL_BUDGET_ENFORCEMENT" in
  stop)
    internal_state="$internal_raw_state"
    ;;
  off)
    internal_state="OK"
    ;;
  warn|*)
    if [ "$internal_raw_state" = "STOP" ]; then
      internal_state="WARN"
    else
      internal_state="$internal_raw_state"
    fi
    ;;
esac

real_output="$(./runners/codex_limit_status.sh 2>/dev/null || true)"
real_state="$(get_field "$real_output" "recommended_state")"
: "${real_state:=WARN}"

five_hour_left_percent="$(get_field "$real_output" "five_hour_left_percent")"
five_hour_reset_at="$(get_field "$real_output" "five_hour_reset_at")"
weekly_left_percent="$(get_field "$real_output" "weekly_left_percent")"
weekly_reset_at="$(get_field "$real_output" "weekly_reset_at")"
real_note="$(get_field "$real_output" "note")"

if [ "$real_state" = "STOP" ] && [ "$CODEX_HARD_STOP_ON_REAL_LIMIT" = "1" ]; then
  final_state="STOP"
elif [ "$internal_state" = "WARN" ] || [ "$real_state" = "WARN" ]; then
  final_state="WARN"
else
  final_state="OK"
fi

printf 'BUDGET_STATE=%s\n' "$final_state"
printf 'BUDGET_INTERNAL_STATE=%s\n' "$internal_state"
printf 'BUDGET_INTERNAL_RAW_STATE=%s\n' "$internal_raw_state"
printf 'BUDGET_REAL_LIMIT_STATE=%s\n' "$real_state"
printf 'BUDGET_ENFORCEMENT=%s\n' "$CODEX_INTERNAL_BUDGET_ENFORCEMENT"
printf '%s\n' "$internal_output" | grep -v '^BUDGET_INTERNAL_RAW_STATE='
printf 'BUDGET_NOTE=%s; real_limit: %s\n' "$CODEX_INTERNAL_BUDGET_NOTE" "${real_note:-unknown}"
printf 'CODEX_5H_LEFT_PERCENT=%s\n' "$five_hour_left_percent"
printf 'CODEX_5H_RESET_AT=%s\n' "$five_hour_reset_at"
printf 'CODEX_WEEKLY_LEFT_PERCENT=%s\n' "$weekly_left_percent"
printf 'CODEX_WEEKLY_RESET_AT=%s\n' "$weekly_reset_at"

if [ "$final_state" = "STOP" ]; then
  exit 2
fi
