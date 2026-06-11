# INTERNAL-013: Add Parallel Agent Queue Foundation

## Goal

Add safe queue and claim runners so agents can independently inspect and claim assigned work.

## Implemented

Added:

- `runners/agent_queue.sh`
- `runners/claim_next_task.sh`
- `runners/agent_worker_once.sh`

Capabilities:

- list queue by agent
- claim one assigned task
- update task status to `IN_PROGRESS`
- log `task_claimed` event
- support future simultaneous agent workers

## Verification

- `bash -n runners/agent_queue.sh`
- `bash -n runners/claim_next_task.sh`
- `bash -n runners/agent_worker_once.sh`
- `./runners/agent_queue.sh engineer_agent`
- `./runners/agent_worker_once.sh engineer_agent`

## Status

Implemented.
