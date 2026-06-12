# INTERNAL-064: Add Idle Internal Improvement Planner

## Goal

Add a safe planner that creates internal improvement tasks when there is no active client work and no pending Owner approval.

## Implemented

Added:

- `runners/idle_internal_improvement_planner.sh`

## Modes

- `--dry-run`: show the next idle improvement candidate without changing the database
- `--once`: create one safe internal improvement task if the system is idle

## Safety Rules

The planner skips task creation when:

- Owner attention is required
- active client work exists

The planner only creates predefined safe internal improvement tasks.

## Verification

- `bash -n runners/idle_internal_improvement_planner.sh`
- `./runners/idle_internal_improvement_planner.sh --dry-run`
- `./runners/pre_commit_check.sh`

## Status

Implemented.
