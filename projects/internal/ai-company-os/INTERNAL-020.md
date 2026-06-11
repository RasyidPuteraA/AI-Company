# INTERNAL-020: Fix Agent Runtime Status Runner SQL

## Goal

Fix SQL quoting in agent runtime status runners so status update and per-agent display work correctly.

## Problem

The first runtime status runners used psql variable syntax that produced SQL errors:

    ERROR: syntax error at or near ":"

Affected commands:

    ./runners/update_agent_runtime_status.sh
    ./runners/agent_runtime_status.sh engineer_agent

## Implemented

Updated:

- runners/update_agent_runtime_status.sh
- runners/agent_runtime_status.sh

Fix:

- use shell-side SQL escaping
- avoid broken psql variable interpolation
- support per-agent runtime status display
- support runtime status update with notes

## Verification

- bash -n runners/update_agent_runtime_status.sh
- bash -n runners/agent_runtime_status.sh
- update runtime status for engineer_agent tested
- per-agent display tested
- all-agent display tested

## Status

Implemented.
