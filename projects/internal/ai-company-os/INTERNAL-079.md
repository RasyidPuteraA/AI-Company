# INTERNAL-079: Polish AI Company OS Autonomous Runtime State and Task Classification

## Summary

Polish the AI Company OS autonomous runtime added in INTERNAL-078 so owner OFF state, orchestrator lifecycle state, autonomous task classification, and scan exclusions are clear and safe.

## Requirements

- Owner switch OFF must persist `PAUSED_BY_OWNER`, clear `active_agent`, refresh `updated_at`, and preserve the latest OFF event.
- Orchestrator cycles must set `active_agent` only while work is active, then clear it for completion, skips, and failures.
- Unresolved `AUTO-*` tasks must block new discovery with a clear status/reason.
- `AUTO-*` tasks must be classified as autonomous/internal work, not client work.
- Repository context and scan helpers must avoid runtime/data paths including `data`, `node_modules`, `.git`, `company/runtime`, and autonomous discovery reports.
- Runtime autonomous discovery report directories must remain ignored without ignoring daily or ops reports.

## Implementation Notes

- `runners/ai_company_os_control.sh` now clears `AI_COMPANY_OS_ACTIVE_AGENT` on both ON/OFF control writes and stores a human-readable `AI_COMPANY_OS_STATUS_NOTE`.
- `runners/ai_company_autonomous_orchestrator.sh` now clears active agent on skip/failure/final states, keeps active agent only during scan/report/verify work, and records useful error/skip notes.
- Unresolved `AUTO-*` tasks now produce a clear skip reason naming the latest unresolved task when available.
- `runners/company_status.sh` excludes `AUTO-*` from client task count and client status, then displays autonomous internal tasks separately.
- `runners/owner_inbox.sh` keeps the existing owner views and adds a separate autonomous internal task section.
- `runners/autonomous_code_context.sh` prunes data/runtime/generated paths before scanning so context generation avoids permission denied warnings and ignores runtime discovery reports.

## Verification

Run:

```bash
bash -n runners/ai_company_os_control.sh runners/ai_company_autonomous_orchestrator.sh runners/ai_company_os_status.sh runners/company_status.sh runners/owner_inbox.sh runners/autonomous_code_context.sh
./runners/pre_commit_check.sh
./runners/ai_company_os_status.sh
./runners/company_status.sh
git status --short
git diff --stat
```

## Test Commands

```bash
./runners/ai_company_os_control.sh off
./runners/ai_company_os_status.sh
./runners/ai_company_os_control.sh on
./runners/ai_company_autonomous_orchestrator.sh
```
