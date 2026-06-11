# INTERNAL-031: Generate Engineer and QA Tasks from PM Analysis

## Goal

Add a safe runner that reads PM intake analysis and creates initial Engineer and QA tasks for a client project.

## Implemented

Added runner:

- runners/generate_tasks_from_pm_analysis.sh

Runner usage:

    ./runners/generate_tasks_from_pm_analysis.sh <project_key> <source_pm_task_key>

Example:

    ./runners/generate_tasks_from_pm_analysis.sh client-company-profile-demo CLIENT-1-001

Behavior:

- reads PM intake analysis file
- creates Engineer implementation task
- creates QA verification task
- writes task files into project workspace
- appends generated task summary to project AGENT_HANDOVER.md
- avoids duplicate task creation if tasks already exist
- logs pm_generated_engineer_qa_tasks event

Generated tasks for demo:

- CLIENT-1-ENG-001
- CLIENT-1-QA-001

## Verification

- bash -n runners/generate_tasks_from_pm_analysis.sh
- generated Engineer and QA tasks from CLIENT-1-001 analysis
- verified tasks in database
- verified task files created
- verified project handover updated
- engineer_agent claim tested
- event logged

## Status

Implemented.
