# INTERNAL-073: Polish Pixel Office Map Fit and Room Labels

## Goal

Polish the production Pixel Office dashboard map by improving canvas fit, centering, room labels, agent spacing, and status bubbles.

## Implemented

Updated:

- `apps/dashboard/public/office-canvas.js`
- `apps/dashboard/public/office.css`
- `apps/dashboard/public/index.html`

## Changes

- widened the office canvas map from 20 columns to 36 columns
- repositioned desks, monitors, server racks, owner area, meeting area, and break room
- repositioned PM, Engineer, QA, DevOps, and Owner agents
- added room labels for PM, Engineering, QA, DevOps, Break Room, Meeting, and Owner
- improved production canvas fit so it does not overlap the summary cards below
- cache-busted office CSS and canvas JS through `v=076`

## Visual Result

The dashboard now shows a wider production-style office map with readable room labels and safer spacing above the summary cards.

## Verification

- `node --check apps/dashboard/public/office-canvas.js`
- `curl http://127.0.0.1:8787/office-canvas.js`
- `curl http://127.0.0.1:8787/office.css`
- `./runners/dashboard_health_check.sh`
- `./runners/pre_commit_check.sh`

## Status

Implemented.
