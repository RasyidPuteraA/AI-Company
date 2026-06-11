#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GENERATOR="${PROJECT_ROOT}/scripts/generate_daily_report.py"
DEFAULT_INPUT="${PROJECT_ROOT}/examples/daily_report/sample_input.json"

if [[ "$#" -eq 0 ]]; then
  exec python3 "${GENERATOR}" "${DEFAULT_INPUT}"
fi

exec python3 "${GENERATOR}" "$@"
