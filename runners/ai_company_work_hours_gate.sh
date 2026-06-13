#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/ai_company_os.env"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

: "${AI_COMPANY_TIMEZONE:=Asia/Jakarta}"
: "${AI_COMPANY_WORK_START_HOUR:=07}"
: "${AI_COMPANY_WORK_END_HOUR:=17}"
: "${AI_COMPANY_OVERTIME_ENABLED:=1}"
: "${AI_COMPANY_OVERTIME_END_HOUR:=19}"

hour_to_num() {
  local value="$1"
  if ! [[ "$value" =~ ^[0-9]{1,2}$ ]]; then
    echo "Invalid hour value: $value" >&2
    exit 2
  fi
  local num=$((10#$value))
  if [ "$num" -lt 0 ] || [ "$num" -gt 23 ]; then
    echo "Hour out of range: $value" >&2
    exit 2
  fi
  printf "%s\n" "$num"
}

if [ "${AI_COMPANY_ALLOW_AFTER_HOURS:-0}" = "1" ]; then
  echo "WORK_HOURS_TIMEZONE=$AI_COMPANY_TIMEZONE"
  echo "WORK_HOURS_CURRENT_HOUR=$(TZ="$AI_COMPANY_TIMEZONE" date +%H)"
  echo "WORK_HOURS_START=$AI_COMPANY_WORK_START_HOUR"
  echo "WORK_HOURS_END=$AI_COMPANY_WORK_END_HOUR"
  echo "WORK_HOURS_OVERTIME_END=$AI_COMPANY_OVERTIME_END_HOUR"
  echo "WORK_HOURS_STATE=OK"
  echo "WORK_HOURS_MODE=OVERRIDE"
  echo "WORK_HOURS_REASON=override"
  exit 0
fi

hour="$(TZ="$AI_COMPANY_TIMEZONE" date +%H)"
hour_num="$(hour_to_num "$hour")"
start_num="$(hour_to_num "$AI_COMPANY_WORK_START_HOUR")"
end_num="$(hour_to_num "$AI_COMPANY_WORK_END_HOUR")"
overtime_end_num="$(hour_to_num "$AI_COMPANY_OVERTIME_END_HOUR")"

echo "WORK_HOURS_TIMEZONE=$AI_COMPANY_TIMEZONE"
echo "WORK_HOURS_CURRENT_HOUR=$hour"
echo "WORK_HOURS_START=$AI_COMPANY_WORK_START_HOUR"
echo "WORK_HOURS_END=$AI_COMPANY_WORK_END_HOUR"
echo "WORK_HOURS_OVERTIME_END=$AI_COMPANY_OVERTIME_END_HOUR"

if [ "$hour_num" -ge "$start_num" ] && [ "$hour_num" -lt "$end_num" ]; then
  echo "WORK_HOURS_STATE=OK"
  echo "WORK_HOURS_MODE=NORMAL_WORK"
  echo "WORK_HOURS_REASON=inside normal work hours"
  exit 0
fi

if [ "$AI_COMPANY_OVERTIME_ENABLED" = "1" ] && [ "$hour_num" -ge "$end_num" ] && [ "$hour_num" -lt "$overtime_end_num" ]; then
  echo "WORK_HOURS_STATE=OK"
  echo "WORK_HOURS_MODE=OVERTIME"
  echo "WORK_HOURS_REASON=inside overtime window"
  exit 0
fi

echo "WORK_HOURS_STATE=PAUSED_OUTSIDE_WORK_HOURS"
echo "WORK_HOURS_MODE=PAUSED"
echo "WORK_HOURS_REASON=outside normal and overtime work hours"
exit 1
