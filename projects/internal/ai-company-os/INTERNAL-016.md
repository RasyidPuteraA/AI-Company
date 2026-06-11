# INTERNAL-016: Fix Empty Task Claim Handling

## Goal

Fix `claim_next_task.sh` so PostgreSQL `UPDATE 0` output is treated as no claimable task.

## Problem

When no rows were updated, PostgreSQL returned `UPDATE 0`.
The previous script interpreted that output as a claimed task.

Bad output:

    Task claimed:
    - Project: unknown-project
    - Task: UPDATE 0
    - Title: UPDATE 0

## Implemented

Updated:

- `runners/claim_next_task.sh`

Behavior:

- ignores `UPDATE 0`
- only accepts claim output containing a pipe-delimited `task_key|title`
- exits cleanly when no claimable task exists

## Verification

- `bash -n runners/claim_next_task.sh`
- claim with available task works
- claim with no available task returns:
  - `No claimable task for agent: engineer_agent`

## Status

Implemented.
