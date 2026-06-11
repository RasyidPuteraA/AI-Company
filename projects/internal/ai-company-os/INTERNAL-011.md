# INTERNAL-011: Add Realtime Event Stream

## Goal

Add read-only realtime event updates to the web dashboard.

## Implemented

- Added `/api/events/live` Server-Sent Events endpoint.
- Dashboard now connects with `EventSource`.
- Latest Events panel updates without manual refresh.
- Added live connection status indicator.

## Verification

- `node --check apps/dashboard/server.js`
- `node --check apps/dashboard/public/app.js`
- `curl -s http://127.0.0.1:8787/api/events`
- `timeout 8 curl -N http://127.0.0.1:8787/api/events/live`
- test event logged with `./runners/log_event.sh`

## Status

Implemented.
