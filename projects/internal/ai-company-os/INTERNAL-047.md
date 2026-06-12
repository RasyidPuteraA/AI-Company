# INTERNAL-047: Render JIK Character Sprites in Pixel Office

## Goal

Replace current block-style agent markers with real human sprite rendering from JIK MetroCity assets in the Pixel Office.

## Implemented

Updated:

- apps/dashboard/public/app.js
- apps/dashboard/public/styles.css
- apps/dashboard/server.js

Added final dashboard assets:

- apps/dashboard/public/assets/jik/metrocity-characters/pm.png
- apps/dashboard/public/assets/jik/metrocity-characters/engineer.png
- apps/dashboard/public/assets/jik/metrocity-characters/qa.png
- apps/dashboard/public/assets/jik/metrocity-characters/devops.png
- apps/dashboard/public/assets/jik/metrocity-characters/owner.png
- apps/dashboard/public/assets/custom-office/maps/office-map-v1.png

## Asset Policy

Raw downloaded/extracted third-party asset folders are not committed:

- apps/dashboard/public/assets/jik/_incoming/
- apps/dashboard/public/assets/jik/_processed/

Only normalized dashboard-ready assets are committed.

## Visual Baseline

Accepted baseline:

- office-main-card min-height: 860px
- tilemapOffice height: 800px
- tilemap-stage width: min(100%, 1480px)
- custom office map rendered as stable PNG
- JIK sprites rendered as cropped per-agent PNG files

## Status

Implemented.
