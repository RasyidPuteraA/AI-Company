# INTERNAL-056: Add Dashboard Health Guard

## Goal

Add a dashboard health check runner to verify syntax, service status, and key API endpoints before and after dashboard changes.

## Implemented

Added:

- `runners/dashboard_health_check.sh`

## Checks

The runner verifies:

- `apps/dashboard/server.js` syntax
- `apps/dashboard/public/app.js` syntax
- optional `office-canvas.js` syntax
- optional `owner-review-actions.js` syntax
- `ai-company-dashboard.service` active status
- `/api/summary`
- `/api/tasks`
- `/api/owner/review/accept-finalize` validation response

## Usage

```bash
./runners/dashboard_health_check.sh
```

## Status

Implemented.
