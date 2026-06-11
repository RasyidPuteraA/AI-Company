# INTERNAL-018: Add Worker Service Control Runner

## Goal

Add a safe owner-facing runner to control disabled-by-default agent worker systemd services.

## Implemented

Added:

- runners/worker_service_control.sh

Supported actions:

- status
- start
- stop
- logs
- reset-failed
- enabled
- config

Example commands:

    ./runners/worker_service_control.sh engineer_agent status
    ./runners/worker_service_control.sh engineer_agent start
    ./runners/worker_service_control.sh engineer_agent stop
    ./runners/worker_service_control.sh engineer_agent logs
    ./runners/worker_service_control.sh engineer_agent reset-failed
    ./runners/worker_service_control.sh engineer_agent enabled
    ./runners/worker_service_control.sh engineer_agent config

## Safety

The wrapper does not enable autonomous startup.

The systemd worker service remains disabled by default.

Starting the service still respects the safety guard in agent_worker_loop.sh, including work-hour blocking and emergency stop.

## Verification

- bash -n runners/worker_service_control.sh
- status action tested
- logs action tested
- reset-failed action tested
- start action tested and safety block confirmed outside work hours
- stop action tested

## Status

Implemented.
