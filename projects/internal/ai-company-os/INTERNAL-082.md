# INTERNAL-082: Add Self-Learning Memory Layer

## Status

Implemented.

## Goal

Add an operational self-learning memory layer that converts AI Company OS experience into reusable lessons, repeated-failure patterns, scorecards, proposals, and compact context for future agents.

This is not model retraining. It does not fine-tune models, modify LLM weights, or auto-apply code/policy changes.

## Added Config

`company/config/ai_company_scheduler.env` now includes:

```bash
AI_COMPANY_LEARNING_ENABLED=1
AI_COMPANY_LEARNING_AUTO_APPLY=0
AI_COMPANY_LEARNING_CREATE_TASKS=1
AI_COMPANY_LEARNING_MAX_LESSONS_PER_RUN=10
AI_COMPANY_LEARNING_LOOKBACK_EVENTS=50
AI_COMPANY_LEARNING_MIN_PATTERN_COUNT=2
```

## Added Memory Structure

- `company/learning/lessons/`
- `company/learning/patterns/`
- `company/learning/agent-scorecards/`
- `company/learning/context/`
- `company/reports/learning/`

Generated memory files are sanitized Markdown notes. They avoid raw sensitive log dumps and do not store secrets.

## Added Runners

- `runners/learning_extract_lessons.sh`
- `runners/learning_failure_patterns.sh`
- `runners/learning_agent_scorecard.sh`
- `runners/learning_context_builder.sh`
- `runners/learning_daily_review.sh`

Each runner is bounded, readable, and safe when the database or prior learning files are unavailable.

## Behavior

- Lesson extraction reads recent events when Postgres is available and creates proposed lesson notes for failures, blocked work, budget/work-hours interruptions, verification issues, and lock-related risks.
- Failure pattern detection groups repeated lesson topics and writes pattern notes when the configured threshold is met.
- Agent scorecards summarize completed tasks, failed/error events, blocked tasks, in-progress task signals, report activity, and improvement areas.
- The context builder writes `company/learning/context/latest-learning-context.md` for future agent/Codex prompts.
- The daily review runs all learning steps and writes `company/reports/learning/YYYY-MM-DD-daily-learning-review.md`.
- Proposed internal learning tasks are written as proposal notes only. No code or policy changes are auto-applied.

## Scheduler Integration

The multi-agent scheduler runs `learning_daily_review.sh` after a successful normal work-hours cycle when learning is enabled.

Learning failures are logged as warnings and do not block the scheduler.

## Dashboard Integration

Added read-only dashboard summary API:

- `GET /api/learning/summary`

The AI Company OS panel now shows:

- learning enabled/disabled
- lesson count
- top repeated pattern
- latest learning context path

## Manual Run

```bash
./runners/learning_daily_review.sh
```

Individual runners:

```bash
./runners/learning_extract_lessons.sh
./runners/learning_failure_patterns.sh
./runners/learning_agent_scorecard.sh
./runners/learning_context_builder.sh
```

## Safety

- No secrets are read intentionally or stored.
- Event evidence is sanitized and truncated.
- No raw credential dumps are written.
- No model fine-tuning is implemented.
- `AI_COMPANY_LEARNING_AUTO_APPLY=0` by default.
- Scheduler work-hours, budget, lock, and owner-control gates remain intact.
- Learning is proposal/context/task-note based before any implementation work.

## Verification

Run:

```bash
bash -n runners/learning_extract_lessons.sh runners/learning_failure_patterns.sh runners/learning_agent_scorecard.sh runners/learning_context_builder.sh runners/learning_daily_review.sh runners/ai_company_multi_agent_scheduler.sh
./runners/learning_extract_lessons.sh
./runners/learning_failure_patterns.sh
./runners/learning_agent_scorecard.sh
./runners/learning_context_builder.sh
./runners/learning_daily_review.sh
./runners/pre_commit_check.sh
git status --short
git diff --stat
```
