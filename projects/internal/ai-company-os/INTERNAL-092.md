# INTERNAL-092: Stabilize Generated Report Cadence

## Problem

After INTERNAL-091 the scheduler was healthy, but every successful scheduler cycle could still rewrite or create tracked generated files:

- `company/learning/agent-scorecards/*.md`
- `company/learning/context/latest-learning-context.md`
- `company/learning/patterns/*.md`
- `company/learning/lessons/LESSON-*.md`
- `company/reports/learning/*.md`
- `company/reports/stale-task-recovery/latest.md`
- `company/reports/stale-task-recovery/*-stale-task-recovery-plan.md`
- `company/reports/post-update/*-service-plan.md`

That made the repository dirty after normal autonomous operation and could repeatedly surface dirty-worktree recovery tasks.

## Changes

Added reusable cadence helper:

```bash
./runners/ai_company_cadence_gate.sh daily NAME [STATE_DIR]
./runners/ai_company_cadence_gate.sh mark-daily NAME [STATE_DIR]
./runners/ai_company_cadence_gate.sh interval NAME MINUTES [STATE_DIR]
./runners/ai_company_cadence_gate.sh mark-interval NAME [STATE_DIR]
./runners/ai_company_cadence_gate.sh git-head-changed NAME [STATE_DIR]
./runners/ai_company_cadence_gate.sh mark-git-head NAME [STATE_DIR]
```

Cadence state is stored under `company/runtime`, which is already runtime-only.

Scheduler cadence rules:

- Learning daily review runs at most once per local date during `NORMAL_WORK`.
- Stale task recovery planning runs at most once every 60 minutes.
- Post-update service planning/restart runs only when `git HEAD` changed since the last successful post-update check or restart.
- Post-update HEAD state is stored under `company/runtime/post-update/service-check.head`.

Dirty worktree classification:

- `runners/autonomous_issue_discovery.sh` now classifies generated learning/recovery/post-update report paths separately.
- Generated report-only dirt becomes a low-priority report-only candidate.
- Source, runner, dashboard, config, and project-doc dirt still creates the high-priority dirty-worktree candidate.
- `runners/autonomous_code_guard.sh` now treats generated report-only dirt as warning/report-only, while source/code/config dirt remains blocking and subject to existing limits and deny patterns.

## Files Changed

- `runners/ai_company_cadence_gate.sh`
- `runners/ai_company_multi_agent_scheduler.sh`
- `runners/autonomous_issue_discovery.sh`
- `runners/autonomous_code_guard.sh`
- `projects/internal/ai-company-os/INTERNAL-092.md`
- `projects/internal/ai-company-os/AGENT_HANDOVER.md`

## Verification

Run:

```bash
bash -n runners/ai_company_cadence_gate.sh
bash -n runners/ai_company_multi_agent_scheduler.sh
bash -n runners/autonomous_issue_discovery.sh
bash -n runners/autonomous_code_guard.sh
./runners/dashboard_health_check.sh
./runners/pre_commit_check.sh
git status --short
git diff --stat
```

Do not run long autonomous scheduler loops for this verification.

## Expected Behavior

Normal scheduler cycles should stop rewriting generated learning/recovery/post-update reports every cycle. Learning and reports still run when cadence conditions are met. Dirty worktree signals still protect real source, runner, dashboard, config, and project documentation changes.
