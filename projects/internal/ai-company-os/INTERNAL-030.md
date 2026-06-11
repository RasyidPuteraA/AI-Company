# INTERNAL-030: Add PM Intake Processor v0

## Goal

Add a safe PM intake processor runner that reads a client PM intake task and produces requirement analysis, implementation plan, and suggested task breakdown.

## Implemented

Added runner:

- runners/pm_intake_processor.sh

Runner usage:

    ./runners/pm_intake_processor.sh <project_key> <task_key>

Example:

    ./runners/pm_intake_processor.sh client-company-profile-demo CLIENT-1-001

Behavior:

- reads client PM intake task file
- reads task metadata from database
- reads uploaded project file metadata from project_uploads
- generates PM intake analysis markdown
- appends PM intake analysis note to project AGENT_HANDOVER.md
- avoids duplicating PM analysis handover note on repeated runs
- logs pm_intake_analysis_generated event

Generated output example:

- projects/clients/client-company-profile-demo/PM_INTAKE_ANALYSIS-CLIENT-1-001.md

## Verification

- bash -n runners/pm_intake_processor.sh
- generated PM intake analysis for CLIENT-1-001
- verified generated analysis includes requirement summary
- verified generated analysis includes uploaded file list
- verified generated analysis includes suggested engineer and QA task breakdown
- event logged

## Status

Implemented.
