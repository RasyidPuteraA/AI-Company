# INTERNAL-065: Add Stale Internal Task Recovery Guard

## Goal

Add a safe guard that detects stale internal IN_PROGRESS tasks and reports them for owner or agent follow-up.

## Implemented

Added:

- `runners/stale_internal_task_recovery_guard.sh`
- `company/reports/ops/YYYY-MM-DD-stale-internal-tasks.md`

## Behavior

The guard lists internal tasks that have stayed `IN_PROGRESS` longer than the configured age threshold.

It does not mutate task state automatically. It only reports stale work and recommends manual review, resume, split, close, or reassignment.

## Usage

```bash
./runners/stale_internal_task_recovery_guard.sh 8
```

## Verification

- `bash -n runners/stale_internal_task_recovery_guard.sh`
- `./runners/stale_internal_task_recovery_guard.sh 8`
- `./runners/pre_commit_check.sh`

## Status

Implemented.
