# INTERNAL-025: Convert Owner Command to Client Project v0

## Goal

Add a safe runner to convert an owner command from the dashboard inbox into a client project and initial implementation task.

## Implemented

Added migration:

- docker/postgres/004_owner_command_links.sql

Added runner:

- runners/convert_owner_command_to_project.sh

Updated runner:

- runners/create_task.sh

Behavior:

- reads owner command from owner_commands
- validates command id and project key
- creates client project row
- creates initial PM intake task
- creates dynamic client project workspace under projects/clients/<project_key>
- updates owner command status to CONVERTED after project and task exist
- stores project_key, task_key, and converted_at on owner_commands
- logs owner_command_converted event

Verified flow:

- Dashboard chatbox
- owner_commands
- convert owner command to project
- create client project
- create PM intake task
- PM agent claim

## Verification

- migration applied successfully
- bash -n runners/convert_owner_command_to_project.sh
- bash -n runners/create_task.sh
- converted owner command id 1
- verified owner_commands status changed to CONVERTED
- verified client project was created
- verified CLIENT-1-001 task was created
- verified PM agent claimed CLIENT-1-001

## Status

Implemented.
