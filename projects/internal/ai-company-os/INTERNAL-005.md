# INTERNAL-005: Add Owner Approval Workflow

## Goal

Add owner approval workflow so client tasks that pass QA move to `WAITING_OWNER_ACCEPTANCE` instead of directly becoming `DONE`.

## Implemented

- Updated `runners/run_qa.sh`
  - Internal tasks with QA PASS still become `DONE`
  - Client tasks with QA PASS now become `WAITING_OWNER_ACCEPTANCE`
  - QA failures still become `QA_FAILED`

- Added `runners/owner_review_task.sh`
  - `ACCEPT` moves task to `ACCEPTED`
  - `REVISION` moves task to `NEEDS_REVISION`
  - Logs owner review event into PostgreSQL

## Verification

- `bash -n runners/run_qa.sh`
- `bash -n runners/owner_review_task.sh`

## Status

Implemented.
