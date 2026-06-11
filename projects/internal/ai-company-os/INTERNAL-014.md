# INTERNAL-014: Add Safe Agent Worker Loop

## Goal

Add a safe agent worker loop runner with dry-run, once, and bounded loop modes.

## Implemented

Added:

- `runners/agent_worker_loop.sh`

Modes:

- `--dry-run`: show the next claimable task without changing the database
- `--once`: claim one task
- `--loop`: repeat claim checks with interval and max iteration bounds

Example commands:

```bash
./runners/agent_worker_loop.sh engineer_agent --dry-run
./runners/agent_worker_loop.sh engineer_agent --once
./runners/agent_worker_loop.sh engineer_agent --loop --interval 3 --max-iterations 2
Verification
bash -n runners/agent_worker_loop.sh
dry-run mode tested
once mode tested
bounded loop mode tested
Status

Implemented.
