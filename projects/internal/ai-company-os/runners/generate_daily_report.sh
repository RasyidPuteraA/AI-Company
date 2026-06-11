#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GENERATOR="${PROJECT_ROOT}/scripts/generate_daily_report.py"
DEFAULT_INPUT="${PROJECT_ROOT}/examples/daily_report/sample_input.json"
INPUT_BUILDER="${PROJECT_ROOT}/scripts/build_daily_report_input.py"

if [[ "$#" -eq 0 ]]; then
  if [[ "${AI_COMPANY_OS_DAILY_REPORT_SAMPLE:-}" == "1" ]]; then
    exec python3 "${GENERATOR}" "${DEFAULT_INPUT}"
  fi

  REPORT_INPUT="$(mktemp)"
  trap 'rm -f "${REPORT_INPUT}"' EXIT
  python3 "${INPUT_BUILDER}" > "${REPORT_INPUT}"
  python3 "${GENERATOR}" "${REPORT_INPUT}"
  exit $?
fi

exec python3 "${GENERATOR}" "$@"
