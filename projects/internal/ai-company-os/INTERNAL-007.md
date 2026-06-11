# INTERNAL-007: Add Owner Inbox Runner

## Goal

Add a read-only Owner Inbox command so the Owner/Master can quickly see which tasks need decisions.

## Implemented

Added:

- `runners/owner_inbox.sh`

The runner displays:

- waiting owner acceptance
- needs revision / QA failed / blocked
- recently accepted deliveries
- internal development status
- suggested owner commands

## Verification

- `bash -n runners/owner_inbox.sh`
- `./runners/owner_inbox.sh`

## Status

Implemented.
