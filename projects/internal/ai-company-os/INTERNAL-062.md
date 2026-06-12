# INTERNAL-062: Add Codex CLI Autonomous Access Policy

## Goal

Set Codex CLI with ChatGPT subscription login as the approved model access path for autonomous agents without storing API keys in repo.

## Implemented

Added:

- `projects/internal/ai-company-os/CODEX_CLI_AUTONOMOUS_ACCESS_POLICY.md`
- `runners/codex_agent_check.sh`

## Verification

Codex CLI is installed and non-interactive read-only smoke test returned:

    CODEX_OK

## Status

Implemented.
