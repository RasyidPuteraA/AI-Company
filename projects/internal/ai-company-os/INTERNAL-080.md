# INTERNAL-080: Multi-Agent Autonomous Operations Scheduler

## Goal

Move AI Company OS from a mostly single-lane autonomous issue loop to bounded multi-agent autonomous operations.

When AI Company OS is ON, a scheduler may run PM, Engineer, QA, and DevOps role cycles in parallel when their work domains do not conflict. Owner control remains the existing ON/OFF switch, with work hours, budget STOP, emergency stop, and safety guards still enforced.

## Added Components

- `company/config/ai_company_scheduler.env`
- `company/runtime/locks/`
- `runners/ai_company_lock.sh`
- `runners/ai_company_multi_agent_scheduler.sh`
- `runners/ai_company_role_cycle.sh`
- `runners/ai_company_scheduler_status.sh`
- `runners/install_ai_company_scheduler_service.sh`

Dashboard status now includes scheduler state, latest role-cycle state, and lock state via the existing AI Company OS status endpoint.

## Scheduler Behavior

The scheduler exits or pauses when:

- AI Company OS owner switch is OFF
- `AI_COMPANY_SCHEDULER_ENABLED` is not `1`
- `AI_COMPANY_AGENT_EMERGENCY_STOP=1`
- work-hours gate blocks execution
- budget gate returns STOP

When client tasks are pending and `AI_COMPANY_CLIENT_PRIORITY=1`, the scheduler runs client role cycles first. Internal idle work is only selected when no client work is pending and `AI_COMPANY_INTERNAL_IDLE_WORK_ENABLED=1`.

Default parallelism is conservative:

```sh
AI_COMPANY_MAX_PARALLEL_AGENTS=2
AI_COMPANY_SCHEDULER_MAX_ITERATIONS=1
```

Internal idle cycles use a round-robin cursor so PM, Engineer, QA, and DevOps all receive turns across repeated scheduler cycles even with a parallel limit of 2.

## Role Behavior

PM:

- client mode: claims PM client intake tasks, runs PM analysis, generates Engineer/QA tasks, marks PM task done
- internal mode: checks owner inbox/client intake queue and logs a planning review event

Engineer:

- client mode: claims Engineer client implementation tasks and runs the implementation runner
- internal mode: claims existing AUTO tasks for safe autonomous code development, or creates one bounded discovery task if no AUTO task is claimable

QA:

- client mode: claims QA client verification tasks and runs the QA verification runner
- internal mode: runs `pre_commit_check.sh`

DevOps:

- client mode: claims DevOps tasks and runs non-destructive service health checks
- internal mode: runs dashboard and agent service health checks

## Locks

Shared resources are protected with `flock`:

- repo writes: `company/runtime/locks/repo_write.lock`
- dashboard work: `company/runtime/locks/dashboard.lock`
- DevOps/service work: `company/runtime/locks/devops.lock`
- database work: `company/runtime/locks/database.lock`
- QA verification: `company/runtime/locks/qa.lock`

Repo-writing role cycles use the repo lock. DevOps/service cycles use the DevOps lock. QA verification uses the QA lock and, when writing reports, the repo lock.

## Manual Commands

Run one bounded scheduler cycle:

```sh
./runners/ai_company_multi_agent_scheduler.sh
```

Run one specific role cycle:

```sh
./runners/ai_company_role_cycle.sh engineer internal
./runners/ai_company_role_cycle.sh qa client
```

Check scheduler status:

```sh
./runners/ai_company_scheduler_status.sh
./runners/ai_company_scheduler_status.sh --json
./runners/ai_company_os_status.sh
```

Install the optional systemd service file without enabling or starting it:

```sh
sudo ./runners/install_ai_company_scheduler_service.sh
```

Owner-controlled service commands after install:

```sh
sudo systemctl enable ai-company-multi-agent-scheduler.service
sudo systemctl start ai-company-multi-agent-scheduler.service
systemctl status ai-company-multi-agent-scheduler.service --no-pager
```

## Safety Notes

- The installer does not enable or start systemd automatically.
- Auto-code development still requires the existing clean-tree, raw asset, pre-commit, and secret/path guards.
- The scheduler does not remove the owner review/client workflow.
- DevOps role cycles are non-destructive health checks unless future owner-approved tasks add bounded service changes.
