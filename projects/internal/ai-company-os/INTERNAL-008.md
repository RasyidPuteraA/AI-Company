# INTERNAL-008: Add Terminal Company Dashboard

## Goal

Add a read-only terminal dashboard that summarizes company health in one command.

## Implemented

Added:

- `runners/company_status.sh`

The dashboard displays:

- task health summary
- client task status
- internal development status
- owner attention queue
- latest accepted deliveries
- latest agent events
- suggested commands

## Verification

- `bash -n runners/company_status.sh`
- `./runners/company_status.sh`

## Status

Implemented.
