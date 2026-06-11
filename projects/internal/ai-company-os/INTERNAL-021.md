# INTERNAL-021: Show Agent Runtime Status on Dashboard

## Goal

Add agent runtime status API and dashboard panel so the web dashboard can display each agent current runtime status.

## Implemented

Added API endpoint:

- /api/agents/runtime

Updated dashboard:

- added Agent Runtime Status panel
- shows agent key
- shows runtime status
- shows current task key
- shows status note
- refreshes runtime status periodically

Updated files:

- apps/dashboard/server.js
- apps/dashboard/public/index.html
- apps/dashboard/public/styles.css
- apps/dashboard/public/app.js

## Verification

- node --check apps/dashboard/server.js
- node --check apps/dashboard/public/app.js
- sudo systemctl restart ai-company-dashboard
- curl -s http://127.0.0.1:8787/api/agents/runtime
- runtime status update tested with update_agent_runtime_status.sh

## Status

Implemented.
