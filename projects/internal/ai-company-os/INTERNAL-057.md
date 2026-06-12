# INTERNAL-057: Add Agent Services Health Guard

## Goal

Add a health check runner for autonomous agent systemd services, runtime status, queues, and recent crash logs.

## Implemented

Added:

- `runners/agent_services_health_check.sh`

## Checks

The runner verifies:

- syntax of key agent runner scripts
- emergency stop is not active in current shell
- autonomous agent systemd services are active
- agent runtime status can be read
- agent queues can be read
- recent journal logs do not contain crash indicators

## Services Checked

- `ai-company-agent@pm_agent.service`
- `ai-company-agent@engineer_agent.service`
- `ai-company-agent@qa_agent.service`
- `ai-company-agent@devops_agent.service`

## Verification

Run:

    ./runners/agent_services_health_check.sh

Expected result:

    Agent services health check passed.

## Status

Implemented.
