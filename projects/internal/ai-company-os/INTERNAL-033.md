# INTERNAL-033: Add QA Verification Runner v0

## Goal

Add a safe QA verification runner that reads QA task, PM analysis, and engineer implementation output, then generates a QA report and updates QA task status.

## Implemented

Added runner:

- runners/qa_verification_runner.sh

Runner usage:

    ./runners/qa_verification_runner.sh <project_key> <qa_task_key>

Example:

    ./runners/qa_verification_runner.sh client-company-profile-demo CLIENT-1-QA-001

Behavior:

- reads QA task file
- reads PM intake analysis
- reviews engineer implementation output under site/
- checks required output files
- runs node --check on site/app.js
- performs basic content checks on site/index.html
- generates QA report
- updates project AGENT_HANDOVER.md
- updates QA task status to QA_PASSED or QA_FAILED
- logs qa_verification_completed event

Generated demo output:

- projects/clients/client-company-profile-demo/QA_REPORT-CLIENT-1-QA-001.md

## Verification

- bash -n runners/qa_verification_runner.sh
- generated QA report for CLIENT-1-QA-001
- verified required files were checked
- verified site/app.js syntax check
- verified content checks
- verified QA task status updated
- event logged

## Status

Implemented.
