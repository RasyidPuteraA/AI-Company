# INTERNAL-024: Add Owner Command Inbox v0

## Goal

Add a local web dashboard chatbox and backend command inbox so the Owner can submit project requirements and instructions from the website.

## Implemented

Added database table:

- owner_commands

Added migration:

- docker/postgres/003_owner_commands.sql

Added API endpoints:

- GET /api/owner/commands
- POST /api/owner/commands

Updated dashboard:

- added Owner Command Inbox panel
- added textarea chatbox
- added submit button
- added command history list
- command list refreshes periodically

Updated files:

- apps/dashboard/server.js
- apps/dashboard/public/index.html
- apps/dashboard/public/styles.css
- apps/dashboard/public/app.js

## Verification

- migration applied successfully
- node --check apps/dashboard/server.js
- node --check apps/dashboard/public/app.js
- sudo systemctl restart ai-company-dashboard
- GET /api/owner/commands tested
- POST /api/owner/commands tested
- owner_command_created event logged

## Status

Implemented.
