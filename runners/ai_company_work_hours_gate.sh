#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="company/config/ai_company_os.env"

if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG"
fi

: "${AI_COMPANY_WORK_START_HOUR:=09}"
: "${AI_COMPANY_WORK_END_HOUR:=23}"
: "${AI_COMPANY_TIMEZONE:=Asia/Jakarta}"

if [ "${AI_COMPANY_ALLOW_AFTER_HOURS:-0}" = "1" ]; then
  echo "WORK_HOURS_STATE=OK"
  echo "WORK_HOURS_REASON=override"
  exit 0
fi

hour="$(TZ="$AI_COMPANY_TIMEZONE" date +%H)"
hour_num=$((10#$hour))
start_num=$((10#$AI_COMPANY_WORK_START_HOUR))
end_num=$((10#$AI_COMPANY_WORK_END_HOUR))

inside=0
if [ "$start_num" -eq "$end_num" ]; then
  inside=1
elif [ "$start_num" -lt "$end_num" ]; then
  if [ "$hour_num" -ge "$start_num" ] && [ "$hour_num" -lt "$end_num" ]; then
    inside=1
  fi
else
  if [ "$hour_num" -ge "$start_num" ] || [ "$hour_num" -lt "$end_num" ]; then
    inside=1
  fi
fi

echo "WORK_HOURS_TIMEZONE=$AI_COMPANY_TIMEZONE"
echo "WORK_HOURS_CURRENT_HOUR=$hour"
echo "WORK_HOURS_START=$AI_COMPANY_WORK_START_HOUR"
echo "WORK_HOURS_END=$AI_COMPANY_WORK_END_HOUR"

if [ "$inside" -eq 1 ]; then
  echo "WORK_HOURS_STATE=OK"
  echo "WORK_HOURS_REASON=inside configured work hours"
  exit 0
fi

echo "WORK_HOURS_STATE=PAUSED_OUTSIDE_WORK_HOURS"
echo "WORK_HOURS_REASON=outside configured work hours"
exit 1
