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

    ./runners/owner_review_task.sh TASK-KEY ACCEPT "Owner accepted this delivery."
    ./runners/owner_review_task.sh TASK-KEY REVISION "Owner requested changes."

## INTERNAL-006 Handover

Owner decision reporting improved.

Daily report now shows clearer recent event titles and includes accepted tasks from today in the owner decision section.

Verification:
- bash syntax check passed for `runners/generate_daily_report.sh`
- daily report regenerated from PostgreSQL data

## INTERNAL-007 Handover

Owner Inbox runner implemented.

New command:

    ./runners/owner_inbox.sh

It shows:
- waiting owner acceptance
- QA failed / needs revision / blocked
- recently accepted deliveries
- internal development status
- suggested owner commands


## INTERNAL-008 Handover

Terminal Company Dashboard implemented.

New command:

    ./runners/company_status.sh

It shows:
- task health summary
- client task status
- internal development status
- owner attention queue
- latest accepted deliveries
- latest agent events
- suggested commands

## INTERNAL-009 Handover

Web Dashboard Foundation implemented.

New app:

    apps/dashboard

Run command:

    cd /opt/ai-company/apps/dashboard
    npm start

Dashboard includes:
- CasaOS-style layout
- pixel office placeholder
- company status cards
- latest tasks
- latest events

## INTERNAL-010 Handover

Web dashboard is now managed by systemd.

Service:

    ai-company-dashboard.service

Local URL:

    http://127.0.0.1:8787

Access method:

    ssh -p 9233 -L 8787:localhost:8787 ubuntu@103.186.30.230

Useful commands:

    sudo systemctl status ai-company-dashboard --no-pager
    sudo systemctl restart ai-company-dashboard
    sudo journalctl -u ai-company-dashboard -n 80 --no-pager

## INTERNAL-011 Handover

Realtime Event Stream implemented.

Dashboard now has:

    /api/events/live

Frontend uses:

    EventSource("/api/events/live")

Latest Events updates without manual refresh.

This is the foundation for future pixel office animation.

## INTERNAL-012 Handover

Pixel Office Visualization v0 implemented.

Dashboard now includes room-based pixel office visualization.

Rooms:
- PM
- Engineer
- QA
- DevOps
- Owner
- Meeting

Realtime events update active rooms and agent sprite states.

This is the first visual layer for the future AI Company pixel office.

## INTERNAL-013 Handover

Parallel Agent Queue Foundation implemented.

New commands:

    ./runners/agent_queue.sh engineer_agent
    ./runners/claim_next_task.sh engineer_agent
    ./runners/agent_worker_once.sh engineer_agent

This is the foundation for future simultaneous multi-agent workers.

Current mode is safe one-shot execution, not autonomous 24/7 execution.

INTERNAL-014 Handover

Safe Agent Worker Loop implemented.

New command:

./runners/agent_worker_loop.sh engineer_agent --dry-run
./runners/agent_worker_loop.sh engineer_agent --once
./runners/agent_worker_loop.sh engineer_agent --loop --interval 3 --max-iterations 2

Current design is safe and bounded. No autonomous 24/7 worker service was enabled.

## INTERNAL-015 Handover

Agent Worker Safety Guard implemented.

Worker loop now has safety controls:
- dry-run is read-only and allowed anytime
- once/loop modes are guarded by work hours
- emergency stop is supported
- max iterations are bounded
- loop interval has a minimum limit
- after-hours execution requires explicit manual override

No autonomous 24/7 worker service was enabled.

## INTERNAL-016 Handover

Empty task claim handling fixed.

`claim_next_task.sh` now treats PostgreSQL `UPDATE 0` as no claimable task and no longer emits fake `task_claimed` events for empty queues.

## INTERNAL-017 Handover

Disabled-by-default agent worker service template implemented.

Systemd template:

    /etc/systemd/system/ai-company-agent-worker@.service

Environment file:

    /etc/ai-company/agent-worker.env

The service is a bounded oneshot worker and is not enabled by default.

Safety was verified by starting the service outside work hours. The worker was blocked by the safety guard.

No autonomous 24/7 agent worker was enabled.

## INTERNAL-018 Handover

Worker Service Control Runner implemented.

New command:

    ./runners/worker_service_control.sh engineer_agent status
    ./runners/worker_service_control.sh engineer_agent start
    ./runners/worker_service_control.sh engineer_agent stop
    ./runners/worker_service_control.sh engineer_agent logs
    ./runners/worker_service_control.sh engineer_agent reset-failed
    ./runners/worker_service_control.sh engineer_agent enabled
    ./runners/worker_service_control.sh engineer_agent config

This wrapper is the preferred Owner-facing way to control disabled-by-default worker services.

No autonomous 24/7 worker was enabled.

## INTERNAL-018 Handover

Worker Service Control Runner implemented.

New command:

    ./runners/worker_service_control.sh engineer_agent status
    ./runners/worker_service_control.sh engineer_agent start
    ./runners/worker_service_control.sh engineer_agent stop
    ./runners/worker_service_control.sh engineer_agent logs
    ./runners/worker_service_control.sh engineer_agent reset-failed
    ./runners/worker_service_control.sh engineer_agent enabled
    ./runners/worker_service_control.sh engineer_agent config

This wrapper is the preferred Owner-facing way to control disabled-by-default worker services.

No autonomous 24/7 worker was enabled.

## INTERNAL-019 Handover

Agent Runtime Status Tracking implemented.

New table:

    agent_runtime_status

New commands:

    ./runners/agent_runtime_status.sh
    ./runners/agent_runtime_status.sh engineer_agent
    ./runners/update_agent_runtime_status.sh engineer_agent working INTERNAL-019 engineering_desk "note"

Task claiming now updates runtime status to claimed.

This is the foundation for better dashboard and pixel office agent state display.

## INTERNAL-020 Handover

Agent Runtime Status Runner SQL fixed.

The runtime status update and per-agent display commands now work without SQL syntax errors.

Commands verified:

    ./runners/update_agent_runtime_status.sh engineer_agent working INTERNAL-020 engineering_desk "Fixing runtime status runner SQL."
    ./runners/agent_runtime_status.sh engineer_agent
    ./runners/agent_runtime_status.sh

## INTERNAL-020 Handover

Agent Runtime Status Runner SQL fixed.

The runtime status update and per-agent display commands now work without SQL syntax errors.

Commands verified:

    ./runners/update_agent_runtime_status.sh engineer_agent working INTERNAL-020 engineering_desk "Fixing runtime status runner SQL."
    ./runners/agent_runtime_status.sh engineer_agent
    ./runners/agent_runtime_status.sh

## INTERNAL-021 Handover

Agent Runtime Status is now visible on the web dashboard.

New API:

    /api/agents/runtime

Dashboard now displays each agent runtime status, current task, and status note.

This prepares the pixel office to use runtime status instead of only event history.

## INTERNAL-022 Handover

Dashboard runtime status API route fixed.

The endpoint now works:

    /api/agents/runtime

This fixes the incomplete INTERNAL-021 dashboard runtime status integration.

## INTERNAL-023 Handover

Pixel Office is now connected to Agent Runtime Status.

The dashboard polls:

    /api/agents/runtime

Pixel rooms and sprites now respond to current runtime status, including working, claimed, queued, safety_blocked, done, and idle states.

This makes the pixel office more accurate than event-history-only visualization.

## INTERNAL-024 Handover

Owner Command Inbox v0 implemented.

New table:

    owner_commands

New API endpoints:

    GET /api/owner/commands
    POST /api/owner/commands

Dashboard now has a chatbox-style input where the Owner can submit project requirements and instructions.

This is the first step toward creating client projects from the local web interface.

## INTERNAL-025 Handover

Owner Command to Client Project conversion v0 implemented.

New runner:

    runners/convert_owner_command_to_project.sh

Updated runner:

    runners/create_task.sh

Usage:

    ./runners/convert_owner_command_to_project.sh <owner_command_id> <project_key> <project_title>

This enables the flow:

    Dashboard chatbox
    owner_commands
    client project
    PM intake task
    agent worker claim

Client project workspaces are now created under:

    projects/clients/<project_key>

## INTERNAL-026 Handover

File Upload Intake v0 implemented.

New table:

    project_uploads

New API endpoints:

    GET /api/uploads?project_key=<project_key>
    POST /api/uploads

Dashboard now supports uploading files to a client project workspace.

Uploaded files are stored under:

    projects/clients/<project_key>/uploads/

This enables the Owner to attach requirement files, logos, PDFs, screenshots, and other client assets to a project.

## INTERNAL-027 Handover

Upload attachment to PM context implemented.

New runner:

    runners/attach_uploads_to_pm_context.sh

Usage:

    ./runners/attach_uploads_to_pm_context.sh <project_key> <task_key>

This connects uploaded client files to PM intake task context.

Current flow:

    Dashboard chatbox
    Owner command
    Client project
    PM intake task
    File upload
    Upload context attached to PM task

## INTERNAL-028 Handover

Convert Command to Project is now available from the dashboard.

New API endpoint:

    POST /api/owner/commands/convert

Dashboard panel:

    Convert Command to Project

The dashboard can now call:

    runners/convert_owner_command_to_project.sh

This reduces terminal dependency for creating client projects from Owner Command Inbox entries.

## INTERNAL-029 Handover

Attach Uploads to PM Context is now available from the dashboard.

New API endpoint:

    POST /api/uploads/attach-context

Dashboard panel:

    Attach Uploads to PM Context

The dashboard can now call:

    runners/attach_uploads_to_pm_context.sh

The runner now replaces the existing task attachment section instead of duplicating it.

## INTERNAL-030 Handover

PM Intake Processor v0 implemented.

New runner:

    runners/pm_intake_processor.sh

Usage:

    ./runners/pm_intake_processor.sh <project_key> <task_key>

This runner creates a PM intake analysis document from:

- PM intake task file
- task metadata
- uploaded file metadata
- project context

This is the first step toward PM agent automatically turning owner/client requirements into implementation plans and task breakdowns.

## INTERNAL-031 Handover

Engineer and QA task generation from PM analysis implemented.

New runner:

    runners/generate_tasks_from_pm_analysis.sh

Usage:

    ./runners/generate_tasks_from_pm_analysis.sh <project_key> <source_pm_task_key>

This runner creates initial Engineer and QA tasks from PM intake analysis.

Current automation flow:

    Owner command
    Client project
    PM intake task
    Upload context
    PM intake analysis
    Engineer task
    QA task

## INTERNAL-032 Handover

Engineer Implementation Runner v0 implemented.

New runner:

    runners/engineer_implementation_runner.sh

Usage:

    ./runners/engineer_implementation_runner.sh <project_key> <engineer_task_key>

This runner creates initial implementation output from PM analysis.

Current automation flow:

    Owner command
    Client project
    PM intake task
    Upload context
    PM intake analysis
    Engineer task
    Engineer implementation output
    QA task

## INTERNAL-032 Handover

Engineer Implementation Runner v0 implemented.

New runner:

    runners/engineer_implementation_runner.sh

Usage:

    ./runners/engineer_implementation_runner.sh <project_key> <engineer_task_key>

This runner creates initial implementation output from PM analysis.

Current automation flow:

    Owner command
    Client project
    PM intake task
    Upload context
    PM intake analysis
    Engineer task
    Engineer implementation output
    QA task

## INTERNAL-033 Handover

QA Verification Runner v0 implemented.

New runner:

    runners/qa_verification_runner.sh

Usage:

    ./runners/qa_verification_runner.sh <project_key> <qa_task_key>

This runner verifies initial engineer implementation output and produces a QA report.

Current automation flow:

    Owner command
    Client project
    PM intake task
    Upload context
    PM intake analysis
    Engineer task
    Engineer implementation output
    QA task
    QA report

## INTERNAL-034 Handover

Submit QA-Passed Project to Owner Review implemented.

New runner:

    runners/submit_project_to_owner_review.sh

Usage:

    ./runners/submit_project_to_owner_review.sh <project_key> <qa_task_key>

This runner submits QA-passed client project output to Owner review queue.

Current automation flow:

    Owner command
    Client project
    PM intake task
    Upload context
    PM intake analysis
    Engineer implementation
    QA verification
    Owner review queue

## INTERNAL-035 Handover

Owner Review Decision Runner implemented.

New runner:

    runners/owner_review_decision.sh

Usage:

    ./runners/owner_review_decision.sh <review_task_key> <ACCEPT|REVISE|REJECT> [note]

Current end-to-end flow:

    Owner command
    PM intake
    PM analysis
    Engineer implementation
    QA verification
    Owner review
    Owner decision

Demo result:

- CLIENT-1-REVIEW-001 accepted
- client-company-profile-demo accepted

## INTERNAL-036 Handover

Final Project Completion Runner implemented.

New runner:

    runners/finalize_accepted_project.sh

Usage:

    ./runners/finalize_accepted_project.sh <project_key> <review_task_key>

Current end-to-end flow:

    Owner command
    PM intake
    PM analysis
    Engineer implementation
    QA verification
    Owner review
    Owner decision
    Final project completion

Demo target:

- client-company-profile-demo finalized as COMPLETED

## INTERNAL-037 Handover

Dashboard Workflow Action Buttons implemented.

New dashboard API:

    POST /api/workflow/action

Supported actions:

- pm_analysis
- generate_tasks
- engineer_impl
- qa_verify
- submit_review
- owner_decision
- finalize

New dashboard panel:

    End-to-End Workflow Actions

This moves the main client workflow from terminal-only runners toward dashboard-controlled execution.

## INTERNAL-039 Handover

Slash Command Palette and Plus Upload implemented.

Dashboard command bar now behaves closer to CLI/Codex:

- typing `/` opens command suggestions
- clicking a suggestion fills the command
- plus button opens file upload directly
- advanced panels are no longer the primary interaction path

This improves the dashboard from admin-panel style toward an AI command center.

## INTERNAL-040 Handover

Dashboard layout restructured based on Owner wireframe.

Main dashboard layout now follows:

    Sidebar
    Header / Web Name
    Map Kantor & Aktivitas Agent
    Kesehatan Server VPS
    Chatbar / Command Bar
    Last Tasks
    Last Events
    Agent Status

This becomes the new visual foundation for AI Company OS.

## INTERNAL-041 Handover

Dashboard UX v1 implemented.

Owner feedback addressed:

- office map enlarged
- Health/Kesehatan Server VPS replaced with VPS Performance
- VPS metrics added: CPU, RAM, Storage, Uptime
- VPS Performance hide/show button added
- white scrollbars replaced with softer styled scrollbars

This improves the dashboard from static layout toward operational UX.

## INTERNAL-042 Handover

Pixel Office Visual v1 implemented.

The dashboard office map now follows Pixel Agents and MetroCity-inspired visual direction:

- top-down office map
- pixel tiled rooms
- desk/furniture shapes
- CSS pixel-agent sprites
- status bubbles
- active room glow

Future improvement:

- import actual MetroCity sprite sheets
- add walking animation frames
- add canvas-based office renderer
- add editable office layout

## INTERNAL-043 Handover

Pixel Office Simulation Stage v1 implemented.

The old CSS-grid office map has been refactored into a simulation-style office stage.

Main changes:

- rooms are absolute positioned
- hallway layer added
- room furniture added
- pixel agents positioned by data-room
- runtime status can update agent room and bubble states

Next improvement:

- import real sprite assets
- add walking animation frames
- add task-to-room animation history
- add canvas/PixiJS renderer if needed

## INTERNAL-046 Handover

JIK character pipeline and custom office map direction selected.

Decision:

- Use JIK-A-4 MetroCity character sprites for employees/agents.
- Keep office map custom-built by AI Company OS.
- Do not use LimeZu office map assets yet.

New validation runner:

    runners/validate_jik_assets.sh

Next step:

- Upload JIK character pack archive into apps/dashboard/public/assets/jik/_incoming/
- Extract and select sprites for PM, Engineer, QA, DevOps, and Owner
- Replace CSS agents with real character sprites

## INTERNAL-047 Handover

JIK Character Sprites rendered in Pixel Office.

Current sprite source:

    apps/dashboard/public/assets/jik/metrocity-characters/character-model.png

Shadow source:

    apps/dashboard/public/assets/jik/metrocity-characters/shadow.png

Agents now use static sprite frames instead of CSS block bodies.

Next improvement:

- choose better frames from contact sheet
- assign outfit/hair variants
- add idle/walk animation
- improve tilemap office layout

## INTERNAL-047 Handover

JIK Character Sprites rendered in Pixel Office.

Current sprite source:

    apps/dashboard/public/assets/jik/metrocity-characters/agent-suit.png

Shadow source:

    apps/dashboard/public/assets/jik/metrocity-characters/shadow.png

Contact sheets:

    apps/dashboard/public/assets/jik/contact-sheets/

Agents now use JIK sprite rendering instead of CSS block bodies.

Next improvement:

- choose final idle/walk frame coordinates
- add walking animation
- improve tilemap office viewport

## INTERNAL-047 Handover

JIK Character Sprites rendered in Pixel Office.

Accepted visual baseline:

- office-main-card min-height: 860px
- tilemapOffice height: 800px
- tilemap-stage width: min(100%, 1480px)

Committed final assets:

- pm.png
- engineer.png
- qa.png
- devops.png
- owner.png
- office-map-v1.png

Raw asset folders are ignored and kept local:

- apps/dashboard/public/assets/jik/_incoming/
- apps/dashboard/public/assets/jik/_processed/

Next improvement:

- choose better sprite frames
- add idle/walk animation
- clean old accumulated Pixel Office CSS overrides

## INTERNAL-050 Handover

Canvas Pixel Office renderer installed.

New file:

    apps/dashboard/public/office-canvas.js

The renderer was adapted from the uploaded standalone pixel-office.html prototype. It now runs inside the dashboard Pixel Office panel, hides the previous DOM map overlays, draws the office scene on Canvas, uses JIK agent sprites, and polls `/api/agents/runtime`.

This is the foundation for future live Pixel Office animation.

## INTERNAL-051 Handover

Canvas Pixel Office polish completed.

Updated:

    apps/dashboard/public/office-canvas.js
    apps/dashboard/public/office.css

The Canvas stage is larger and centered. Selected furniture objects can optionally render from local LimeZu sprites, while falling back safely to procedural drawing when raw LimeZu files are unavailable.

## INTERNAL-052 Handover

Autonomous agent worker services enabled.

Services:

    ai-company-agent@pm_agent.service
    ai-company-agent@engineer_agent.service
    ai-company-agent@qa_agent.service
    ai-company-agent@devops_agent.service

Important safety note:

The worker loop max iteration limit is 20. Do not set systemd ExecStart above `--max-iterations 20`.

Current autonomous mode uses bounded loops with systemd restart.

Verification:

    pm_agent automatically claimed CLIENT-2-001.

## INTERNAL-053 Handover

Autonomous execution dispatcher installed.

New runners:

    runners/autonomous_agent_dispatcher.sh
    runners/agent_autonomous_loop.sh

Systemd agent services now run the autonomous loop.

Verified flow:

    CLIENT-2-001 -> DONE
    CLIENT-2-ENG-001 -> IMPLEMENTED
    CLIENT-2-QA-001 -> QA_PASSED
    CLIENT-2-REVIEW-001 -> WAITING_OWNER_ACCEPTANCE

Important:

Owner review remains manual by design.

## INTERNAL-054 Handover

Added owner accept + finalize helper:

    runners/owner_accept_and_finalize.sh

Purpose:

    Accept owner review task and finalize accepted project in one command.

This prevents missing the `project_key` argument required by `finalize_accepted_project.sh`.

## INTERNAL-055 Handover

Added dashboard Owner Review action panel.

New file:

    apps/dashboard/public/owner-review-actions.js

Updated:

    apps/dashboard/public/index.html
    apps/dashboard/server.js
    runners/owner_accept_and_finalize.sh

The dashboard now exposes an `Accept + Finalize` button when an owner review task is waiting for acceptance.

## INTERNAL-056 Handover

Added dashboard health guard:

    runners/dashboard_health_check.sh

Use it after dashboard changes to verify syntax, service status, and core API endpoints.


INTERNAL-057 Handover

Added agent services health guard:

runners/agent_services_health_check.sh

Use it after changes to autonomous agent services or dispatch runners.

Verification passed against:

ai-company-agent@pm_agent.service
ai-company-agent@engineer_agent.service
ai-company-agent@qa_agent.service
ai-company-agent@devops_agent.service


## INTERNAL-057 Handover

Added agent services health guard:

    runners/agent_services_health_check.sh

Use it after changes to autonomous agent services or dispatch runners.

## INTERNAL-057 Handover

Added agent services health guard:

    runners/agent_services_health_check.sh

Use it after changes to autonomous agent services or dispatch runners.

## INTERNAL-058 Handover

Added unified system health guard:

    runners/system_health_check.sh

Use it as the top-level smoke test after dashboard, agent service, queue, or workflow runner changes.

## INTERNAL-059 Handover

Added owner health shortcut:

    ./runners/health.sh

This is the short command for the unified system health check.

## INTERNAL-060 Handover

Added pre-commit safety runner:

    ./runners/pre_commit_check.sh

Run it before commits to verify system health, runner shell syntax, git status visibility, and raw asset staging safety.

## INTERNAL-061 Handover

Added autonomy operating policy:

    projects/internal/ai-company-os/AUTONOMY_OPERATING_POLICY.md

Client project deliveries must wait for Owner approval before finalization. When no client work is active, agents may improve internal infrastructure and the virtual office within safety boundaries.

## INTERNAL-062 Handover

Codex CLI is the approved model access path for autonomous agents using Owner ChatGPT subscription login.

Added:

    projects/internal/ai-company-os/CODEX_CLI_AUTONOMOUS_ACCESS_POLICY.md
    runners/codex_agent_check.sh

Run this to verify Codex access:

    ./runners/codex_agent_check.sh

## INTERNAL-063 Handover

Added 3-day and weekly meeting report generators.

Commands:

    ./runners/generate_3day_report.sh
    ./runners/generate_weekly_report.sh

Output paths:

    company/reports/3day/YYYY-MM-DD-3day-report.md
    company/reports/weekly/YYYY-MM-DD-weekly-report.md

## INTERNAL-064 Handover

Added idle internal improvement planner.

Command:

    ./runners/idle_internal_improvement_planner.sh --dry-run
    ./runners/idle_internal_improvement_planner.sh --once

Behavior:

- skips when Owner attention is required
- skips when active client work exists
- creates one predefined safe internal improvement task when idle

## INTERNAL-065 Handover

Added stale internal task recovery guard.

Command:

    ./runners/stale_internal_task_recovery_guard.sh 8

Output:

    company/reports/ops/YYYY-MM-DD-stale-internal-tasks.md

Safety:

- report-only
- no automatic task mutation
- recommends manual review/resume/split/close/reassign

## INTERNAL-066 Handover

Added Codex CLI usage ledger and internal budget guard.

Commands:

    ./runners/codex_agent_run.sh AGENT_KEY TASK_KEY MODE "prompt..."
    ./runners/codex_usage_report.sh

Tracked config:

    company/config/codex_budget.env

Runtime ledger:

    company/runtime/codex_usage.jsonl

Report:

    company/reports/ops/YYYY-MM-DD-codex-usage.md

Safety:

- agents should use codex_agent_run.sh, not raw codex exec
- Codex credentials must never be logged or committed
- budget limits are internal estimates, not official OpenAI remaining quota

## INTERNAL-067 Handover

Connected autonomous task context to Codex wrapper.

Commands:

    ./runners/codex_task_brief.sh AGENT_KEY TASK_KEY
    ./runners/codex_task_plan.sh AGENT_KEY TASK_KEY

Flow:

    task queue -> task brief -> codex_agent_run.sh -> usage ledger -> usage report

Verification:

- engineer_agent ran a Codex plan for INTERNAL-067
- usage report recorded 3024 tokens
- exit status was 0

Safety:

- plan/read-only mode first
- no direct raw codex exec
- no credential access
- no client finalization without Owner approval

## INTERNAL-068 Handover

Added safe autonomous Codex dispatcher hook.

Commands:

    ./runners/autonomous_codex_dispatcher_hook.sh AGENT_KEY TASK_KEY --dry-run
    AI_COMPANY_ENABLE_CODEX_DISPATCHER=1 ./runners/autonomous_codex_dispatcher_hook.sh AGENT_KEY TASK_KEY --plan

Flow:

    claimed internal task -> dispatcher eligibility check -> codex_task_plan.sh -> codex_agent_run.sh -> usage ledger -> plan report

Verification:

- engineer_agent generated a Codex dispatcher plan for INTERNAL-068
- usage report recorded 2634 tokens
- event logged: codex_plan_generated

Safety:

- internal tasks only
- assigned agent only
- skips when Owner attention exists
- skips when active client work exists
- explicit enable flag required
- plan/read-only only

## INTERNAL-069 Handover

Added Codex-enabled agent worker loop wrappers.

Commands:

    ./runners/agent_worker_once_with_codex.sh AGENT_KEY
    ./runners/agent_worker_loop_with_codex.sh AGENT_KEY --once
    ./runners/agent_worker_loop_with_codex.sh AGENT_KEY --loop --interval 5 --max-iterations 3

Enable Codex dispatcher:

    AI_COMPANY_ENABLE_CODEX_DISPATCHER=1

Verification:

- devops_agent generated a Codex dispatcher plan for INTERNAL-069
- usage report recorded 2607 tokens

Safety:

- disabled by default
- bounded loop only
- plan/read-only dispatcher path
- usage tracked through Codex ledger
- no auto-edit, no auto-commit, no client finalization

## INTERNAL-070 Handover

Enabled Codex-enabled worker loop for managed agent services via systemd drop-in.

Install command:

    ./runners/install_codex_agent_service_dropin.sh --apply

Drop-in path:

    /etc/systemd/system/ai-company-agent@.service.d/10-codex-loop.conf

Service ExecStart:

    /opt/ai-company/runners/agent_worker_loop_with_codex.sh %i --loop --interval 10 --max-iterations 1

Safety:

- Codex dispatcher is explicitly enabled in the managed service environment
- loop remains bounded
- RestartSec is set to 30 seconds
- no secrets are stored in service config

## INTERNAL-071 Handover

Added Codex usage dashboard API and UI panel.

API:

    GET /api/codex/usage

UI:

    apps/dashboard/public/codex-usage-panel.js

Safety:

- reads internal usage ledger only
- does not read Codex auth files
- exposes internal budget estimate only
- read-only panel

## INTERNAL-072 Handover

Upgraded Pixel Office dashboard renderer using production package concepts.

Files:

    apps/dashboard/public/office-canvas.js
    apps/dashboard/public/office.css
    apps/dashboard/public/index.html

Notes:

- renderer uses synthetic production-style Canvas drawing
- old map background flicker is disabled in canvas mode
- custom PNG assets can be integrated later via tile mapping

## INTERNAL-073 Handover

Polished Pixel Office map fit and labels.

Files:

    apps/dashboard/public/office-canvas.js
    apps/dashboard/public/office.css
    apps/dashboard/public/index.html

Notes:

- map is widened to 36 columns
- room labels are rendered inside canvas
- agent positions are more spread out
- canvas height is balanced to avoid covering summary cards
- cache-busted dashboard office assets to v=076

## INTERNAL-074 Handover

Prepared Pixel Office custom asset mapping foundation.

Tracked files:

    apps/dashboard/public/assets/office/config.json
    apps/dashboard/public/assets/office/tilesets/.gitkeep
    apps/dashboard/public/assets/office/characters/.gitkeep
    runners/pixel_office_asset_check.sh

Raw image assets are intentionally ignored by git:

    apps/dashboard/public/assets/office/tilesets/*.png
    apps/dashboard/public/assets/office/characters/*.png

Validation:

    ./runners/pixel_office_asset_check.sh

Next step:

    copy approved tileset/character assets to the ignored folders, then map tile IDs in config.json.

## INTERNAL-075 Handover

Connected Pixel Office renderer to optional asset config.

Config:

    apps/dashboard/public/assets/office/config.json

Renderer:

    apps/dashboard/public/office-canvas.js

Behavior:

- mode=template keeps synthetic renderer active
- mode=custom attempts to load configured tileset PNG from ignored asset folder
- missing PNG falls back safely

Validation:

    ./runners/pixel_office_asset_check.sh

## INTERNAL-076 Handover

Added controlled autonomous code development foundation.

New runners:

    runners/autonomous_code_context.sh
    runners/autonomous_code_guard.sh
    runners/autonomous_code_dev.sh

Config:

    company/config/autonomous_development.env

Usage:

    ./runners/autonomous_code_dev.sh engineer_agent TASK_KEY --dry-run
    AI_COMPANY_ENABLE_AUTO_EDIT=1 AI_COMPANY_ENABLE_AUTO_COMMIT=1 ./runners/autonomous_code_dev.sh engineer_agent TASK_KEY --run

Safety:

- edits are denied for secret/auth/token/password/.env/runtime/binary paths
- working tree must be clean before auto-edit starts
- code is committed to an autodev branch, not directly to master
- pre_commit_check must pass before auto-commit
