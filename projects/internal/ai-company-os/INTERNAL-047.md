# INTERNAL-047: Render JIK Character Sprites in Pixel Office

## Goal

Replace current block-style agent markers with real human sprite rendering from JIK MetroCity assets in the Pixel Office.

## Implemented

Updated:

- apps/dashboard/public/index.html
- apps/dashboard/public/styles.css

Added normalized assets:

- apps/dashboard/public/assets/jik/metrocity-characters/character-model.png
- apps/dashboard/public/assets/jik/metrocity-characters/shadow.png

## Behavior

- Pixel Office agents now render using JIK character sprite sheet.
- CSS block agent body is hidden.
- Each agent uses a different static idle frame.
- Shadow rendering uses JIK Shadow.png.
- Working state keeps a small bob animation.

## Verification

- JIK assets copied to public assets folder
- node --check apps/dashboard/public/app.js
- dashboard service restarted
- /api/summary checked
- browser hard refresh tested
- visual sprite rendering verified

## Status

Implemented.
