# INTERNAL-037: Add Dashboard Workflow Action Buttons

## Goal

Add dashboard API actions and UI buttons for the end-to-end client workflow from PM analysis through final project completion.

## Implemented

Updated:

- apps/dashboard/server.js
- apps/dashboard/public/index.html
- apps/dashboard/public/app.js
- apps/dashboard/public/styles.css

## Added API

- POST /api/workflow/action

Supported actions:

- pm_analysis
- generate_tasks
- engineer_impl
- qa_verify
- submit_review
- owner_decision
- finalize

## Added UI

Dashboard panel:

- End-to-End Workflow Actions

Buttons:

- Run PM Analysis
- Generate Engineer/QA Tasks
- Run Engineer Implementation
- Run QA Verification
- Submit to Owner Review
- Run Owner Decision
- Finalize Project

## Verification

- node --check apps/dashboard/server.js
- node --check apps/dashboard/public/app.js
- dashboard service restarted
- /api/summary checked
- /api/workflow/action tested with finalize action
- UI markers verified with grep

## Status

Implemented.
