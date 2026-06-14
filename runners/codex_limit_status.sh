#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/codex_budget.env"
SNAPSHOT="company/runtime/codex_limits/latest.env"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

: "${CODEX_LIMIT_STALE_AFTER_MINUTES:=90}"
: "${CODEX_5H_MIN_LEFT_PERCENT:=3}"
: "${CODEX_WEEKLY_MIN_LEFT_PERCENT:=3}"
: "${CODEX_LIMIT_SOURCE:=manual_cli_status}"

if [ ! -f "$SNAPSHOT" ]; then
  cat <<EOF
source=$CODEX_LIMIT_SOURCE
observed_at=
stale=yes
five_hour_left_percent=
five_hour_reset_at=
weekly_left_percent=
weekly_reset_at=
recommended_state=WARN
note=Codex limit snapshot missing; run runners/codex_limit_snapshot_update.sh after Codex CLI /status.
EOF
  exit 0
fi

if ! bash -n "$SNAPSHOT" 2>/dev/null; then
  cat <<EOF
source=$CODEX_LIMIT_SOURCE
observed_at=
stale=yes
five_hour_left_percent=
five_hour_reset_at=
weekly_left_percent=
weekly_reset_at=
recommended_state=WARN
note=Codex limit snapshot is malformed; update it from Codex CLI /status.
EOF
  exit 0
fi

# shellcheck disable=SC1090
source "$SNAPSHOT"

: "${CODEX_LIMIT_OBSERVED_AT:=}"
: "${CODEX_LIMIT_SOURCE:=manual_cli_status}"
: "${CODEX_5H_LEFT_PERCENT:=}"
: "${CODEX_5H_RESET_AT:=}"
: "${CODEX_WEEKLY_LEFT_PERCENT:=}"
: "${CODEX_WEEKLY_RESET_AT:=}"
: "${CODEX_LIMIT_NOTE:=}"

python3 - "$CODEX_LIMIT_SOURCE" "$CODEX_LIMIT_OBSERVED_AT" "$CODEX_LIMIT_STALE_AFTER_MINUTES" \
  "$CODEX_5H_LEFT_PERCENT" "$CODEX_5H_RESET_AT" "$CODEX_5H_MIN_LEFT_PERCENT" \
  "$CODEX_WEEKLY_LEFT_PERCENT" "$CODEX_WEEKLY_RESET_AT" "$CODEX_WEEKLY_MIN_LEFT_PERCENT" \
  "$CODEX_LIMIT_NOTE" <<'PY'
import sys
from datetime import datetime, timedelta

(
    source,
    observed_at,
    stale_after_minutes,
    five_left,
    five_reset,
    five_min,
    weekly_left,
    weekly_reset,
    weekly_min,
    note,
) = sys.argv[1:]

def parse_float(value):
    try:
        return float(value)
    except Exception:
        return None

def parse_dt(value):
    value = (value or "").strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            pass
    try:
        return datetime.fromisoformat(value)
    except Exception:
        return None

stale = True
state = "WARN"
status_note = note or "Codex limit snapshot captured from manual/status source."

observed = parse_dt(observed_at)
try:
    stale_after = int(float(stale_after_minutes))
except Exception:
    stale_after = 90

if observed:
    stale = datetime.now() - observed > timedelta(minutes=stale_after)

five_value = parse_float(five_left)
weekly_value = parse_float(weekly_left)
five_threshold = parse_float(five_min)
weekly_threshold = parse_float(weekly_min)

if not observed:
    stale = True
    state = "WARN"
    status_note = "Codex limit snapshot has no valid observed_at; update it from Codex CLI /status."
elif stale:
    state = "WARN"
    status_note = "Codex limit snapshot is stale; update it from Codex CLI /status."
elif five_value is None or weekly_value is None:
    state = "WARN"
    status_note = "Codex limit snapshot is incomplete; update it from Codex CLI /status."
elif five_threshold is not None and five_value <= five_threshold:
    state = "STOP"
elif weekly_threshold is not None and weekly_value <= weekly_threshold:
    state = "STOP"
else:
    state = "OK"

print(f"source={source}")
print(f"observed_at={observed_at}")
print(f"stale={'yes' if stale else 'no'}")
print(f"five_hour_left_percent={five_left}")
print(f"five_hour_reset_at={five_reset}")
print(f"weekly_left_percent={weekly_left}")
print(f"weekly_reset_at={weekly_reset}")
print(f"recommended_state={state}")
print(f"note={status_note}")
PY
