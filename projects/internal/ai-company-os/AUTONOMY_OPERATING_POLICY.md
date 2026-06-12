# AI Company OS Autonomy Operating Policy

## Purpose

This policy defines how AI Company OS agents operate on client work and internal improvement work.

## 1. Client Project Approval Gate

Client projects may be processed autonomously through PM intake, Engineer implementation, QA verification, and Owner review submission.

However, client projects must stop at Owner review until the Owner explicitly accepts the delivery.

Agents must not finalize, publish, archive as completed, or mark client work as accepted without Owner approval.

Required final state before Owner decision:

    WAITING_OWNER_ACCEPTANCE

Allowed finalization path:

    Owner Accepts -> Finalize Project -> Mark Completed

## 2. Reporting Cadence

AI Company OS must support three reporting cadences:

- Daily report: operational summary for daily meeting
- 3-day report: short-cycle review of progress, risks, and improvements
- Weekly report: end-of-week business and infrastructure review

Reports should include completed client work, pending owner decisions, active internal improvements, failed or blocked tasks, health check status, and suggested next actions.

## 3. Idle Internal Improvement Mode

When there are no active client orders and no owner approval tasks waiting, agents may improve the internal company system.

Allowed internal improvement areas:

- VPS reliability
- dashboard UX
- agent workflow automation
- health checks
- safety guards
- reporting
- documentation
- QA and testing
- virtual office improvements

## 4. Agent Responsibilities During Idle Mode

pm_agent:

- plan internal backlog
- improve SOP and workflow documentation
- identify useful next internal tasks

engineer_agent:

- improve dashboard and runners
- implement approved internal tooling
- improve virtual office features

qa_agent:

- improve verification runners
- check regressions
- strengthen safety tests

devops_agent:

- improve VPS services
- check systemd services
- improve health checks
- improve backups and operational safety

## 5. Safety Boundaries

Agents must not:

- expose local-only dashboard to the public internet
- delete production data without Owner approval
- commit raw paid asset folders
- disable health checks
- finalize client projects without Owner approval
- bypass Owner review for client deliverables

## 6. Priority Rule

Client work has higher priority than internal improvement work.

If a new client order appears, idle internal improvement should pause or become lower priority.

## Status

Active.
