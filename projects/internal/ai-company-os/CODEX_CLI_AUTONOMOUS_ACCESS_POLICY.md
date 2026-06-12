# AI Company OS Codex CLI Autonomous Access Policy

## Purpose

This policy defines Codex CLI as the approved model access path for AI Company OS autonomous agents.

## 1. Approved Model Access Method

AI Company OS agents may use Codex CLI authenticated through the Owner's ChatGPT subscription.

Approved method:

    Codex CLI -> Sign in with ChatGPT

Not the default method:

    OpenAI API key

API keys should only be introduced later if the Owner explicitly decides to use usage-based API billing.

## 2. Agent Role Mapping

pm_agent:

- requirements analysis
- project planning
- task breakdown
- backlog generation
- daily, 3-day, and weekly reports

engineer_agent:

- code implementation
- dashboard improvements
- runner improvements
- virtual office improvements
- internal tooling

qa_agent:

- test planning
- regression checks
- quality review
- safety verification
- report verification

devops_agent:

- VPS reliability planning
- service diagnostics
- health check improvements
- operational automation
- backup and recovery planning

## 3. Credential Rule

Agents must not store ChatGPT credentials, Codex tokens, API keys, passwords, or session secrets in:

- git
- markdown files
- shell scripts
- reports
- handover files
- task notes
- logs

Codex CLI authentication cache must be treated as secret.

Any local Codex credential file must never be committed, pasted, logged, or shared.

## 4. VPS Login Rule

Because the VPS is remote/headless, the Owner performs Codex CLI login manually once.

After login, agents may use the already-authenticated Codex CLI session.

## 5. Client Project Approval Gate

Codex-powered agents may work autonomously on client projects through:

- PM intake
- Engineer implementation
- QA verification
- Owner review submission

Client projects must stop at Owner review.

Agents must not finalize, publish, deliver, archive as completed, or mark client work as accepted without explicit Owner approval.

Required state before Owner decision:

    WAITING_OWNER_ACCEPTANCE

Allowed path:

    Owner Accepts -> Finalize Project -> Mark Completed

## 6. Idle Internal Improvement Mode

When no active client order exists and no Owner approval task is waiting, Codex-powered agents may improve the internal system.

Allowed idle work:

- VPS reliability
- dashboard UX
- agent workflow automation
- health checks
- safety guards
- reporting
- documentation
- QA tooling
- virtual office improvements

Client work always has priority over idle internal improvement.

## 7. Sudo Rule

Agents must not receive or store the sudo password.

If autonomous sudo access is needed, it must use a narrow sudoers allowlist for specific commands only.

Allowed examples:

- status checks for AI Company OS services
- restarting approved AI Company OS services
- reading relevant journal logs
- reloading systemd after approved service changes

Disallowed without Owner approval:

- unrestricted root shell
- changing SSH access
- opening public dashboard access
- deleting production data
- changing firewall rules
- changing root password
- disabling health checks
- disabling backups
- broad sudoers changes

## 8. Required Safety Checks

Before commits or operational changes, agents should run:

    ./runners/pre_commit_check.sh

For general health validation, agents should run:

    ./runners/health.sh

To verify Codex CLI access, agents should run:

    ./runners/codex_agent_check.sh

## Status

Active.
