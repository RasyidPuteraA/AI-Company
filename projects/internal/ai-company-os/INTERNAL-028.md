# INTERNAL-028: Add Convert Command Button in Dashboard

## Goal

Add dashboard UI and backend API to convert Owner Command Inbox entries into client projects without using terminal commands.

## Implemented

Added backend API endpoint:

- POST /api/owner/commands/convert

The endpoint calls:

- runners/convert_owner_command_to_project.sh

Updated dashboard:

- added Convert Command to Project panel
- added command id input
- added project key input
- added project title input
- added convert button
- added command output display

Updated files:

- apps/dashboard/server.js
- apps/dashboard/public/index.html
- apps/dashboard/public/styles.css
- apps/dashboard/public/app.js

## Verification

- node --check apps/dashboard/server.js
- node --check apps/dashboard/public/app.js
- dashboard service restarted
- created test owner command from API
- converted test owner command from API
- verified owner command status changed to CONVERTED
- verified client project was created
- verified initial PM task was created

## Status

Implemented.
