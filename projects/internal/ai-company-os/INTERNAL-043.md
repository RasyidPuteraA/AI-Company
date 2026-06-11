# INTERNAL-043: Add Pixel Office Simulation Stage v1

## Goal

Refactor Pixel Office from CSS grid rooms into a simulation-style office stage inspired by Claude Office and Pixel Agents.

## Implemented

Updated:

- apps/dashboard/public/index.html
- apps/dashboard/public/app.js
- apps/dashboard/public/styles.css

## Visual Direction

The Pixel Office now uses a simulation-style stage:

- absolute-position office map
- hallway layout
- room zones
- pixel floor
- city window
- wall clock
- furniture
- server rack
- whiteboard
- CSS pixel agents
- agent status bubbles
- data-room based agent positioning

## References

- Claude Office style office simulation
- Pixel Agents style office activity visualization

## Verification

- node --check apps/dashboard/public/app.js
- dashboard service restarted
- /api/summary checked
- browser hard refresh tested
- office simulation stage visually checked

## Status

Implemented.
