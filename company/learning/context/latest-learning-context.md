# Latest Learning Context

- generated_at: 2026-06-14T12:52:03+07:00
- purpose: Compact operational memory for future AI Company OS agents and Codex prompts.
- safety: Operational self-learning only. Do not fine-tune models, expose secrets, or auto-apply risky changes.

## Top Recent Lessons

- company/learning/lessons/LESSON-20260614125202-9e61a24847.md: A shared-resource lock constrained or blocked work. (status=proposed)
- company/learning/lessons/LESSON-20260614125034-96134b7fd3.md: A shared-resource lock constrained or blocked work. (status=proposed)
- company/learning/lessons/LESSON-20260614124909-cf6726f1a6.md: A shared-resource lock constrained or blocked work. (status=proposed)
- company/learning/lessons/LESSON-20260614124741-3427d966e5.md: A shared-resource lock constrained or blocked work. (status=proposed)
- company/learning/lessons/LESSON-20260614124612-6650beabe8.md: A shared-resource lock constrained or blocked work. (status=proposed)
- company/learning/lessons/LESSON-20260614124442-0db098e594.md: A shared-resource lock constrained or blocked work. (status=proposed)
- company/learning/lessons/LESSON-20260614124314-8ef4ddc024.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614124314-4b1e2231f6.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614124314-17be5e6a65.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614124314-9854284a2d.md: An agent or runner reported an error/failure. (status=proposed)

## Repeated Failure Patterns

- company/learning/patterns/PATTERN-dashboard-health.md: Dashboard health regressions (count=10)
- company/learning/patterns/PATTERN-runner-errors.md: Runner or agent errors (count=25)

## Agent-Specific Notes

- qa_agent: failed/error events=0, blocked tasks=0, stale in-progress tasks=0
- engineer_agent: failed/error events=0, blocked tasks=0, stale in-progress tasks=6
- devops_agent: failed/error events=0, blocked tasks=0, stale in-progress tasks=0
- owner: failed/error events=0, blocked tasks=0, stale in-progress tasks=0
- pm_agent: failed/error events=0, blocked tasks=0, stale in-progress tasks=0
- budget_manager: failed/error events=0, blocked tasks=0, stale in-progress tasks=0

## Prevention Rules

- Use the existing lock runner around shared repo, dashboard, database, QA, and DevOps operations.
- Summarize the lesson and provide it in future agent context before similar work starts.

## Current Known Risks

- Repeated failure patterns exist; review pattern notes before starting similar work.
