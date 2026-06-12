# INTERNAL-055: Add Dashboard Owner Review Accept Finalize Button

## Goal

Add a dashboard action panel and API endpoint so owner can accept and finalize review tasks from the dashboard.

## Implemented

Added:

- `apps/dashboard/public/owner-review-actions.js`

Updated:

- `apps/dashboard/public/index.html`
- `apps/dashboard/server.js`
- `runners/owner_accept_and_finalize.sh`

## Behavior

When a task is waiting for owner acceptance, the dashboard shows an Owner Review panel with an `Accept + Finalize` button.

The button calls:

- `POST /api/owner/review/accept-finalize`

The API safely executes:

- `runners/owner_accept_and_finalize.sh`

## Safety

Owner approval remains manual.

The dashboard button does not auto-approve anything. It only reduces terminal steps after the owner deliberately clicks `Accept + Finalize`.

## Status

Implemented.
