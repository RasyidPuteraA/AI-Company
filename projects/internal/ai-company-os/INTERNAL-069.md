# INTERNAL-069: Wire Autonomous Codex Hook Into Agent Loop

## Goal

Wire the safe autonomous Codex dispatcher hook into the agent loop so eligible internal tasks can automatically receive Codex planning through the tracked wrapper.

## Implemented

Added:

- `runners/agent_worker_once_with_codex.sh`
- `runners/agent_worker_loop_with_codex.sh`

## Behavior

`agent_worker_once_with_codex.sh` runs the existing safe worker once, detects the claimed task key, and optionally runs the Codex dispatcher hook.

`agent_worker_loop_with_codex.sh` provides bounded once and loop modes around the Codex-enabled once runner.

Codex planning is opt-in and only runs when:

```bash
AI_COMPANY_ENABLE_CODEX_DISPATCHER=1
```

## Verified Flow

```text
agent loop -> task claim -> post-claim Codex hook -> dispatcher eligibility check -> codex_task_plan.sh -> codex_agent_run.sh -> usage ledger -> report
```

## Verification

- `bash -n runners/agent_worker_once_with_codex.sh`
- `bash -n runners/agent_worker_loop_with_codex.sh`
- `AI_COMPANY_ALLOW_AFTER_HOURS=1 AI_COMPANY_ENABLE_CODEX_DISPATCHER=1 ./runners/agent_worker_loop_with_codex.sh devops_agent --once`
- `AI_COMPANY_ENABLE_CODEX_DISPATCHER=1 ./runners/autonomous_codex_dispatcher_hook.sh devops_agent INTERNAL-069 --plan`
- `./runners/codex_usage_report.sh`
- `./runners/pre_commit_check.sh`

Observed:

- Codex dispatcher plan generated for `INTERNAL-069`
- tokens used: `2607`
- exit status: `0`
- event logged: `codex_plan_generated`

## Safety

- existing worker loop remains available
- Codex dispatcher is disabled by default
- bounded loop mode only
- uses `autonomous_codex_dispatcher_hook.sh` eligibility gates
- uses `codex_agent_run.sh` usage ledger and budget guard
- no auto-edit
- no auto-commit
- no client finalization

## Status

Implemented.
