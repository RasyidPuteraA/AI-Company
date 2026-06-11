# AGENT_HANDOVER

## Latest Task

- `INTERNAL-004`: Connect Daily Report Generator to PostgreSQL
- Date: 2026-06-11
- Scope: Local reporting script and tests inside `/opt/ai-company/projects/internal/ai-company-os`

## Implementation Notes

- Added `scripts/build_daily_report_input.py` to build the JSON input expected by `scripts/generate_daily_report.py` from PostgreSQL `tasks` and `events` rows.
- The PostgreSQL bridge uses the local `psql` command and performs read-only `select * ... limit 100` queries.
- Default tables are `public.tasks` and `public.events`.
- Optional environment overrides:
  - `AI_COMPANY_OS_PSQL`: alternate `psql` executable
  - `AI_COMPANY_OS_TASKS_TABLE`: alternate tasks table name
  - `AI_COMPANY_OS_EVENTS_TABLE`: alternate events table name
- The builder maps common task columns into report fields:
  - title/name/summary/description -> title
  - owner/assignee/assigned_to/responsible -> owner
  - status/state/workflow_state -> status
  - due/due_date/deadline/target_date -> due
  - blocker/blocked_by/blocking_issue -> blocker
- The builder classifies rows as client tasks when scope/category/type/project/client contains `client`; otherwise tasks are treated as internal.
- The builder maps common event columns into report fields:
  - summary/title/name/message/description -> summary
  - date/event_date/created_at/occurred_at/time -> date
  - impact/severity/result/outcome -> impact
- `runners/generate_daily_report.sh`:
  - now builds a temporary JSON file from PostgreSQL when invoked with no arguments
  - passes that generated JSON into `scripts/generate_daily_report.py`
  - still passes explicit arguments through to the Python generator for custom input/output usage
  - supports `AI_COMPANY_OS_DAILY_REPORT_SAMPLE=1` for local sample-mode smoke checks
- The `psql` subprocess disables password file/service file usage and removes `PGPASSWORD` from the subprocess environment to avoid accessing secrets. If PostgreSQL requires a password secret, the runner fails instead of reading it.
- Added test coverage for row mapping and runner integration using a fake local `psql`; tests do not touch a real database.
- Did not access secrets.
- Did not use `sudo`.
- Did not deploy anything.
- Did not modify files outside the current project folder.
- Did not modify `/opt/ai-company/docker-compose.yml`, `/opt/ai-company/company`, `/etc`, SSH, firewall, Docker daemon, PostgreSQL, Redis, or system files.

## Build/Test/Check Result

- Command: `python3 -m unittest discover -s tests`
- Result: Pass. 7 tests passed.
- Command: `python3 -m py_compile scripts/generate_daily_report.py scripts/build_daily_report_input.py tests/test_generate_daily_report.py`
- Result: Pass. Python syntax compile check completed successfully.
- Command: `AI_COMPANY_OS_DAILY_REPORT_SAMPLE=1 runners/generate_daily_report.sh >/tmp/ai-company-os-daily-report-smoke.md`
- Result: Pass. Sample Markdown report generated successfully with the required five sections.

## Files Created

- `scripts/build_daily_report_input.py`

## Files Updated

- `runners/generate_daily_report.sh`
- `tests/test_generate_daily_report.py`
- `AGENT_HANDOVER.md`

## Prior Task Context

- `INTERNAL-003`: Added `runners/generate_daily_report.sh`, the main daily report command wrapper, and integrated the improved Python generator into it.
- `INTERNAL-002`: Added `scripts/generate_daily_report.py`, sample input, and tests for the clean five-section daily report format.
- `INTERNAL-001`: Created `INTERNAL_DEVELOPMENT_ROADMAP.md` with improvement priorities for reporting, security, dashboard, backup, and automation.

## INTERNAL-005 Handover

Owner approval workflow implemented.

Client task QA PASS now routes to `WAITING_OWNER_ACCEPTANCE`.
Internal task QA PASS still routes to `DONE`.

New owner review command:

```bash
./runners/owner_review_task.sh TASK-KEY ACCEPT "Owner accepted this delivery."
./runners/owner_review_task.sh TASK-KEY REVISION "Owner requested changes."


