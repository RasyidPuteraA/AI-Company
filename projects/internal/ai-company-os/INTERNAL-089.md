# INTERNAL-089: Filter Invalid Task Keys

## Problem

The scheduler passed PostgreSQL command output `UPDATE 0` as if it were a real task key.

## Fix

- Filter PostgreSQL command tags from `psql_rows`.
- Add task key validation.
- Only accept task keys starting with `TASK-`, `CLIENT-`, `INTERNAL-`, or `AUTO-`.
- Reset stale scheduler runtime state before re-testing.

## Expected Result

The scheduler must never pass `UPDATE 0` to autonomous development runners.
