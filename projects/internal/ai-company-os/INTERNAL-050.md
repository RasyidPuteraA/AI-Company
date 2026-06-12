# INTERNAL-050: Install Canvas Pixel Office Renderer

## Goal

Adapt the uploaded pixel-office.html Canvas prototype into the AI Company OS dashboard Pixel Office panel.

## Source

The implementation is based on the uploaded standalone `pixel-office.html` prototype.

## Implemented

Added:

- `apps/dashboard/public/office-canvas.js`

Updated:

- `apps/dashboard/public/index.html`
- `apps/dashboard/public/office.css`

## Behavior

- Renders Pixel Office into `#tilemapOffice .tilemap-stage`
- Uses Canvas instead of static PNG-only background
- Hides old DOM room labels, props, and tile agents while Canvas mode is active
- Uses JIK agent sprites from `/assets/jik/metrocity-characters/`
- Polls `/api/agents/runtime` every 5 seconds
- Shows simple working/blocked visual states
- Keeps pixelated rendering and scanline overlay

## Current Stage

Prototype installed.

This is the new foundation for future Pixel Office animation and live simulation.

## Next Steps

- Replace procedural furniture with selected LimeZu object sprites
- Tune agent coordinates
- Add walking paths
- Add richer status animation
- Add click/hover agent info

## Status

Implemented.
