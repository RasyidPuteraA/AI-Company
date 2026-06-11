# INTERNAL-035: Add Owner Review Decision Runner

## Goal

Add a safe runner that lets Owner accept, request revision, or reject a client project review task.

## Implemented

Added:

- runners/owner_review_decision.sh

## Usage

    ./runners/owner_review_decision.sh <review_task_key> <ACCEPT|REVISE|REJECT> [note]

Example:

    ./runners/owner_review_decision.sh CLIENT-1-REVIEW-001 ACCEPT "Approved for demo."

## Decision Mapping

- ACCEPT: task ACCEPTED, project ACCEPTED
- REVISE: task NEEDS_REVISION, project REVISION_REQUESTED
- REJECT: task REJECTED, project REJECTED

## Verified

- CLIENT-1-REVIEW-001 accepted
- client-company-profile-demo accepted
- owner decision file created
- project handover updated

## Status

Implemented.
