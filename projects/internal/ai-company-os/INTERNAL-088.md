# INTERNAL-088: Fix Scheduler Role Selection Nameref Shadowing

## Problem

The multi-agent scheduler was enabled and all roles were configured as enabled, but the scheduler reported:

```text
No enabled roles selected
Root Cause

select_internal_roles and select_client_roles accepted a nameref output array, but each function also declared a local array named roles.

When the caller passed roles as the output array, the local roles declaration shadowed the caller array. Selected roles were written into a local variable and disappeared when the function returned.

Fix

Renamed the internal candidate role arrays to role_order so the nameref output array is no longer shadowed.

Expected Result

When AI Company OS is ON and gates allow execution, the scheduler should select enabled roles and start role cycles instead of staying idle with No enabled roles selected.

Verification
bash -n runners/ai_company_multi_agent_scheduler.sh
./runners/pre_commit_check.sh
scheduler restart
AI Company OS ON
scheduler status check
