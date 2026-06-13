# INTERNAL-075: Connect Pixel Office Renderer to Optional Asset Config

## Goal

Connect dashboard Pixel Office renderer to the optional `assets/office/config.json` mapping so future custom tileset PNGs can be loaded without committing raw assets.

## Implemented

Updated:

- `apps/dashboard/public/office-canvas.js`
- `runners/pixel_office_asset_check.sh`
- `apps/dashboard/public/index.html`

## Behavior

The Pixel Office renderer now reads:

- `/assets/office/config.json`

When `mode` is `template`, the renderer keeps using the synthetic Canvas renderer.

When `mode` is changed to `custom` and an approved tileset image exists in the ignored asset folder, the renderer can load mapped tiles from the custom tileset.

## Safety

- raw image assets remain ignored by git
- missing PNG assets do not break dashboard rendering
- renderer falls back to synthetic mode
- config is exposed for debugging as `window.AI_COMPANY_PIXEL_OFFICE_ASSET_CONFIG`

## Verification

- `node --check apps/dashboard/public/office-canvas.js`
- `bash -n runners/pixel_office_asset_check.sh`
- `./runners/pixel_office_asset_check.sh`
- `curl http://127.0.0.1:8787/assets/office/config.json`
- `./runners/dashboard_health_check.sh`
- `./runners/pre_commit_check.sh`

## Status

Implemented.
