# INTERNAL-071: Add Codex Usage Dashboard Panel

## Goal

Add a dashboard API and UI panel for Codex CLI usage, internal token budget, budget state, per-agent usage, and recent Codex runs.

## Implemented

Added:

- `GET /api/codex/usage`
- `apps/dashboard/public/codex-usage-panel.js`
- dashboard index script injection for Codex usage panel

## API

`GET /api/codex/usage` returns:

- generated timestamp
- internal budget note
- budget state for today, week, and month
- usage by agent
- recent Codex runs

## UI

The dashboard loads a small fixed Codex CLI Usage panel that shows:

- today usage
- weekly usage
- monthly usage
- OK/WARN/STOP state
- usage by agent

## Safety

- reads only internal usage ledger and internal budget config
- does not read Codex auth files
- does not expose secrets
- labels budget as internal estimate, not official OpenAI remaining quota
- read-only dashboard panel

## Verification

- `node --check apps/dashboard/server.js`
- `curl http://127.0.0.1:8787/api/codex/usage`
- `curl http://127.0.0.1:8787/codex-usage-panel.js`
- `./runners/dashboard_health_check.sh`
- `./runners/pre_commit_check.sh`

## Status

Implemented.
