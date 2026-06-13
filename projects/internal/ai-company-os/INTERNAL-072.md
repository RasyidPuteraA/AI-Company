# INTERNAL-072: Upgrade Pixel Office Map Renderer from Production Package

## Goal

Upgrade the dashboard Pixel Office map using the uploaded production pixel-office renderer concepts: layered ground map, furniture objects, animated characters, loading-safe rendering, and no old-map flicker.

## Implemented

Updated:

- `apps/dashboard/public/office-canvas.js`
- `apps/dashboard/public/office.css`
- `apps/dashboard/public/index.html`

## Behavior

The dashboard Pixel Office now uses a production-style Canvas renderer based on the uploaded package concepts:

- layered `GROUND` map
- furniture object list
- animated PM, Engineer, QA, DevOps, and Owner characters
- runtime task labels from `/api/agents/runtime`
- old CSS background maps disabled in canvas mode

## Flicker Fix

Older CSS background maps are disabled when canvas mode is active, preventing the previous office map from flashing before the Canvas renderer takes over.

## Safety

- no raw asset PNG committed
- no Codex auth or secret files touched
- renderer remains isolated in dashboard public assets
- custom PNG tile mapping is deferred to a future task

## Verification

- `node --check apps/dashboard/public/office-canvas.js`
- `curl http://127.0.0.1:8787/office-canvas.js`
- `curl http://127.0.0.1:8787/office.css`
- `./runners/dashboard_health_check.sh`
- `./runners/pre_commit_check.sh`

## Status

Implemented.
