# INTERNAL-010: Run Web Dashboard as Managed Service

## Goal

Run the web dashboard as a managed local-only service.

## Implemented

- Updated dashboard server to listen on `127.0.0.1` by default.
- Added systemd service:
  - `ai-company-dashboard.service`
- Dashboard runs on:
  - `http://127.0.0.1:8787`
- Access remains through SSH tunnel for safety.

## Verification

- `node --check apps/dashboard/server.js`
- `sudo systemctl status ai-company-dashboard --no-pager`
- `curl -s http://127.0.0.1:8787/api/summary`

## Status

Implemented.
