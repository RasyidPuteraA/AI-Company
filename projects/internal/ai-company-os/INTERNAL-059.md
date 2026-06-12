# INTERNAL-059: Add System Health Shortcut

## Goal

Add a documented owner shortcut for running the unified system health check and make it visible in handover/status guidance.

## Implemented

Added:

- `runners/health.sh`

## Behavior

`runners/health.sh` delegates to:

    ./runners/system_health_check.sh

## Usage

    ./runners/health.sh

## Expected Result

    AI Company OS system health check passed.

## Status

Implemented.
