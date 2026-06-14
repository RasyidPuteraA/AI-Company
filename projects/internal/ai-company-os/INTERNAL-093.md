# INTERNAL-093: Ignore Generated-Only Changes and Move Transient Reports to Runtime

## Root Cause

Generated learning, stale recovery, post-update, discovery, and runtime artifacts could be treated as meaningful repository changes. After a generated-only commit or a scheduler cycle that wrote tracked reports, post-update and discovery routines could see the new files as work, generate more reports, and keep the repo dirty.

## Generated-Only Classification

Shared classifier:

    runners/ai_company_generated_path_classifier.sh

Generated/report-only paths:

- `company/learning/**`
- `company/reports/learning/**`
- `company/reports/stale-task-recovery/**`
- `company/reports/post-update/**`
- `company/reports/autonomous-discovery/**`
- `company/runtime/**`

Source/config/docs paths remain non-generated, including:

- `runners/**`
- `apps/dashboard/**`
- `projects/internal/**`
- `company/config/**`
- package/config/script files

Autonomous issue discovery uses this classifier to avoid creating a high-priority dirty-worktree task for generated-only changes. Autonomous code guard also uses it so generated-only dirt is warning/report-only, while real source/config/dashboard/runner/doc dirt remains guarded.

## Runtime Report Behavior

Scheduler routine artifacts now write to ignored runtime directories:

- Post-update service plans: `company/runtime/post-update/`
- Post-update restart and health recovery reports when scheduler-driven: `company/runtime/post-update/`
- Stale task recovery plans when scheduler-driven: `company/runtime/stale-task-recovery/`
- Learning skip notes: `company/runtime/learning/`

Manual/default report commands keep their tracked report output unless called with `--runtime`.

Learning daily review is strict per local date. If today’s tracked learning review already exists, the runner exits without rewriting tracked learning files and writes only a runtime skip note.

## Generated-Only HEAD Skip

`ai_company_cadence_gate.sh git-head-changed` compares the previous processed HEAD with the current HEAD. If the diff contains only generated/report/runtime paths, it records the current HEAD as processed and skips post-update routines. This prevents generated-only commits from causing another post-update report cycle.

## Verification Commands

    bash -n runners/ai_company_generated_path_classifier.sh runners/ai_company_cadence_gate.sh runners/ai_company_multi_agent_scheduler.sh runners/post_update_service_plan.sh runners/post_update_health_recovery.sh runners/post_update_service_restart.sh runners/stale_task_recovery_plan.sh runners/learning_daily_review.sh runners/autonomous_issue_discovery.sh runners/autonomous_code_guard.sh
    ./runners/dashboard_health_check.sh
    ./runners/pre_commit_check.sh
    git status --short
    git diff --stat

## Expected Clean Git Behavior

After a clean code commit, routine scheduler cycles may update files under `company/runtime/**`, but those paths are ignored. They should not create tracked post-update, stale recovery, or repeated learning report changes. Generated-only tracked changes, if committed manually, are acknowledged as processed HEADs and should not trigger another post-update report cycle.
