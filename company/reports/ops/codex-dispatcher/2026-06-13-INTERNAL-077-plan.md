# Codex Dispatcher Plan: INTERNAL-077

Generated at: Sat Jun 13 06:20:43 PM WIB 2026
Agent: engineer_agent

# Codex Agent Run
- Agent: engineer_agent
- Task: INTERNAL-077
- Mode: plan
- Today used before run: 30246 / 500000
OpenAI Codex v0.139.0
--------
workdir: /opt/ai-company
model: gpt-5.5
provider: openai
approval: never
sandbox: read-only
reasoning effort: none
reasoning summaries: none
session id: 019ec0b6-7dbf-7fd0-8cf3-e1d764aa6a46
--------
user
You are engineer_agent in AI Company OS.

Task:
- key: INTERNAL-077
- title: Add Autonomous Issue Discovery and Self-Directed Fix Loop
- status: IN_PROGRESS
- phase: INTERNAL_DEVELOPMENT
- priority: HIGH
- note: Claimed by engineer_agent at 2026-06-13 11:20:42.028205+00

Operating rules:
- Do not expose secrets.
- Do not edit Codex auth files.
- Do not finalize client work without Owner approval.
- Prefer safe, minimal, auditable changes.
- If implementation is needed, propose exact files and commands.
- If this is an internal improvement, keep it bounded and reversible.
- End with a concise handover summary.

Repository context:
- repo: /opt/ai-company
- use pre-commit check before commits:
  ./runners/pre_commit_check.sh

Create a short implementation plan for this task.
Do not modify files.
Return:
1. understanding
2. proposed files
3. safety checks
4. next command recommendation
warning: Codex's Linux sandbox uses bubblewrap and needs access to create user namespaces.
codex
I’ll inspect the repo structure and any existing internal task/runner patterns so the plan names the right files without changing anything.
codex
1. **Understanding**

`INTERNAL-077` should add a bounded internal loop that can discover likely issues autonomously, select a safe fix candidate, apply or propose a minimal change, run validation, and stop with an auditable report. Since this is internal infrastructure, the first implementation should be conservative: discovery-only or dry-run by default, explicit allowlists for editable paths, and no client-work finalization without Owner approval.

I could not inspect the repo because the sandbox command runner failed with `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`, so the file list below is a proposed target set to verify before editing.

2. **Proposed Files**

Likely files to inspect first:

- `runners/pre_commit_check.sh`
- existing `runners/*` scripts
- any task/agent orchestration files under likely paths such as:
  - `agents/`
  - `company_os/`
  - `internal/`
  - `tasks/`
  - `workflows/`
  - `docs/`

Likely files to add or modify after inspection:

- Add: `runners/autonomous_issue_loop.sh`
- Add or modify: internal agent/workflow module that performs:
  - issue discovery
  - candidate ranking
  - bounded fix execution
  - validation
  - handover report
- Add: tests for dry-run behavior, path allowlisting, stop conditions, and validation failure handling
- Add or update: docs/runbook for the internal autonomous loop

3. **Safety Checks**

- Default to `--dry-run`; require an explicit flag for write mode.
- Restrict editable paths with an allowlist.
- Never read or modify Codex auth files, secrets, `.env`, credentials, or private keys.
- Log discovered issues and selected actions without exposing secret values.
- Stop after a small fixed number of iterations, for example `--max-iterations 1` initially.
- Require clean validation before marking an internal fix ready.
- Run `./runners/pre_commit_check.sh` before any commit.
- Do not finalize any client-facing work; produce an Owner-review handover instead.

4. **Next Command Recommendation**

Run this first to map the existing structure:

```bash
rg --files -g '!*node_modules*' -g '!*.pyc' | sed -n '1,200p'
```

Then inspect likely orchestration points:

```bash
rg -n "INTERNAL-|runner|agent|workflow|pre_commit|autonomous|issue discovery|self-directed|loop" .
```
tokens used
2,716
1. **Understanding**

`INTERNAL-077` should add a bounded internal loop that can discover likely issues autonomously, select a safe fix candidate, apply or propose a minimal change, run validation, and stop with an auditable report. Since this is internal infrastructure, the first implementation should be conservative: discovery-only or dry-run by default, explicit allowlists for editable paths, and no client-work finalization without Owner approval.

I could not inspect the repo because the sandbox command runner failed with `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`, so the file list below is a proposed target set to verify before editing.

2. **Proposed Files**

Likely files to inspect first:

- `runners/pre_commit_check.sh`
- existing `runners/*` scripts
- any task/agent orchestration files under likely paths such as:
  - `agents/`
  - `company_os/`
  - `internal/`
  - `tasks/`
  - `workflows/`
  - `docs/`

Likely files to add or modify after inspection:

- Add: `runners/autonomous_issue_loop.sh`
- Add or modify: internal agent/workflow module that performs:
  - issue discovery
  - candidate ranking
  - bounded fix execution
  - validation
  - handover report
- Add: tests for dry-run behavior, path allowlisting, stop conditions, and validation failure handling
- Add or update: docs/runbook for the internal autonomous loop

3. **Safety Checks**

- Default to `--dry-run`; require an explicit flag for write mode.
- Restrict editable paths with an allowlist.
- Never read or modify Codex auth files, secrets, `.env`, credentials, or private keys.
- Log discovered issues and selected actions without exposing secret values.
- Stop after a small fixed number of iterations, for example `--max-iterations 1` initially.
- Require clean validation before marking an internal fix ready.
- Run `./runners/pre_commit_check.sh` before any commit.
- Do not finalize any client-facing work; produce an Owner-review handover instead.

4. **Next Command Recommendation**

Run this first to map the existing structure:

```bash
rg --files -g '!*node_modules*' -g '!*.pyc' | sed -n '1,200p'
```

Then inspect likely orchestration points:

```bash
rg -n "INTERNAL-|runner|agent|workflow|pre_commit|autonomous|issue discovery|self-directed|loop" .
```

Codex usage logged:
- tokens_used: 2716
- exit_status: 0
- run_seconds: 51
- output_path: company/runtime/codex_runs/2026-06-13/20260613182044-engineer_agent-INTERNAL-077-plan.out
