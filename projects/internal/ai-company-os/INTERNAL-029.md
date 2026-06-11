# INTERNAL-029: Add Attach Uploads Button in Dashboard

## Goal

Add dashboard UI and backend API to attach uploaded project files to PM intake task context without using terminal commands.

## Implemented

Added backend API endpoint:

- POST /api/uploads/attach-context

The endpoint calls:

- runners/attach_uploads_to_pm_context.sh

Updated dashboard:

- added Attach Uploads to PM Context panel
- added project key input
- added task key input
- added attach button
- added command output display

Updated runner behavior:

- attachment section in PM task file is now replaced instead of duplicated

Updated files:

- apps/dashboard/server.js
- apps/dashboard/public/index.html
- apps/dashboard/public/styles.css
- apps/dashboard/public/app.js
- runners/attach_uploads_to_pm_context.sh

## Verification

- node --check apps/dashboard/server.js
- node --check apps/dashboard/public/app.js
- bash -n runners/attach_uploads_to_pm_context.sh
- dashboard service restarted
- POST /api/uploads/attach-context tested
- verified task file was updated with upload context
- verified attachment section is not duplicated
- event logged

## Status

Implemented.
