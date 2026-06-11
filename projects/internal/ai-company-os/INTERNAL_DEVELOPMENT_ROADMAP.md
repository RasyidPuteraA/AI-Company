# AI Company OS Internal Development Roadmap

## Purpose

This roadmap defines safe, incremental internal improvements for AI Company OS. It focuses on better reporting, security posture, dashboard visibility, backup readiness, and automation while avoiding direct infrastructure, production, secret, firewall, SSH, Docker daemon, and destructive database changes.

## Operating Principles

- Keep changes scoped to project-owned files and documented workflows.
- Prefer read-only checks, generated reports, and reversible application changes.
- Treat production, secrets, firewall, SSH, Docker daemon, database deletion, volume deletion, and deployment changes as proposal-only work.
- Add tests or validation steps whenever scripts, automation, or application behavior changes.
- Record build, test, and check results in handover notes for every internal task.

## Priority 1: Reporting

### Objectives

- Make project health visible without requiring direct access to infrastructure or secrets.
- Standardize internal status reports so future agents and maintainers can compare progress over time.

### Work Items

1. Create a recurring internal status report template covering uptime observations, task status, known risks, unresolved blockers, and next actions.
2. Add a lightweight project inventory document that lists owned services, repos, dashboards, scheduled jobs, and responsible maintainers when known.
3. Define report retention and naming conventions for generated internal reports.
4. Add validation guidance for report-generating scripts, including dry-run behavior and sample output checks.

### Deliverables

- `docs/reporting/status-report-template.md`
- `docs/reporting/project-inventory.md`
- Optional future script proposal for read-only report generation.

## Priority 2: Security

### Objectives

- Improve security hygiene through documentation, reviews, and safe checks.
- Avoid secret access and avoid system-level security changes unless approved through a proposal.

### Work Items

1. Document a security review checklist for code, configuration, access assumptions, dependency changes, and logging.
2. Add guidance for secret-safe development, including what not to read, print, commit, or copy.
3. Define a process for proposing infrastructure-sensitive changes such as SSH, firewall, Docker daemon, PostgreSQL, Redis, or production network changes.
4. Add dependency review notes for future package changes, including license, maintenance, and necessity checks.

### Deliverables

- `docs/security/security-review-checklist.md`
- `docs/security/secret-safe-development.md`
- `docs/security/infrastructure-change-proposal-template.md`

## Priority 3: Dashboard

### Objectives

- Improve visibility into AI Company OS status and internal operations.
- Keep dashboard changes application-level and avoid direct production deployment.

### Work Items

1. Define dashboard requirements for service status, recent task activity, report freshness, backup status, and automation run history.
2. Create wireframe-level documentation for the first internal dashboard view.
3. Identify safe data sources that do not require secrets or privileged system access.
4. Add acceptance criteria for dashboard updates, including loading, empty, error, and stale-data states.

### Deliverables

- `docs/dashboard/dashboard-requirements.md`
- `docs/dashboard/internal-dashboard-wireframe.md`
- Future implementation ticket for application-level dashboard changes.

## Priority 4: Backup

### Objectives

- Improve backup confidence through documentation and verification plans.
- Avoid destructive database, Docker volume, and production operations.

### Work Items

1. Document current backup assumptions and unknowns without accessing secrets or production systems.
2. Create a backup verification checklist that separates safe read-only checks from infrastructure tasks requiring approval.
3. Define restore-test planning requirements for non-production environments.
4. Add handover requirements for any future backup-related script or process change.

### Deliverables

- `docs/backup/backup-assumptions.md`
- `docs/backup/backup-verification-checklist.md`
- `docs/backup/restore-test-plan-template.md`

## Priority 5: Automation

### Objectives

- Automate repetitive internal work safely.
- Ensure automation defaults to dry-run or read-only behavior unless explicitly approved.

### Work Items

1. Document automation candidates: report generation, stale task detection, documentation index generation, and local validation checks.
2. Define automation safety requirements: dry-run mode, clear logging, no secret output, no production deployment, and explicit confirmation for irreversible work.
3. Add a validation matrix for automation scripts covering local checks, sample fixtures, and failure behavior.
4. Create a backlog for future scripts with risk levels and required approvals.

### Deliverables

- `docs/automation/automation-candidates.md`
- `docs/automation/automation-safety-requirements.md`
- `docs/automation/validation-matrix.md`

## Proposed Milestones

### Milestone 1: Documentation Foundation

- Add reporting, security, backup, dashboard, and automation documentation templates.
- Create a documentation index for internal operators.
- Define handover expectations for future internal tasks.

### Milestone 2: Safe Local Checks

- Add read-only local validation scripts only after documentation is accepted.
- Ensure every script supports dry-run behavior and has sample output.
- Add tests or fixture-based checks for each script.

### Milestone 3: Application Visibility

- Implement dashboard changes using safe application-level data sources.
- Add clear stale, missing, and error states.
- Avoid deployment until separately approved.

### Milestone 4: Operational Readiness

- Formalize backup verification and restore-test planning.
- Convert infrastructure-sensitive work into proposals.
- Track recurring internal reports and automation outcomes.

## Risk Handling

| Area | Safe Work | Proposal-Only Work |
| --- | --- | --- |
| Reporting | Templates, local report formats, read-only summaries | Production monitoring integration requiring credentials |
| Security | Checklists, dependency review notes, secret-safe guidance | SSH, firewall, access policy, or daemon changes |
| Dashboard | Requirements, wireframes, app-level changes | Production deployment or privileged metrics access |
| Backup | Verification plans and non-production restore planning | Database deletion, volume operations, production restore |
| Automation | Dry-run local scripts and tests | Destructive jobs, production scheduling, privileged system tasks |

## Immediate Next Steps

1. Create the documentation foundation files listed in Milestone 1.
2. Review the security and automation safety requirements before adding any scripts.
3. Convert any infrastructure-sensitive item into a proposal instead of executing it.
4. Keep `AGENT_HANDOVER.md` updated with task notes and validation results.
