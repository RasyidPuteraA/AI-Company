# INTERNAL-066: Add Codex CLI Usage Ledger and Budget Guard

## Goal

Add a safe Codex CLI usage ledger and internal budget guard so autonomous agents can track token usage before deeper Codex integration.

## Implemented

Added:

- `company/config/codex_budget.env`
- `runners/codex_agent_run.sh`
- `runners/codex_usage_report.sh`
- `company/reports/ops/YYYY-MM-DD-codex-usage.md`

## Verification

Verified Codex CLI wrapper with:

```bash
./runners/codex_agent_run.sh pm_agent INTERNAL-066 plan "Reply exactly: CODEX_LEDGER_OK"
./runners/codex_usage_report.sh
```

Observed:

- Codex returned `CODEX_LEDGER_OK`
- tokens used: `1322`
- exit status: `0`
- usage report generated
- budget state: `OK`

## Safety

- Runtime ledger is stored under `company/runtime/`
- `company/runtime/` is ignored by git
- tracked reports only contain usage metadata, not Codex credentials
- budget limits are internal estimates, not official OpenAI remaining quota

## Status

Implemented.
