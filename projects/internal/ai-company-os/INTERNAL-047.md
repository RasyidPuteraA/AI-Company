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
- apps/dashboard/public/assets/jik/metrocity-characters/agent-suit.png

Generated contact sheets:

- apps/dashboard/public/assets/jik/contact-sheets/character-model-contact-sheet.png
- apps/dashboard/public/assets/jik/contact-sheets/suit-contact-sheet.png
- apps/dashboard/public/assets/jik/contact-sheets/suit1-contact-sheet.png
- apps/dashboard/public/assets/jik/contact-sheets/hair-contact-sheet.png

## Behavior

- Pixel Office agents now render using JIK character sprite sheets.
- CSS block agent body is hidden.
- Each agent uses a static idle frame.
- Shadow rendering uses JIK Shadow.png.
- Suit sprite sheet is used for agent body rendering.
- Contact sheets help select better frames.

## Verification

- JIK assets copied to public assets folder
- contact sheets generated
- node --check apps/dashboard/public/app.js
- dashboard service restarted
- browser hard refresh tested
- visual sprite rendering verified

## Status

Implemented.
