# INTERNAL-078: AI Company OS Master Autonomous Operations Mode

## Goal

Add a single owner-controlled AI Company OS ON/OFF runtime switch. When ON, the system may run bounded autonomous operations inside work-hours, internal budget, emergency stop, duplicate issue, and pre-commit/test guards. When OFF, autonomous operation stops.

## Implemented

Added:

- `company/config/ai_company_os.env`
- `runners/ai_company_os_control.sh`
- `runners/ai_company_os_status.sh`
- `runners/ai_company_work_hours_gate.sh`
- `runners/ai_company_budget_gate.sh`
- `runners/ai_company_autonomous_orchestrator.sh`

Updated:

- dashboard server API:
  - `GET /api/ai-company-os/status`
  - `POST /api/ai-company-os/control`
- dashboard UI with AI Company OS ON/OFF toggle and status panel
- `projects/internal/ai-company-os/AGENT_HANDOVER.md`

## Runtime State

Mutable runtime state is stored at:

```bash
company/runtime/ai-company-os/state.env
```

Default config keeps the OS off:

```bash
AI_COMPANY_OS_ENABLED=0
AI_COMPANY_AUTOSOLVE_ENABLED=1
AI_COMPANY_CLIENT_PRIORITY=1
AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED=1
AI_COMPANY_WORK_START_HOUR=09
AI_COMPANY_WORK_END_HOUR=23
AI_COMPANY_TIMEZONE=Asia/Jakarta
AI_COMPANY_MAX_AUTONOMOUS_ITERATIONS=1
AI_COMPANY_DISCOVERY_ONLY_AFTER_RESOLUTION=1
```

## Behavior

- OFF state exits safely and records `PAUSED_BY_OWNER`.
- `AI_COMPANY_AGENT_EMERGENCY_STOP=1` halts the orchestrator.
- work-hours gate pauses outside configured local hours.
- budget gate pauses when the internal Codex CLI budget estimate reaches `STOP`.
- pending client tasks/events have priority over internal improvement.
- when no client work is pending, the orchestrator uses the existing self-directed discovery loop.
- discovery creates deduplicated `AUTO-*` tasks through the existing ledger in `company/runtime/autonomous-discovery/ledger.tsv`.
- auto-solve uses the existing guarded autonomous code development runner.
- `pre_commit_check.sh` remains the verification guard after a successful autonomous cycle.

## Usage

Turn ON:

```bash
./runners/ai_company_os_control.sh on
```

Turn OFF:

```bash
./runners/ai_company_os_control.sh off
```

Check status:

```bash
./runners/ai_company_os_status.sh
./runners/ai_company_os_status.sh --json
```

Run one bounded orchestrator cycle:

```bash
./runners/ai_company_autonomous_orchestrator.sh
```

The same ON/OFF control is available from the dashboard AI Company OS panel.

## Safety Notes

- Dashboard budget labels are internal AI Company Codex CLI budget estimates, not official OpenAI quota.
- Existing owner review code remains for client compatibility.
- Internal autonomous tasks do not require owner approval when master mode is ON.
- No raw asset, secret, emergency stop, budget, work-hours, duplicate, or pre-commit guard was removed.

## Verification

Expected checks:

```bash
bash -n runners/ai_company_os_control.sh
bash -n runners/ai_company_os_status.sh
bash -n runners/ai_company_work_hours_gate.sh
bash -n runners/ai_company_budget_gate.sh
bash -n runners/ai_company_autonomous_orchestrator.sh
./runners/health.sh
./runners/pre_commit_check.sh
./runners/dashboard_health_check.sh
```

## Status

Implemented.
