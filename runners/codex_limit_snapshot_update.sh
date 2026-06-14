#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SNAPSHOT_DIR="company/runtime/codex_limits"
SNAPSHOT_FILE="$SNAPSHOT_DIR/latest.env"

five_hour_left_percent=""
five_hour_reset_at=""
weekly_left_percent=""
weekly_reset_at=""
note=""
source="manual_cli_status"

usage() {
  cat <<'EOF'
Usage:
  ./runners/codex_limit_snapshot_update.sh \
    --five-hour-left-percent N \
    --five-hour-reset-at "YYYY-MM-DD HH:MM" \
    --weekly-left-percent N \
    --weekly-reset-at "YYYY-MM-DD HH:MM" \
    [--note "..."] \
    [--source manual_cli_status]

Writes company/runtime/codex_limits/latest.env from Codex CLI /status values.
Do not include account email or credentials in notes.
EOF
}

shell_quote() {
  printf "%q" "$1"
}

require_percent() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "FAIL: $name must be a number from 0 to 100." >&2
    exit 64
  fi
  awk -v value="$value" 'BEGIN { exit !(value >= 0 && value <= 100) }' || {
    echo "FAIL: $name must be a number from 0 to 100." >&2
    exit 64
  }
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --five-hour-left-percent)
      five_hour_left_percent="${2:-}"
      shift 2
      ;;
    --five-hour-reset-at)
      five_hour_reset_at="${2:-}"
      shift 2
      ;;
    --weekly-left-percent)
      weekly_left_percent="${2:-}"
      shift 2
      ;;
    --weekly-reset-at)
      weekly_reset_at="${2:-}"
      shift 2
      ;;
    --note)
      note="${2:-}"
      shift 2
      ;;
    --source)
      source="${2:-}"
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

if [ -z "$five_hour_left_percent" ] || [ -z "$five_hour_reset_at" ] || [ -z "$weekly_left_percent" ] || [ -z "$weekly_reset_at" ]; then
  echo "FAIL: all 5h and weekly percent/reset values are required." >&2
  usage >&2
  exit 64
fi

require_percent "--five-hour-left-percent" "$five_hour_left_percent"
require_percent "--weekly-left-percent" "$weekly_left_percent"

case "$source" in
  manual_cli_status|owner_usage_dashboard)
    ;;
  *)
    echo "FAIL: unsupported --source '$source'. Use manual_cli_status or owner_usage_dashboard." >&2
    exit 64
    ;;
esac

mkdir -p "$SNAPSHOT_DIR"
tmp="$(mktemp "$SNAPSHOT_DIR/latest.env.tmp.XXXXXX")"
observed_at="$(date '+%Y-%m-%d %H:%M:%S')"

{
  printf 'CODEX_LIMIT_OBSERVED_AT=%s\n' "$(shell_quote "$observed_at")"
  printf 'CODEX_LIMIT_SOURCE=%s\n' "$(shell_quote "$source")"
  printf 'CODEX_5H_LEFT_PERCENT=%s\n' "$(shell_quote "$five_hour_left_percent")"
  printf 'CODEX_5H_RESET_AT=%s\n' "$(shell_quote "$five_hour_reset_at")"
  printf 'CODEX_WEEKLY_LEFT_PERCENT=%s\n' "$(shell_quote "$weekly_left_percent")"
  printf 'CODEX_WEEKLY_RESET_AT=%s\n' "$(shell_quote "$weekly_reset_at")"
  printf 'CODEX_LIMIT_NOTE=%s\n' "$(shell_quote "$note")"
} > "$tmp"

mv "$tmp" "$SNAPSHOT_FILE"

echo "Codex limit snapshot updated: $SNAPSHOT_FILE"
echo "source=$source"
echo "observed_at=$observed_at"
echo "five_hour_left_percent=$five_hour_left_percent"
echo "five_hour_reset_at=$five_hour_reset_at"
echo "weekly_left_percent=$weekly_left_percent"
echo "weekly_reset_at=$weekly_reset_at"
