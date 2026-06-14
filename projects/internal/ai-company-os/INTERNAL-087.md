# INTERNAL-087: Codex CLI Limit Snapshot Alignment

## Summary

AI Company OS no longer treats the internal 500k/day token estimate as the official Codex CLI quota by default.

The internal ledger remains for audit and trend reporting, but real stop decisions now come from a fresh Codex CLI limit snapshot when available.

## Runtime Snapshot

Live snapshots are stored at:

    company/runtime/codex_limits/latest.env

`company/runtime/` is ignored, so a safe tracked template is available at:

    company/config/codex_limit_snapshot.example.env

Update the live snapshot after checking Codex CLI `/status`:

    ./runners/codex_limit_snapshot_update.sh \
      --five-hour-left-percent 8 \
      --five-hour-reset-at "2026-06-14 10:12" \
      --weekly-left-percent 84 \
      --weekly-reset-at "2026-06-18 15:13" \
      --note "Captured from Codex CLI /status"

Do not include account email, credentials, or secrets in the snapshot note.

## Gate Behavior

Default config:

    CODEX_INTERNAL_BUDGET_ENFORCEMENT=warn
    CODEX_LIMIT_SOURCE=manual_cli_status
    CODEX_LIMIT_STALE_AFTER_MINUTES=90
    CODEX_5H_MIN_LEFT_PERCENT=3
    CODEX_WEEKLY_MIN_LEFT_PERCENT=3
    CODEX_HARD_STOP_ON_REAL_LIMIT=1

Rules:

- Internal token estimates still produce OK/WARN/STOP internally.
- With `CODEX_INTERNAL_BUDGET_ENFORCEMENT=warn`, an internal STOP becomes final WARN.
- With `CODEX_INTERNAL_BUDGET_ENFORCEMENT=off`, internal budget state is ignored.
- With `CODEX_INTERNAL_BUDGET_ENFORCEMENT=stop`, internal STOP can hard-stop the system.
- A fresh real Codex snapshot below the 5h or weekly threshold returns STOP when `CODEX_HARD_STOP_ON_REAL_LIMIT=1`.
- Missing or stale snapshots return WARN, not STOP.

## Dashboard

`GET /api/codex/usage` now separates:

- internal estimated token usage
- internal budget enforcement mode
- budget gate state
- real Codex 5h percent/reset snapshot
- real Codex weekly percent/reset snapshot
- snapshot freshness

The dashboard card labels the 500k value as an internal soft estimate and does not show it as the main Codex quota.

## Status

`./runners/ai_company_os_status.sh` and `--json` include:

- `budget_state`
- `internal_budget_state`
- `real_codex_limit_state`
- `codex_5h_left_percent`
- `codex_5h_reset_at`
- `codex_weekly_left_percent`
- `codex_weekly_reset_at`

## Safety

- Internal usage ledger was preserved.
- Runtime snapshots are ignored by git.
- Account email and credentials are not stored or displayed.
- Owner override remains available through `AI_COMPANY_CODEX_ALLOW_OVER_BUDGET=1`.
