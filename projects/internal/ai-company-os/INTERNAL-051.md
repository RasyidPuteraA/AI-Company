# INTERNAL-051: Polish Canvas Pixel Office Layout and LimeZu Sprite Fallback

## Goal

Polish the installed Canvas Pixel Office renderer, enlarge the office stage, and add optional LimeZu sprite fallback for selected furniture objects.

## Implemented

Updated:

- `apps/dashboard/public/office-canvas.js`
- `apps/dashboard/public/office.css`

## Behavior

- Canvas Pixel Office stage is enlarged and centered inside the dashboard panel
- Optional LimeZu object sprites are loaded from the local VPS asset folder
- If LimeZu raw assets are unavailable, the renderer safely falls back to procedural furniture
- JIK character sprites remain the live agent sprites
- Runtime polling remains connected to `/api/agents/runtime`

## Asset Policy

Raw LimeZu paid assets remain gitignored:

- `apps/dashboard/public/assets/limezu/_incoming/`
- `apps/dashboard/public/assets/limezu/modern-office/`
- `apps/dashboard/public/assets/limezu/_preview/`

Only code and selected/generated outputs should be committed.

## Current Stage

Canvas Pixel Office polish checkpoint.

## Next Steps

- Build a formal Canvas layout config file
- Replace more procedural objects with selected LimeZu sprites
- Add walking paths and agent movement
- Add click/hover agent detail popups

## Status

Implemented.
