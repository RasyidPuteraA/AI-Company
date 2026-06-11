# INTERNAL-017: Add Disabled Agent Worker Service Template

## Goal

Add disabled-by-default systemd service templates for safe agent worker loops without enabling autonomous 24/7 execution.

## Implemented

Added systemd template:

- /etc/systemd/system/ai-company-agent-worker@.service

Added environment config:

- /etc/ai-company/agent-worker.env

Behavior:

- service is a bounded oneshot
- service uses agent_worker_loop.sh
- service respects work-hour guard
- service respects emergency stop
- service is not enabled by default
- service does not auto-start on reboot

Example commands:

    sudo systemctl start ai-company-agent-worker@engineer_agent
    sudo systemctl status ai-company-agent-worker@engineer_agent --no-pager
    sudo journalctl -u ai-company-agent-worker@engineer_agent -n 40 --no-pager

## Safety Verification

Starting the worker outside work hours was blocked by safety guard.

Observed result:

    SAFETY BLOCK: outside work hours 08:00-19:00 Asia/Jakarta.

This confirms the service template respects the worker safety guard.

## Status

Implemented.
