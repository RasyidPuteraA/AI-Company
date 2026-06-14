# INTERNAL-090: Floating Owner Approval Notification Widget

## Summary

Added a floating dashboard widget for owner-action items so approvals, failures, blocked tasks, revision requests, and autonomous failure items are visible outside the latest-task panels.

## Backend

New endpoints:

    GET /api/owner/attention
    POST /api/owner/decision

`GET /api/owner/attention` returns owner attention items from `tasks`, `projects`, recent `events`, and pending `approvals`. It includes:

- `WAITING_OWNER_ACCEPTANCE`
- `NEEDS_REVISION`
- `BLOCKED`
- `QA_FAILED`
- tasks with pending approval records
- recent failed or blocked `AUTO-*` task events

Returned text fields are redacted for common secret/token patterns before they reach the browser.

`POST /api/owner/decision` accepts:

    {
      "task_key": "CLIENT-1-REVIEW-001",
      "decision": "ACCEPT",
      "message": "Owner note"
    }

Valid decisions:

- `ACCEPT`
- `REJECT`
- `REVISION`

Validation:

- `task_key` must use uppercase letters, numbers, and dashes only.
- `REVISION` and `REJECT` require a non-empty message.
- messages are limited to 5000 characters.

Decision routing:

- review tasks in `WAITING_OWNER_ACCEPTANCE` use existing project review runners:
  - accept: `runners/owner_accept_and_finalize.sh`
  - revision/reject: `runners/owner_review_decision.sh`
- non-review tasks use existing generic owner review runner:
  - `runners/owner_review_task.sh`

## Frontend

Added a fixed bottom-right owner attention widget in `apps/dashboard/public/app.js` and `apps/dashboard/public/styles.css`.

Behavior:

- polls `/api/owner/attention` every 7 seconds
- compact collapsed card with badge count
- expandable list of owner attention cards
- each item shows task key, title, agent, project, status, priority, context, and recommended owner action
- supports Accept, Request Revision, and Reject
- revision/reject opens an inline textarea and blocks empty messages
- shows loading, success, and error states

## Safety

- no task is auto-accepted
- owner decisions require explicit button click
- no arbitrary shell command is built from user input
- runners are called by fixed script name with validated argument arrays
- common credential/token patterns are redacted from endpoint output
- existing owner review accept-finalize endpoint and legacy widget remain available

