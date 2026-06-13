# INTERNAL-083: Dashboard Realtime Refresh and Logged Dangerous Codex Exec Usage

## Status

Implemented.

## Dashboard Refresh Behavior

Dashboard panels now refresh independently:

- summary cards: every 5 seconds
- AI Company OS, scheduler, and learning status: every 5 seconds
- agent runtime status: every 5 seconds
- latest tasks: every 10 seconds
- latest events: SSE remains enabled, with 10 second polling fallback
- Codex usage card: every 30 seconds

Panels include lightweight last-updated timestamps where practical.

Task classification now treats:

- client tasks: not `INTERNAL-*` and not `AUTO-*`
- internal tasks: `INTERNAL-*`
- autonomous tasks: `AUTO-*`

Agent runtime display clears completed/idle/failed task keys so an old completed task is not shown as active work.

## Dangerous Codex Exec Tracking

Owner-approved broad Codex access is preserved. The new logged runner calls:

```bash
codex exec --dangerously-bypass-approvals-and-sandbox "$PROMPT"
```

Use this command for future direct dangerous Codex runs:

```bash
./runners/codex_exec_danger_logged.sh \
  --agent-key engineer_agent \
  --task-key INTERNAL-083 \
  --prompt-file /tmp/ai-company-internal-083-codex-prompt.md
```

The runner writes terminal output to:

```text
company/runtime/codex_runs/YYYY-MM-DD/
```

It appends metadata to:

```text
company/runtime/codex_usage.jsonl
```

Recorded fields include timestamp, agent key, task key, mode, dangerous command name, prompt/output character counts, estimated prompt/output/total tokens, exit status, run seconds, and output path.

Token counts from this runner are internal chars/4 estimates. They are not official OpenAI billing usage and not official remaining quota.

## Usage Reconciliation

Added:

```bash
./runners/codex_usage_reconcile.sh
```

The reconciliation report is written to:

```text
company/reports/codex-usage/
```

It shows wrapper tracked usage, `direct_danger_logged` usage, estimated total usage, and recent records. It avoids double counting duplicate ledger rows by created time, agent, task, mode, and output path.

## Historical Limitation

Previous raw direct runs that used:

```bash
codex exec --dangerously-bypass-approvals-and-sandbox ...
```

without going through the ledger cannot be reconstructed exactly. Future runs should use `./runners/codex_exec_danger_logged.sh` to keep the same broad access while making usage visible.

## Dashboard Codex Usage

The Codex token card now includes the existing wrapper ledger and future `direct_danger_logged` estimates. It shows source breakdown and the note:

```text
Internal AI Company Codex CLI budget estimate, not official OpenAI remaining quota.
```

## Verification

Run:

```bash
bash -n runners/codex_exec_danger_logged.sh runners/codex_usage_reconcile.sh runners/codex_usage_report.sh
node --check apps/dashboard/server.js
./runners/dashboard_health_check.sh
./runners/codex_usage_report.sh
./runners/codex_usage_reconcile.sh
./runners/pre_commit_check.sh
git status --short
git diff --stat
```
