# INTERNAL-074: Prepare Pixel Office Custom Asset Mapping

## Goal

Prepare dashboard Pixel Office custom asset folders, config template, gitignore rules, and validation runner for future tileset and character PNG integration without committing raw assets.

## Implemented

Added:

- `apps/dashboard/public/assets/office/config.json`
- `apps/dashboard/public/assets/office/tilesets/.gitkeep`
- `apps/dashboard/public/assets/office/characters/.gitkeep`
- `runners/pixel_office_asset_check.sh`

Updated:

- `.gitignore` ignores raw Pixel Office tileset and character image assets

## Verification

- `bash -n runners/pixel_office_asset_check.sh`
- `./runners/pixel_office_asset_check.sh`
- `python3 -m json.tool apps/dashboard/public/assets/office/config.json`

Observed:

- asset root exists
- tilesets directory exists
- characters directory exists
- config JSON is valid
- raw PNG assets are optional and ignored by git by default

## Safety

- raw PNG/JPG/WebP assets are ignored by default
- config template is tracked
- asset folders are tracked via `.gitkeep`
- validation runner is read-only
- no Codex credentials or auth files touched

## Status

Implemented.
