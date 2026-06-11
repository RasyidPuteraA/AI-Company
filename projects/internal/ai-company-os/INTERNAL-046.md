# INTERNAL-046: Add JIK Character Pipeline and Custom Office Map

## Goal

Add JIK-A-4 MetroCity character asset pipeline and keep the office map custom-built instead of using external office tiles.

## Decision

Use:

- JIK-A-4 MetroCity Free Top Down Character Pack for agent/employee characters.
- Custom AI Company OS office map for the Pixel Office background.

Do not use LimeZu office map assets for now.

## Implemented

Added:

- apps/dashboard/public/assets/jik/
- apps/dashboard/public/assets/jik/README.md
- apps/dashboard/public/assets/jik/asset-manifest.json
- apps/dashboard/public/assets/jik/_incoming/
- apps/dashboard/public/assets/jik/_processed/
- apps/dashboard/public/assets/jik/metrocity-characters/
- apps/dashboard/public/assets/custom-office/
- apps/dashboard/public/assets/custom-office/README.md
- apps/dashboard/public/assets/custom-office/tiles/
- apps/dashboard/public/assets/custom-office/props/
- apps/dashboard/public/assets/custom-office/maps/
- runners/validate_jik_assets.sh

## Asset Flow

1. Download JIK character pack manually.
2. Upload archive into:

       apps/dashboard/public/assets/jik/_incoming/

3. Extract into:

       apps/dashboard/public/assets/jik/_processed/

4. Select sprites for:

- pm_agent
- engineer_agent
- qa_agent
- devops_agent
- owner

5. Normalize selected sprites into:

       apps/dashboard/public/assets/jik/metrocity-characters/

## Verification

- folder structure created
- asset manifest created
- validation runner created
- validation runner executed

## Status

Implemented.
