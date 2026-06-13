# INTERNAL-068: Add Autonomous Codex Dispatcher Hook

## Goal

Add a safe autonomous dispatcher hook that lets eligible internal tasks run through `codex_task_plan.sh` via the tracked Codex wrapper.

## Implemented

Added:

- `runners/autonomous_codex_dispatcher_hook.sh`
- `company/reports/ops/codex-dispatcher/YYYY-MM-DD-TASK-plan.md`

## Behavior

The hook checks whether a task is eligible for Codex planning.

Eligibility rules:

- task key must be `INTERNAL-*`
- task must be `IN_PROGRESS`
- task must be assigned to the invoking agent
- Owner attention queue must be empty
- active client work must be empty
- Codex dispatcher must be explicitly enabled with `AI_COMPANY_ENABLE_CODEX_DISPATCHER=1`

## Verified Flow

```text
claimed internal task -> dispatcher eligibility check -> codex_task_plan.sh -> codex_agent_run.sh -> usage ledger -> plan report
```

## Verification

Verified with:

```bash
./runners/autonomous_codex_dispatcher_hook.sh engineer_agent INTERNAL-068 --dry-run
AI_COMPANY_ENABLE_CODEX_DISPATCHER=1 ./runners/autonomous_codex_dispatcher_hook.sh engineer_agent INTERNAL-068 --plan
./runners/codex_usage_report.sh
```

Observed:

- Codex plan generated
- tokens used: `2634`
- exit status: `0`
- usage report updated
- event logged: `codex_plan_generated`

## Safety

- plan/read-only only
- no auto-edit
- no auto-commit
- no client finalization
- no credential access
- no direct raw `codex exec`

## Known Note

Codex reported a Linux sandbox/bubblewrap warning during repository inspection. The dispatcher hook still completed successfully. Future executor work should provide bounded repository context explicitly instead of relying on broad sandbox inspection.

## Status

Implemented.
