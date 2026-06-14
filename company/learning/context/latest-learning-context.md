# Latest Learning Context

- generated_at: 2026-06-14T11:10:49+07:00
- purpose: Compact operational memory for future AI Company OS agents and Codex prompts.
- safety: Operational self-learning only. Do not fine-tune models, expose secrets, or auto-apply risky changes.

## Top Recent Lessons

- company/learning/lessons/LESSON-20260614111048-cff68af401.md: A shared-resource lock constrained or blocked work. (status=proposed)
- company/learning/lessons/LESSON-20260614110912-3c5d8ea8b1.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614110912-0b4953c5d0.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614110912-89455831c1.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614110912-097564d42e.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614105026-59fd5fa6d3.md: A shared-resource lock constrained or blocked work. (status=proposed)
- company/learning/lessons/LESSON-20260614104849-1e4e2ac970.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614104849-91ade0fe06.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614104849-1f4cb0e935.md: An agent or runner reported an error/failure. (status=proposed)
- company/learning/lessons/LESSON-20260614104849-9a57bf8384.md: An agent or runner reported an error/failure. (status=proposed)

## Repeated Failure Patterns

- company/learning/patterns/PATTERN-dashboard-health.md: Dashboard health regressions (count=2)
- company/learning/patterns/PATTERN-runner-errors.md: Runner or agent errors (count=10)

## Agent-Specific Notes

- owner: failed/error events=0, blocked tasks=0, stale in-progress tasks=0
- pm_agent: failed/error events=3, blocked tasks=0, stale in-progress tasks=0
- qa_agent: failed/error events=0, blocked tasks=0, stale in-progress tasks=0
- engineer_agent: failed/error events=0, blocked tasks=0, stale in-progress tasks=5
- devops_agent: failed/error events=0, blocked tasks=0, stale in-progress tasks=0
- budget_manager: failed/error events=0, blocked tasks=0, stale in-progress tasks=0

## Prevention Rules

- Use the existing lock runner around shared repo, dashboard, database, QA, and DevOps operations.
- Summarize the lesson and provide it in future agent context before similar work starts.

## Current Known Risks

- Repeated failure patterns exist; review pattern notes before starting similar work.
- Some agents have failure or blocked-work signals in their scorecards.
