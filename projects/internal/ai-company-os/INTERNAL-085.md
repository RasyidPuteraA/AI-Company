# INTERNAL-085: Autonomous Post-Update Service Restart and Health Recovery

## Summary

Added a safe post-update restart layer for AI Company OS services. It detects changed files, maps them to affected systemd services, writes owner-visible reports, and can restart only those services after explicit apply and safety checks.

## Runners

- `runners/post_update_service_plan.sh`
  - detects changed files from `git diff`, staged changes, untracked files, and optional `--since-ref REF`
  - maps changes to dashboard, scheduler, or agent service restarts
  - report-only by default
  - writes reports to `company/reports/post-update/`

- `runners/post_update_service_restart.sh`
  - supports `--dry-run` and `--apply`
  - refuses mutating work unless `--apply` is present
  - runs `./runners/pre_commit_check.sh` before applying unless `--skip-precheck` is explicitly provided
  - respects owner switch, emergency stop, work-hours gate, budget STOP, and service-category config
  - restarts only mapped services with `sudo systemctl restart SERVICE`
  - runs post-update health recovery after successful restarts

- `runners/post_update_health_recovery.sh`
  - runs dashboard health check
  - runs agent services health check when available
  - runs scheduler status when available
  - writes PASS/WARN/FAIL reports and owner notes on non-PASS
  - does not attempt rollback

## Service Mapping

Dashboard changes restart:

- `ai-company-dashboard.service`

Scheduler changes restart:

- `ai-company-multi-agent-scheduler.service`

Agent worker/dispatcher changes restart:

- `ai-company-agent@pm_agent.service`
- `ai-company-agent@engineer_agent.service`
- `ai-company-agent@qa_agent.service`
- `ai-company-agent@devops_agent.service`

## Defaults

Configured in `company/config/ai_company_scheduler.env`:

```bash
AI_COMPANY_AUTO_RESTART_SERVICES=0
AI_COMPANY_AUTO_RESTART_DASHBOARD=1
AI_COMPANY_AUTO_RESTART_SCHEDULER=1
AI_COMPANY_AUTO_RESTART_AGENT_SERVICES=0
```

Global autonomous restart remains disabled by default. Dashboard and scheduler categories are eligible once global auto-restart is intentionally enabled. Agent services stay disabled by default because their loops can be more disruptive.

## Scheduler Integration

The multi-agent scheduler now runs `post_update_service_plan.sh` after a successful role cycle. This creates report-only post-update visibility without changing running services.

If `AI_COMPANY_AUTO_RESTART_SERVICES=1`, the scheduler calls `post_update_service_restart.sh --apply`. The restart runner still re-checks owner switch, emergency stop, work-hours, budget, and pre-commit safety gates before restarting anything.

## Dashboard Integration

The dashboard exposes latest post-update status at:

- `GET /api/post-update/summary`

The existing AI Company OS status panel shows the latest post-update report/status.

## Manual Commands

Preview affected services:

```bash
./runners/post_update_service_plan.sh
./runners/post_update_service_restart.sh --dry-run
```

Apply restart after safety checks:

```bash
./runners/post_update_service_restart.sh --apply
```

Check health:

```bash
./runners/post_update_health_recovery.sh
```

Compare from a specific ref:

```bash
./runners/post_update_service_plan.sh --since-ref HEAD~1
./runners/post_update_service_restart.sh --dry-run --since-ref HEAD~1
```

## Safety Notes

- No database services or containers are restarted.
- Manual restart commands remain available.
- Auto-restart is not enabled by default.
- Reports do not include secrets.
- Health recovery does not perform risky rollback.
