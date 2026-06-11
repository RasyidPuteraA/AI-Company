# INTERNAL-039: Add Slash Command Palette and Plus Upload

## Goal

Improve dashboard command bar UX so slash typing shows command suggestions and plus button opens file upload directly.

## Implemented

Updated:

- apps/dashboard/public/app.js
- apps/dashboard/public/styles.css

## UX Changes

- Typing `/` opens a command palette.
- Slash command suggestions are shown like CLI/Codex.
- Clicking a suggestion fills the command bar.
- Pressing Tab selects the first suggestion.
- Pressing Escape closes the command palette.
- The `+` button now opens file upload directly.
- Uploaded files use the existing `/api/uploads` endpoint.

## Supported Commands

- /new
- /pm
- /tasks
- /eng
- /qa
- /review
- /accept
- /revise
- /reject
- /finalize
- /advanced

## Verification

- node --check apps/dashboard/public/app.js
- dashboard service restarted
- `/` tested in command bar
- slash suggestions shown
- plus button opens file picker
- upload tested through command bar plus button

## Status

Implemented.
