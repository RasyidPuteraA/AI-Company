# INTERNAL-070: Enable Codex Agent Loop in Managed Services

## Goal

Enable managed agent services to use the Codex-enabled worker loop with explicit safety flags and bounded execution.

## Implemented

Added:

- `runners/install_codex_agent_service_dropin.sh`

Installed systemd drop-in:

- `/etc/systemd/system/ai-company-agent@.service.d/10-codex-loop.conf`

## Behavior

The drop-in overrides the managed agent service `ExecStart` to use:

```bash
/opt/ai-company/runners/agent_worker_loop_with_codex.sh %i --loop --interval 10 --max-iterations 1
```

## Safety

- Codex dispatcher enabled explicitly with `AI_COMPANY_ENABLE_CODEX_DISPATCHER=1`
- loop remains bounded
- `RestartSec=30` prevents tight restart loops
- existing dispatcher eligibility gates still apply
- no Codex credentials are stored in systemd config
- no auto-edit
- no auto-commit
- no client finalization

## Verification

- `bash -n runners/install_codex_agent_service_dropin.sh`
- `./runners/install_codex_agent_service_dropin.sh --dry-run`
- `./runners/install_codex_agent_service_dropin.sh --apply`
- `systemctl cat ai-company-agent@pm_agent.service`
- `./runners/agent_services_health_check.sh`
- `./runners/pre_commit_check.sh`

## Status

Implemented.
