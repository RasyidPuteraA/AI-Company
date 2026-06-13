# INTERNAL-067: Connect Autonomous Agents to Codex Wrapper

## Goal

Connect autonomous agent execution to `codex_agent_run.sh` so agents can use Codex CLI through the tracked usage ledger and budget guard.

## Implemented

Added:

- `runners/codex_task_brief.sh`
- `runners/codex_task_plan.sh`

## Behavior

`codex_task_brief.sh` builds a safe task prompt from the task queue.

`codex_task_plan.sh` sends that prompt through `codex_agent_run.sh` in `plan` mode.

This gives agents a safe first Codex integration path:

```text
task queue -> task brief -> Codex wrapper -> usage ledger -> usage report
```

## Verification

Verified with:

```bash
./runners/codex_task_brief.sh engineer_agent INTERNAL-067
./runners/codex_task_plan.sh engineer_agent INTERNAL-067
./runners/codex_usage_report.sh
```

Observed:

- Codex returned an implementation plan
- `engineer_agent` usage was logged
- `INTERNAL-067` usage was logged
- tokens used: `3024`
- exit status: `0`

## Safety

- Uses Codex wrapper instead of raw `codex exec`
- Starts with plan/read-only mode
- Does not automatically finalize client work
- Does not expose or inspect Codex credentials
- Keeps implementation bounded and auditable

## Known Note

Codex reported a Linux sandbox/bubblewrap warning during repository inspection. The bridge still completed successfully, and future executor work should provide bounded repository context explicitly.

## Status

Implemented.
