# INTERNAL-063: Add 3-Day and Weekly Meeting Reports

## Goal

Add report generators for 3-day review meetings and weekly end-of-week review meetings.

## Implemented

Added:

- `runners/generate_3day_report.sh`
- `runners/generate_weekly_report.sh`
- `company/reports/3day/`
- `company/reports/weekly/`

## Report Coverage

Each report includes executive summary, owner attention queue, active work, completed work, recent events when available, and suggested next actions.

## Verification

- `bash -n runners/generate_3day_report.sh`
- `bash -n runners/generate_weekly_report.sh`
- `./runners/generate_3day_report.sh`
- `./runners/generate_weekly_report.sh`
- `./runners/pre_commit_check.sh`

## Status

Implemented.
