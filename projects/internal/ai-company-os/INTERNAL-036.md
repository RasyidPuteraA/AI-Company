# INTERNAL-036: Add Final Project Completion Runner

## Goal

Add a safe runner that finalizes an accepted client project, writes final handover summary, and marks project as completed.

## Implemented

Added:

- runners/finalize_accepted_project.sh

## Usage

    ./runners/finalize_accepted_project.sh <project_key> <review_task_key>

Example:

    ./runners/finalize_accepted_project.sh client-company-profile-demo CLIENT-1-REVIEW-001

## Behavior

The runner:

- validates project exists
- validates review task is ACCEPTED
- validates project is ACCEPTED or already COMPLETED
- verifies implementation output exists
- verifies QA report exists
- verifies Owner decision file exists
- creates FINAL_HANDOVER.md
- updates project status to COMPLETED
- updates project phase to completed
- appends finalization note to project AGENT_HANDOVER.md
- logs project_completed event

## Demo Verification

Tested on:

- client-company-profile-demo
- CLIENT-1-REVIEW-001

Expected result:

- project status COMPLETED
- project phase completed
- FINAL_HANDOVER.md created

## Status

Implemented.
