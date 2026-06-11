# INTERNAL-040: Restructure Dashboard Layout from Wireframe

## Goal

Restructure dashboard layout based on owner wireframe:

- sidebar navigation
- top header / web name
- central office map and agent activity area
- VPS/server health area
- command bar as primary interaction
- bottom summary cards

## Implemented

Updated:

- apps/dashboard/public/index.html
- apps/dashboard/public/styles.css

## New Layout

The dashboard now follows this structure:

    Sidebar
    Top header
    Main office activity map
    Server/VPS health panel
    Command bar
    Bottom cards:
      - Last Tasks
      - Latest Events
      - Agent Status

## Design Direction

This moves the UI away from stacked admin panels and toward an AI command center interface.

The pixel office / agent activity map is now the visual center of the dashboard.

Legacy advanced workflow panels are no longer the primary visible interface.

## Verification

- node --check apps/dashboard/public/app.js
- dashboard service restarted
- /api/summary checked
- browser hard refresh tested
- sidebar visible
- office map visible
- health panel visible
- command bar visible
- bottom cards visible

## Status

Implemented.
