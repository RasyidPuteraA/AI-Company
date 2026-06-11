#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GENERATOR="${PROJECT_ROOT}/scripts/generate_daily_report.py"
INPUT_FILE="${PROJECT_ROOT}/examples/daily_report/sample_input.json"
REPORT_DIR="${PROJECT_ROOT}/company/reports/daily"
REPORT_DATE="$(date +%F)"
REPORT_FILE="${REPORT_DIR}/${REPORT_DATE}-daily-report.md"

mkdir -p "$REPORT_DIR"

if [ ! -f "$GENERATOR" ]; then
  echo "Generator not found: $GENERATOR"
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "Input file not found: $INPUT_FILE"
  exit 1
fi

python3 "$GENERATOR" "$INPUT_FILE" -o "$REPORT_FILE"

echo "Daily report generated:"
echo "$REPORT_FILE"
