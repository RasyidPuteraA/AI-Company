# INTERNAL-022: Fix Dashboard Runtime Status API Route

## Goal

Fix dashboard server route for `/api/agents/runtime`.

## Problem

INTERNAL-021 added the dashboard frontend panel, but the API endpoint returned:

    Not found

The server route patch failed because the route variable could not be detected.

## Implemented

Updated:

- apps/dashboard/server.js

Behavior:

- `/api/agents/runtime` returns agent runtime status JSON
- dashboard frontend can load runtime status panel

## Verification

- node --check apps/dashboard/server.js
- sudo systemctl restart ai-company-dashboard
- curl -s http://127.0.0.1:8787/api/agents/runtime
- endpoint no longer returns Not found

## Status

Implemented.
