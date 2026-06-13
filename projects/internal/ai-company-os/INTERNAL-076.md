# INTERNAL-076: Add Controlled Auto-Edit and Auto-Commit Developer Worker

## Goal

Add a guarded autonomous developer worker that can learn repository context, run Codex in workspace-write mode, edit code, run safety checks, and optionally auto-commit to an autodev branch.

## Implemented

Added:

- `company/config/autonomous_development.env`
- `runners/autonomous_code_context.sh`
- `runners/autonomous_code_guard.sh`
- `runners/autonomous_code_dev.sh`

## Capabilities

- generate repository and infrastructure context before development
- run Codex in `workspace-write` mode for bounded implementation
- deny edits to secrets, tokens, auth files, `.env`, SSH/Codex credentials, runtime files, and binary assets
- limit maximum changed files and diff lines
- run `pre_commit_check.sh` before commit
- optionally auto-commit to an `autodev/...` branch
- optionally push the branch
- optionally mark task DONE after successful commit

## Safety Defaults

- auto edit disabled by default
- auto commit disabled by default
- auto push disabled by default
- auto mark done disabled by default

Enable per run with environment variables:

```bash
AI_COMPANY_ENABLE_AUTO_EDIT=1 AI_COMPANY_ENABLE_AUTO_COMMIT=1 ./runners/autonomous_code_dev.sh engineer_agent TASK_KEY --run
```

## Verification

- `bash -n runners/autonomous_code_context.sh`
- `bash -n runners/autonomous_code_guard.sh`
- `bash -n runners/autonomous_code_dev.sh`
- `./runners/autonomous_code_context.sh`
- `./runners/autonomous_code_dev.sh engineer_agent INTERNAL-076 --dry-run`
- `./runners/pre_commit_check.sh`

## Status

Implemented.
