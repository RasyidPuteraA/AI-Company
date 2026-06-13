# INTERNAL-081: Add Overtime-Aware Work Hours Gate

## Status

Implemented.

## Policy

- Normal work hours are 07:00 <= hour < 17:00 in Asia/Jakarta.
- Overtime is 17:00 <= hour < 19:00 when enabled.
- Outside those windows, autonomous scheduler work is paused.
- No workday or day-of-week filter is applied.

## Runtime Signals

`runners/ai_company_work_hours_gate.sh` emits:

- `WORK_HOURS_TIMEZONE`
- `WORK_HOURS_CURRENT_HOUR`
- `WORK_HOURS_START`
- `WORK_HOURS_END`
- `WORK_HOURS_OVERTIME_END`
- `WORK_HOURS_STATE`
- `WORK_HOURS_MODE`
- `WORK_HOURS_REASON`

`WORK_HOURS_MODE` is one of:

- `NORMAL_WORK`
- `OVERTIME`
- `PAUSED`
- `OVERRIDE`

## Overtime Defaults

During overtime, scheduler role cycles avoid starting broad new autonomous discovery and new internal improvement work by default. Existing `IN_PROGRESS` work may continue when the role runner can find it. QA and reporting/status checks remain enabled by default.

Config defaults:

- `AI_COMPANY_TIMEZONE=Asia/Jakarta`
- `AI_COMPANY_WORK_START_HOUR=07`
- `AI_COMPANY_WORK_END_HOUR=17`
- `AI_COMPANY_OVERTIME_ENABLED=1`
- `AI_COMPANY_OVERTIME_END_HOUR=19`
- `AI_COMPANY_OVERTIME_ALLOW_NEW_DISCOVERY=0`
- `AI_COMPANY_OVERTIME_ALLOW_INTERNAL_IMPROVEMENT=0`
- `AI_COMPANY_OVERTIME_ALLOW_QA=1`
- `AI_COMPANY_OVERTIME_ALLOW_REPORTING=1`

## Verification

Run:

```bash
bash -n runners/ai_company_work_hours_gate.sh runners/ai_company_multi_agent_scheduler.sh runners/ai_company_role_cycle.sh runners/ai_company_scheduler_status.sh runners/ai_company_os_status.sh
./runners/ai_company_work_hours_gate.sh
./runners/ai_company_scheduler_status.sh
./runners/ai_company_os_status.sh
./runners/pre_commit_check.sh
```
