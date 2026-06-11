# INTERNAL-012: Add Pixel Office Visualization v0

## Goal

Add the first pixel office visualization to the web dashboard.

## Implemented

- Replaced static pixel placeholder with a room-based pixel office.
- Added rooms:
  - PM
  - Engineer
  - QA
  - DevOps
  - Owner
  - Meeting
- Added simple agent sprites.
- Connected pixel office state to realtime event stream.
- Events now activate rooms and move/busy-state sprites.

## Verification

- `node --check apps/dashboard/public/app.js`
- `sudo systemctl restart ai-company-dashboard`
- logged test events for engineer, QA, and owner activity

## Status

Implemented.
