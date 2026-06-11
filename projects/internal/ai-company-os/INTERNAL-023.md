# INTERNAL-023: Connect Pixel Office to Runtime Status

## Goal

Connect pixel office visualization to agent runtime status API so rooms and sprites reflect current agent states instead of only latest event history.

## Implemented

Updated:

- apps/dashboard/public/app.js

Behavior:

- pixel office polls /api/agents/runtime
- room labels show current runtime status
- busy statuses activate rooms and sprites
- done/idle statuses return sprites to non-busy state
- runtime status now drives pixel office more directly than latest event history

Runtime statuses considered busy:

- queued
- claimed
- working
- safety_blocked

## Verification

- node --check apps/dashboard/public/app.js
- /api/agents/runtime tested
- engineer_agent runtime status updated to working
- engineer room/sprite updated from runtime status
- engineer_agent runtime status updated to done

## Status

Implemented.
