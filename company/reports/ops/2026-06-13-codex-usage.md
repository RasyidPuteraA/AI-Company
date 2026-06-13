# AI Company OS Codex CLI Usage Report

Generated at: 2026-06-13 07:56:40

> Internal Codex CLI budget estimate, not official OpenAI remaining quota.

## Budget Summary

| Window | Used Tokens | Internal Limit | State |
| --- | --- | --- | --- |
| Today | 1322 | soft 300000 / hard 500000 | OK |
| This Week | 1322 | 2000000 | OK |
| This Month | 1322 | 8000000 | OK |

## Usage By Agent

| Agent | Tokens Used |
| --- | --- |
| pm_agent | 1322 |

## Recent Codex Runs

| Created At | Agent | Task | Mode | Tokens | Exit | Seconds | Output |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-06-13T07:52:51 | pm_agent | INTERNAL-066 | plan | 1322 | 0 | 162 | company/runtime/codex_runs/2026-06-13/20260613075008-pm_agent-INTERNAL-066-plan.out |

## Policy

- Agents should use `./runners/codex_agent_run.sh`, not raw `codex exec`.
- Client work has priority over idle internal improvement.
- If budget state is `STOP`, non-client Codex work should pause unless Owner overrides.
- Codex credentials must never be logged, committed, pasted, or shown in dashboard.
