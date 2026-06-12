# INTERNAL-052: Enable Autonomous Agent Worker Services

## Goal

Enable safe autonomous worker services for PM, Engineer, QA, and DevOps agents so they can claim and process work loops independently with safety guards.

## Implemented

Added systemd template:

- `/etc/systemd/system/ai-company-agent@.service`

Enabled services:

- `ai-company-agent@pm_agent.service`
- `ai-company-agent@engineer_agent.service`
- `ai-company-agent@qa_agent.service`
- `ai-company-agent@devops_agent.service`

## Safety Fix

Initial service config used:

    --max-iterations 240

The worker loop rejected this because the safety guard limit is 20.

Fixed service config:

    --max-iterations 20

## Runtime Behavior

Each service runs:

    ./runners/agent_worker_loop.sh AGENT --loop --interval 15 --max-iterations 20

Systemd restarts the bounded loop after it exits.

## Verification

All services are active and running:

- `ai-company-agent@pm_agent.service`
- `ai-company-agent@engineer_agent.service`
- `ai-company-agent@qa_agent.service`
- `ai-company-agent@devops_agent.service`

PM agent successfully claimed:

- `CLIENT-2-001`

## Safety Controls

Stop all services:

    sudo systemctl stop 'ai-company-agent@*.service'

Disable all services:

    sudo systemctl disable 'ai-company-agent@*.service'

Emergency stop env:

    AI_COMPANY_AGENT_EMERGENCY_STOP=1

## Status

Implemented.
