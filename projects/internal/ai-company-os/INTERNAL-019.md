# INTERNAL-019: Add Agent Runtime Status Tracking

## Goal

Add runtime status tracking for agents so the system can record and display each agent's current state.

## Implemented

Added database table:

- agent_runtime_status

Added migration:

- docker/postgres/002_agent_runtime_status.sql

Added runners:

- runners/update_agent_runtime_status.sh
- runners/agent_runtime_status.sh

Updated:

- runners/claim_next_task.sh

Runtime statuses supported by convention:

- idle
- queued
- claimed
- working
- safety_blocked
- done
- failed
- stopped

Behavior:

- agent runtime status can be updated directly
- current task key can be recorded
- location can be recorded
- status note can be recorded
- task claiming now updates agent runtime status to claimed

Example commands:

    ./runners/agent_runtime_status.sh
    ./runners/agent_runtime_status.sh engineer_agent
    ./runners/update_agent_runtime_status.sh engineer_agent working INTERNAL-019 engineering_desk "Implementing runtime status tracking."

## Verification

- migration applied successfully
- bash -n runners/update_agent_runtime_status.sh
- bash -n runners/agent_runtime_status.sh
- bash -n runners/claim_next_task.sh
- runtime status updated for engineer_agent
- runtime status display verified

## Status

Implemented.
