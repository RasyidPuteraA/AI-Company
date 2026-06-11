# INTERNAL-042: Improve Pixel Office Visual v1

## Goal

Improve Pixel Office visual style using Pixel Agents and MetroCity-inspired top-down office references.

## References

- pixel-agents-hq/pixel-agents
- JIK-A-4 MetroCity Free Top Down Character Pack

## Implemented

Updated:

- apps/dashboard/public/index.html
- apps/dashboard/public/app.js
- apps/dashboard/public/styles.css

## Visual Changes

- Reworked office map into a larger top-down pixel office
- Added pixel tiled floor
- Added room wall strips
- Added furniture/desk shapes
- Replaced emoji-like agents with CSS pixel-agent sprites
- Added per-agent name labels
- Added status bubbles
- Added working/done/blocked visual states
- Added active room glow
- Improved responsive office layout

## Notes

This version uses CSS pixel-art inspired visuals first.

Future version can import actual MetroCity/Pixel Agents sprite assets into:

    apps/dashboard/public/assets/pixel-office/

## Verification

- node --check apps/dashboard/public/app.js
- dashboard service restarted
- /api/summary checked
- browser hard refresh tested
- office map visually verified

## Status

Implemented.
