# INTERNAL-049: Render LimeZu Modern Office Map v1

## Goal

Build a new Pixel Office map using purchased LimeZu Modern Office assets while keeping JIK MetroCity characters for live agents.

## Current Stage

Work in progress.

The current implementation is a LimeZu-based floorplan prototype, not the final Pixel Office visual.

## Implemented So Far

Added:

- `runners/render_limezu_office_map.py`
- `apps/dashboard/public/assets/limezu/maps/office-map-v2.png`

Prepared locally but ignored from git:

- `apps/dashboard/public/assets/limezu/_incoming/`
- `apps/dashboard/public/assets/limezu/modern-office/`
- `apps/dashboard/public/assets/limezu/_preview/`

## Current Visual Direction

The target direction is a single top-down office floorplan inspired by the provided modern office reference image.

The map should feel like one coherent office, not six separate room cards.

## Current Issues

- Office layout is still prototype quality
- Furniture placement needs more polish
- Room labels are still too visible
- Agent anchors are not final
- The map does not yet fully match the reference composition

## Next Steps

- Build a denser single-floor office layout
- Reduce heavy room labels
- Improve desk clusters and furniture layering
- Tune JIK agent positions
- Commit final version only after visual approval

## Status

In progress.
