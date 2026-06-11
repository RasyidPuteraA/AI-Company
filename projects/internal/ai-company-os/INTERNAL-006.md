# INTERNAL-006: Improve Owner Decision Reporting

## Goal

Improve the daily report so Owner/Master can quickly see what needs attention.

## Implemented

- Recent events now use readable event titles instead of `Untitled event`.
- Owner decision section now includes:
  - pending owner acceptance
  - QA failures
  - revision requests
  - blockers
  - accepted tasks from today

## Verification

- `bash -n runners/generate_daily_report.sh`
- `./runners/generate_daily_report.sh`
- daily report generated from PostgreSQL data

## Status

Implemented.
