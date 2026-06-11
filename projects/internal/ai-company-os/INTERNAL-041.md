# INTERNAL-041: Improve Dashboard UX v1

## Goal

Improve dashboard UX based on owner feedback:

- resize office map so it fills the main frame
- replace Health panel with VPS Performance
- show CPU, RAM, Storage, and Uptime metrics
- add hide/unhide button for VPS Performance
- soften and restyle scrollbars

## Implemented

Updated:

- apps/dashboard/server.js
- apps/dashboard/public/index.html
- apps/dashboard/public/app.js
- apps/dashboard/public/styles.css

## Added API

- GET /api/system/metrics

Metrics returned:

- CPU usage percent
- CPU load
- CPU cores
- RAM usage
- Disk/storage usage
- VPS uptime
- timestamp

## UI Changes

- Office map expanded to fill the main dashboard frame
- Health panel renamed to VPS Performance
- VPS Performance can be hidden/unhidden
- Performance bars added for CPU, RAM, and Storage
- Scrollbar styling made thinner and darker

## Verification

- node --check apps/dashboard/server.js
- node --check apps/dashboard/public/app.js
- dashboard service restarted
- /api/system/metrics tested
- /api/summary tested
- browser hard refresh tested

## Status

Implemented.
