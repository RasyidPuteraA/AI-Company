# AI Company OS Codex CLI Usage Report

Generated at: 2026-06-13 14:03:56

> Internal Codex CLI budget estimate, not official OpenAI remaining quota.

## Budget Summary

| Window | Used Tokens | Internal Limit | State |
| --- | --- | --- | --- |
| Today | 20611 | soft 300000 / hard 500000 | OK |
| This Week | 20611 | 2000000 | OK |
| This Month | 20611 | 8000000 | OK |

## Usage By Agent

| Agent | Tokens Used |
| --- | --- |
| engineer_agent | 16682 |
| devops_agent | 2607 |
| pm_agent | 1322 |

## Recent Codex Runs

| Created At | Agent | Task | Mode | Tokens | Exit | Seconds | Output |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-06-13T13:49:15 | engineer_agent | INTERNAL-073 | plan | 4110 | 0 | 54 | company/runtime/codex_runs/2026-06-13/20260613134821-engineer_agent-INTERNAL-073-plan.out |
| 2026-06-13T13:21:36 | engineer_agent | INTERNAL-072 | plan | 2642 | 0 | 192 | company/runtime/codex_runs/2026-06-13/20260613131824-engineer_agent-INTERNAL-072-plan.out |
| 2026-06-13T12:55:59 | engineer_agent | INTERNAL-071 | plan | 4272 | 0 | 52 | company/runtime/codex_runs/2026-06-13/20260613125507-engineer_agent-INTERNAL-071-plan.out |
| 2026-06-13T08:55:33 | devops_agent | INTERNAL-069 | plan | 2607 | 0 | 70 | company/runtime/codex_runs/2026-06-13/20260613085423-devops_agent-INTERNAL-069-plan.out |
| 2026-06-13T08:44:34 | engineer_agent | INTERNAL-068 | plan | 2634 | 0 | 84 | company/runtime/codex_runs/2026-06-13/20260613084310-engineer_agent-INTERNAL-068-plan.out |
| 2026-06-13T08:02:45 | engineer_agent | INTERNAL-067 | plan | 3024 | 0 | 213 | company/runtime/codex_runs/2026-06-13/20260613075911-engineer_agent-INTERNAL-067-plan.out |
| 2026-06-13T07:52:51 | pm_agent | INTERNAL-066 | plan | 1322 | 0 | 162 | company/runtime/codex_runs/2026-06-13/20260613075008-pm_agent-INTERNAL-066-plan.out |

## Policy

- Agents should use `./runners/codex_agent_run.sh`, not raw `codex exec`.
- Client work has priority over idle internal improvement.
- If budget state is `STOP`, non-client Codex work should pause unless Owner overrides.
- Codex credentials must never be logged, committed, pasted, or shown in dashboard.
