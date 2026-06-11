# INTERNAL-027: Attach Uploads to PM Intake Context

## Goal

Add a safe runner to attach uploaded project files to PM intake task context so agents can see requirement files and client assets linked to a project.

## Implemented

Added runner:

- runners/attach_uploads_to_pm_context.sh

Runner usage:

    ./runners/attach_uploads_to_pm_context.sh <project_key> <task_key>

Example:

    ./runners/attach_uploads_to_pm_context.sh client-company-profile-demo CLIENT-1-001

Behavior:

- reads uploaded file metadata from project_uploads
- appends upload context to the PM intake task file
- appends upload context summary to project AGENT_HANDOVER.md
- logs uploads_attached_to_pm_context event

Updated project workspace:

- projects/clients/client-company-profile-demo/CLIENT-1-001.md
- projects/clients/client-company-profile-demo/AGENT_HANDOVER.md

## Verification

- bash -n runners/attach_uploads_to_pm_context.sh
- attached uploads to CLIENT-1-001
- verified task file includes Project Upload Attachments
- verified AGENT_HANDOVER includes upload context
- verified project_uploads metadata query
- event logged

## Status

Implemented.
