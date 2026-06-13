# AI Company OS Codex Usage Reconciliation

Generated at: 2026-06-14 01:58:40
Ledger: `company/runtime/codex_usage.jsonl`

> Internal AI Company Codex CLI budget estimate, not official OpenAI billing usage or remaining quota.

## Source Breakdown

| Source | Estimated Tokens |
| --- | --- |
| wrapper | 37860 |
| direct_danger_logged | 133230 |
| estimated/reconciled total | 171090 |

## Usage By Agent

| Agent | Estimated Tokens |
| --- | --- |
| engineer_agent | 167161 |
| devops_agent | 2607 |
| pm_agent | 1322 |

## Usage By Mode

| Mode | Estimated Tokens |
| --- | --- |
| direct_danger_logged | 133230 |
| plan | 32962 |
| engineering | 4898 |

## Recent Runs

| Created At | Agent | Task | Mode | Source | Estimated Tokens | Exit | Output |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-06-14T01:35:06 | engineer_agent | INTERNAL-084 | direct_danger_logged | direct_danger_logged | 133230 | 0 | company/runtime/codex_runs/2026-06-14/20260614013506-engineer_agent-INTERNAL-084-direct_danger_logged.out |
| 2026-06-13T19:12:34 | engineer_agent | INTERNAL-078 | engineering | wrapper | 4898 | 0 | company/runtime/codex_runs/2026-06-13/20260613191126-engineer_agent-INTERNAL-078-engineering.out |
| 2026-06-13T18:21:35 | engineer_agent | INTERNAL-077 | plan | wrapper | 2716 | 0 | company/runtime/codex_runs/2026-06-13/20260613182044-engineer_agent-INTERNAL-077-plan.out |
| 2026-06-13T16:45:53 | engineer_agent | INTERNAL-076 | plan | wrapper | 2676 | 0 | company/runtime/codex_runs/2026-06-13/20260613164501-engineer_agent-INTERNAL-076-plan.out |
| 2026-06-13T14:22:29 | engineer_agent | INTERNAL-075 | plan | wrapper | 2739 | 0 | company/runtime/codex_runs/2026-06-13/20260613142125-engineer_agent-INTERNAL-075-plan.out |
| 2026-06-13T14:12:39 | engineer_agent | INTERNAL-074 | plan | wrapper | 4220 | 0 | company/runtime/codex_runs/2026-06-13/20260613141139-engineer_agent-INTERNAL-074-plan.out |
| 2026-06-13T13:49:15 | engineer_agent | INTERNAL-073 | plan | wrapper | 4110 | 0 | company/runtime/codex_runs/2026-06-13/20260613134821-engineer_agent-INTERNAL-073-plan.out |
| 2026-06-13T13:21:36 | engineer_agent | INTERNAL-072 | plan | wrapper | 2642 | 0 | company/runtime/codex_runs/2026-06-13/20260613131824-engineer_agent-INTERNAL-072-plan.out |
| 2026-06-13T12:55:59 | engineer_agent | INTERNAL-071 | plan | wrapper | 4272 | 0 | company/runtime/codex_runs/2026-06-13/20260613125507-engineer_agent-INTERNAL-071-plan.out |
| 2026-06-13T08:55:33 | devops_agent | INTERNAL-069 | plan | wrapper | 2607 | 0 | company/runtime/codex_runs/2026-06-13/20260613085423-devops_agent-INTERNAL-069-plan.out |
| 2026-06-13T08:44:34 | engineer_agent | INTERNAL-068 | plan | wrapper | 2634 | 0 | company/runtime/codex_runs/2026-06-13/20260613084310-engineer_agent-INTERNAL-068-plan.out |
| 2026-06-13T08:02:45 | engineer_agent | INTERNAL-067 | plan | wrapper | 3024 | 0 | company/runtime/codex_runs/2026-06-13/20260613075911-engineer_agent-INTERNAL-067-plan.out |
| 2026-06-13T07:52:51 | pm_agent | INTERNAL-066 | plan | wrapper | 1322 | 0 | company/runtime/codex_runs/2026-06-13/20260613075008-pm_agent-INTERNAL-066-plan.out |

## Historical Limitation

- Future dangerous direct runs are tracked when launched through `./runners/codex_exec_danger_logged.sh`.
- Old raw `codex exec --dangerously-bypass-approvals-and-sandbox ...` runs that bypassed the ledger may not be exactly recoverable.
- This reconciliation avoids double counting duplicate ledger records by created time, agent, task, mode, and output path.
- Token counts are chars/4 estimates for dangerous logged runs unless the original wrapper recorded Codex CLI token output.
