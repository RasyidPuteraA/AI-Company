# Latest Learning Context

- generated_at: 2026-06-14T12:15:14+07:00
- purpose: Compact operational memory for future AI Company OS agents and Codex prompts.
- safety: Operational self-learning only. Do not fine-tune models, expose secrets, or auto-apply risky changes.

## Top Recent Lessons

- company/learning/lessons/LESSON-20260614121513-e93ce84126.md: A shared-resource lock constrained or blocked work. (status=proposed)
- company/learning/lessons/LESSON-20260614121342-c3eb737f6b.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614121342-ee3144a4eb.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614121342-94462ec1d3.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614121342-4d4b84fbad.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614113741-ab69946d21.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614113741-da12af4280.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614113741-433b46d7e1.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614113741-a8dcdef6c9.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614112835-b034c0eb6d.md: An agent or runner reported an error/failure. (status=proposed)

## Repeated Failure Patterns

- company/learning/patterns/PATTERN-dashboard-health.md: Dashboard health regressions (count=3)
- company/learning/patterns/PATTERN-runner-errors.md: Runner or agent errors (count=21)

## Agent-Specific Notes

- qa_agent: failed/error events=0, blocked tasks=0, stale in-progress tasks=0
- owner: failed/error events=0, blocked tasks=0, stale in-progress tasks=0
- pm_agent: failed/error events=3, blocked tasks=0, stale in-progress tasks=0
- engineer_agent: failed/error events=0, blocked tasks=0, stale in-progress tasks=5
- devops_agent: failed/error events=0, blocked tasks=0, stale in-progress tasks=0
- budget_manager: failed/error events=0, blocked tasks=0, stale in-progress tasks=0

## Prevention Rules

- Use the existing lock runner around shared repo, dashboard, database, QA, and DevOps operations.
- Summarize the lesson and provide it in future agent context before similar work starts.

## Current Known Risks

- Repeated failure patterns exist; review pattern notes before starting similar work.
- Some agents have failure or blocked-work signals in their scorecards.
