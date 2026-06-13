# INTERNAL-077: Add Autonomous Issue Discovery and Self-Directed Fix Loop

## Goal

Add a self-directed loop where AI agents discover repo, dashboard, service, and infrastructure problems by themselves, create internal AUTO tasks, solve them through guarded auto-development, and report outcomes.

## Implemented

Added:

- `company/config/autonomous_discovery.env`
- `runners/autonomous_issue_discovery.sh`
- `runners/autonomous_self_directed_loop.sh`

Updated:

- `runners/autonomous_code_dev.sh` includes autonomous task notes in Codex prompts when available

## Capabilities

- discovers issues from git state, dashboard health, agent service health, Pixel Office asset check, pre-commit check, TODO/FIXME scan, and stale task guard if present
- writes discovery reports under `company/reports/autonomous-discovery/`
- writes candidate TSV files under `company/runtime/autonomous-discovery/`
- creates deduplicated `AUTO-*` internal tasks from discovered candidates
- writes task notes under `company/runtime/autodev/task_notes/`
- can optionally auto-solve via `runners/autonomous_code_dev.sh`

## Safety Defaults

- task creation disabled by default
- auto-solve disabled by default
- max task creation per run defaults to 1
- duplicate issue signatures are skipped using runtime ledger
- auto-solve still uses autonomous code guard and pre-commit check from INTERNAL-076

## Usage

Dry-run discovery:

```bash
./runners/autonomous_self_directed_loop.sh engineer_agent --dry-run
```

Create discovered task, but do not auto-solve:

```bash
AI_COMPANY_SELF_DIRECTED_CREATE_TASKS=1 ./runners/autonomous_self_directed_loop.sh engineer_agent --once
```

Create and auto-solve discovered task:

```bash
AI_COMPANY_SELF_DIRECTED_CREATE_TASKS=1 AI_COMPANY_SELF_DIRECTED_AUTO_SOLVE=1 AI_COMPANY_ENABLE_AUTO_EDIT=1 AI_COMPANY_ENABLE_AUTO_COMMIT=1 ./runners/autonomous_self_directed_loop.sh engineer_agent --once
```

## Verification

- `bash -n runners/autonomous_issue_discovery.sh`
- `bash -n runners/autonomous_self_directed_loop.sh`
- `./runners/autonomous_self_directed_loop.sh engineer_agent --dry-run`
- `./runners/pre_commit_check.sh`

## Status

Implemented.
