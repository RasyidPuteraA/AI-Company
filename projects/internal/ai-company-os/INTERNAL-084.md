# INTERNAL-084: Stabilize Codex Token Panel Rendering and Usage Totals

## Status

Implemented.

## Problem

The dashboard Codex token card could briefly reset to the old summary-card placeholder during realtime polling. That made the card appear to blink and could show `0 / 500,000` even when week, month, or wrapper totals were nonzero.

## Stable Usage Mapping

`GET /api/codex/usage` now exposes stable top-level display fields:

- `limit_tokens`
- `week_total_tokens`
- `month_total_tokens`
- `wrapper_total_tokens`
- `danger_logged_total_tokens`
- `total_estimated_tokens`
- `status`
- `last_updated`
- `note`
- `is_estimate`

The dashboard main Codex token number uses the best nonzero available total in this order:

1. `total_estimated_tokens`
2. `month_total_tokens`
3. `week_total_tokens`
4. `wrapper_total_tokens + danger_logged_total_tokens`
5. `0` only when all values are zero

`total_estimated_tokens` is the internal ledger total from wrapper-tracked runs plus logged dangerous direct runs. It is not official OpenAI billing usage or official remaining quota.

## Rendering Fix

The summary strip now mounts once and updates existing summary-card value nodes in place. It no longer recreates the Codex card every 5 seconds.

The Codex panel now:

- refreshes every 30 seconds
- avoids duplicate polling intervals
- skips overlapping fetches
- preserves last known good data while a fetch is pending
- keeps old values visible if a fetch fails and marks the card `STALE`
- updates text nodes in place instead of remounting the whole card
- keeps wrapper usage and danger-logged usage visibly separate
- keeps the internal-estimate note visible

## Safety Notes

- `runners/codex_usage_report.sh` remains in place.
- `runners/codex_exec_danger_logged.sh` remains in place.
- Dangerous logged usage can remain zero until a logged dangerous wrapper run exists.
- Historical raw direct Codex exec usage may not be exactly recoverable.
- No secrets are exposed.
- The dashboard still labels Codex usage as internal estimates, not official OpenAI remaining quota.

## Verification

Run:

```bash
node --check apps/dashboard/server.js
bash -n runners/codex_usage_report.sh runners/codex_usage_reconcile.sh
./runners/dashboard_health_check.sh
./runners/codex_usage_report.sh
./runners/codex_usage_reconcile.sh
./runners/pre_commit_check.sh
git status --short
git diff --stat
```
