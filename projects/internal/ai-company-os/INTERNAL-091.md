# INTERNAL-091: Stabilize Dashboard Health Timeout

## Problem

Scheduler and pre-commit cycles could fail when dashboard health hit a transient `/api/summary` curl timeout and reported HTTP `000`. Agent services and git state could be healthy, but the dashboard smoke test had only one `/api/summary` attempt.

## Root Cause

`apps/dashboard/server.js` ran dashboard SQL through `docker exec ... psql` without an explicit subprocess timeout. A slow or blocked DB exec could hold the Node request long enough for the health check curl limit to fire. The health script retried `/api/tasks`, but `/api/summary` was a single hard failure.

## Changes

- Added a bounded dashboard DB exec timeout in `apps/dashboard/server.js`.
- Sanitized DB helper failures so requests do not expose command output, SQL text, or secrets.
- Made `/api/summary` return controlled JSON with `generated_at`, `error`, `error_code`, and `error_note` on DB timeout/failure.
- Added four `/api/summary` health-check attempts with short sleeps in `runners/dashboard_health_check.sh`.
- Kept persistent `/api/summary` failures as real dashboard health failures after all retries.

## Changed Files

- `apps/dashboard/server.js`
- `runners/dashboard_health_check.sh`
- `projects/internal/ai-company-os/INTERNAL-091.md`
- `projects/internal/ai-company-os/AGENT_HANDOVER.md`

## Verification

```bash
node --check apps/dashboard/server.js
bash -n runners/dashboard_health_check.sh
./runners/dashboard_health_check.sh
./runners/pre_commit_check.sh
git status --short
git diff --stat
```

## Expected Behavior

Transient `/api/summary` HTTP `000` results are retried before failing scheduler or pre-commit verification. If the dashboard DB path is persistently unhealthy, `/api/summary` returns a fast, sanitized JSON `503`, and dashboard health fails only after all retry attempts.
