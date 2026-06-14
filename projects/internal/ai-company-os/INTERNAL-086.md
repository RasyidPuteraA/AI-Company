# INTERNAL-086: Stale Task Recovery and Autonomous Queue Cleanup

## Status

Implemented.

## Summary

Added safe stale task recovery for old `IN_PROGRESS` work without deleting tasks or auto-completing work. The default behavior is report-only.

## New Runners

```bash
./runners/stale_task_recovery_plan.sh
./runners/stale_task_recovery_apply.sh --dry-run
./runners/agent_runtime_stale_cleanup.sh --dry-run
```

Reports are written to:

```text
company/reports/stale-task-recovery/
```

## Safety Model

- Stale task planning is enabled by default, but report-only.
- Client tasks are never status-mutated by stale recovery.
- Stale tasks are never marked `DONE` automatically.
- Tasks are never deleted.
- Safe internal and `AUTO-*` apply modes require explicit command flags and config opt-in.
- Safe apply moves stale internal/autonomous `IN_PROGRESS` tasks to `BLOCKED` with a handover recovery note only when no active runtime row or active lock holder is present.

## Config

Defaults live in `company/config/ai_company_scheduler.env`:

```bash
AI_COMPANY_STALE_TASK_RECOVERY_ENABLED=1
AI_COMPANY_STALE_TASK_AGE_HOURS=24
AI_COMPANY_STALE_TASK_AUTO_APPLY_INTERNAL=0
AI_COMPANY_STALE_TASK_AUTO_APPLY_AUTO=0
AI_COMPANY_STALE_TASK_CLIENT_REPORT_ONLY=1
```

## Scheduler

The multi-agent scheduler runs stale recovery planning after a successful cycle. Apply modes remain disabled unless the explicit auto-apply config values are set to `1`.

## Dashboard

Dashboard API:

```text
GET /api/stale-task-recovery/summary
```

The AI Company OS panel shows stale task totals and the latest stale recovery report path.
