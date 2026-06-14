# INTERNAL-094: Overtime Skip and Bounded Agent Service Health Stabilization

## Root Cause

Scheduler overtime policy can intentionally skip categories such as new autonomous discovery while still allowing QA and reporting. Those expected `skipped_overtime` role states are neutral outcomes, but scheduler health was not explicit about that classification.

Agent services now run as bounded systemd loops with `--max-iterations 1`. After a successful bounded iteration, systemd can report:

- `ActiveState=inactive`
- `SubState=dead`
- `Result=success`
- `ExecMainStatus=0`

That state is a successful bounded completion, not a crashed worker.

QA pre-commit and DevOps dashboard health can also run in the same scheduler cycle. Both hit `/api/summary`, so a transient dashboard timeout in one caller could fail while a later direct check passed.

## Changes

- Scheduler role aggregation treats a `skipped_overtime` role state as a neutral expected skip if a role process exits nonzero after recording that state.
- `runners/agent_services_health_check.sh` now treats inactive/dead/success/0 agent services with bounded `--max-iterations` ExecStart configuration as healthy bounded completion.
- Real failed, crashed, or nonzero service exits still fail agent service health.
- `runners/dashboard_health_check.sh` serializes itself with the existing `dashboard` lock so QA pre-commit and DevOps dashboard checks do not hammer `/api/summary` concurrently.
- Dashboard health retries remain in place; persistent `/api/summary` failures still fail.

## Expected Overtime Behavior

With overtime policy like:

    AI_COMPANY_OVERTIME_ALLOW_NEW_DISCOVERY=0
    AI_COMPANY_OVERTIME_ALLOW_INTERNAL_IMPROVEMENT=0
    AI_COMPANY_OVERTIME_ALLOW_QA=1
    AI_COMPANY_OVERTIME_ALLOW_REPORTING=1

an engineer internal cycle may record:

    ROLE_STATE='skipped_overtime'
    ROLE_EVENT='New autonomous discovery disabled during overtime'

That is expected. Scheduler should complete the cycle if all non-skipped roles pass.

## Bounded Agent Service Health Behavior

`ai-company-agent@*.service` units using bounded `--max-iterations` loops are healthy when they finish successfully and systemd reports inactive/dead with success result and exit status `0`.

The health output says `healthy bounded completion` for this case. Nonzero exit status, failed result, crash indicators, or unbounded inactive services remain failures.

## Verification Commands

```bash
bash -n runners/ai_company_multi_agent_scheduler.sh runners/agent_services_health_check.sh runners/dashboard_health_check.sh runners/pre_commit_check.sh runners/system_health_check.sh runners/ai_company_lock.sh
./runners/dashboard_health_check.sh
./runners/agent_services_health_check.sh
./runners/pre_commit_check.sh
git status --short
git diff --stat
```
