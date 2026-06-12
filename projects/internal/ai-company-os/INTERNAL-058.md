# INTERNAL-058: Add Unified System Health Check

## Goal

Add one top-level health check runner that verifies dashboard health, agent services health, company status, and owner inbox readability.

## Implemented

Added:

- `runners/system_health_check.sh`

## Checks

The runner verifies:

- dashboard health via `runners/dashboard_health_check.sh`
- autonomous agent services health via `runners/agent_services_health_check.sh`
- company status readability via `runners/company_status.sh`
- owner inbox readability via `runners/owner_inbox.sh`

## Agent Service Note

Agent services may briefly appear as `activating (auto-restart)` after a successful bounded loop exits with status 0. This is treated as healthy.

## Usage

    ./runners/system_health_check.sh

## Expected Result

    AI Company OS system health check passed.

## Status

Implemented.
