# INTERNAL-015: Add Agent Worker Safety Guard

## Goal

Add safety guard to agent worker loop before enabling future autonomous worker services.

## Implemented

Updated:

- `runners/agent_worker_loop.sh`

Safety behavior:

- `--dry-run` remains read-only and is allowed anytime.
- `--once` and `--loop` are blocked outside work hours by default.
- Work hours default to `08:00-19:00 Asia/Jakarta`.
- `AI_COMPANY_ALLOW_AFTER_HOURS=1` allows manual override.
- `AI_COMPANY_AGENT_EMERGENCY_STOP=1` blocks all modes.
- Loop mode requires bounded `--max-iterations`.
- Loop interval must not be lower than the configured minimum.

Environment controls:

- `AI_COMPANY_TZ`
- `AI_COMPANY_WORK_START_HOUR`
- `AI_COMPANY_WORK_END_HOUR`
- `AI_COMPANY_ALLOW_AFTER_HOURS`
- `AI_COMPANY_AGENT_EMERGENCY_STOP`
- `AI_COMPANY_MAX_WORKER_ITERATIONS`
- `AI_COMPANY_MIN_WORKER_INTERVAL`

## Verification

- `bash -n runners/agent_worker_loop.sh`
- dry-run mode tested
- emergency stop tested
- after-hours block tested
- manual override tested

## Status

Implemented.
