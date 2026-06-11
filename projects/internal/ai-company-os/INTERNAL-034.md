# INTERNAL-034: Submit QA-Passed Project to Owner Review

## Goal

Add a safe runner that submits a QA-passed client project output to Owner review queue with project summary, QA report, and implementation output path.

## Implemented

Added runner:

- runners/submit_project_to_owner_review.sh

Runner usage:

    ./runners/submit_project_to_owner_review.sh <project_key> <qa_task_key>

Example:

    ./runners/submit_project_to_owner_review.sh client-company-profile-demo CLIENT-1-QA-001

Behavior:

- verifies QA task status is QA_PASSED
- creates owner review task
- sets review task status to WAITING_OWNER_ACCEPTANCE
- writes owner review markdown file into project workspace
- appends owner review submission note to project AGENT_HANDOVER.md
- logs submitted_to_owner_review event

Generated demo review task:

- CLIENT-1-REVIEW-001

## Verification

- bash -n runners/submit_project_to_owner_review.sh
- submitted QA-passed demo project to Owner review
- verified owner review task status WAITING_OWNER_ACCEPTANCE
- verified owner review markdown file created
- verified project handover updated
- verified owner inbox shows review task
- event logged

## Status

Implemented.
