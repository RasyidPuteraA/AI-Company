#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG_FILE="company/config/ai_company_scheduler.env"
ENV_STALE_ENABLED="${AI_COMPANY_STALE_TASK_RECOVERY_ENABLED:-}"
ENV_STALE_AGE_HOURS="${AI_COMPANY_STALE_TASK_AGE_HOURS:-}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1091
  source "$CONFIG_FILE"
fi
[ -n "$ENV_STALE_ENABLED" ] && AI_COMPANY_STALE_TASK_RECOVERY_ENABLED="$ENV_STALE_ENABLED"
[ -n "$ENV_STALE_AGE_HOURS" ] && AI_COMPANY_STALE_TASK_AGE_HOURS="$ENV_STALE_AGE_HOURS"

: "${AI_COMPANY_STALE_TASK_RECOVERY_ENABLED:=1}"
: "${AI_COMPANY_STALE_TASK_AGE_HOURS:=24}"

RUNTIME_MODE=0
REPORT_DIR="company/reports/stale-task-recovery"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --runtime)
      RUNTIME_MODE=1
      REPORT_DIR="company/runtime/stale-task-recovery"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./runners/stale_task_recovery_plan.sh [--runtime]

Generate a stale task recovery plan. Use --runtime for scheduler cycle
artifacts that should not dirty the tracked repo.
EOF
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ "$AI_COMPANY_STALE_TASK_RECOVERY_ENABLED" != "1" ]; then
  echo "Stale task recovery planning is disabled by AI_COMPANY_STALE_TASK_RECOVERY_ENABLED."
  exit 0
fi

if ! [[ "$AI_COMPANY_STALE_TASK_AGE_HOURS" =~ ^[0-9]+$ ]] || [ "$AI_COMPANY_STALE_TASK_AGE_HOURS" -lt 1 ]; then
  echo "ERROR: AI_COMPANY_STALE_TASK_AGE_HOURS must be a positive integer." >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"

STAMP="$(date +%Y%m%dT%H%M%S%z)"
REPORT="$REPORT_DIR/${STAMP}-stale-task-recovery-plan.md"
LATEST="$REPORT_DIR/latest.md"

read -r -d '' STALE_SQL <<SQL || true
WITH in_progress AS (
  SELECT
    t.task_key,
    t.title,
    COALESCE(t.assigned_agent_key, '') AS agent,
    t.status,
    t.updated_at,
    FLOOR(EXTRACT(EPOCH FROM (now() - t.updated_at)) / 3600)::int AS age_hours,
    CASE
      WHEN t.task_key LIKE 'INTERNAL-%' THEN 'internal'
      WHEN t.task_key LIKE 'AUTO-%' THEN 'auto'
      ELSE 'client'
    END AS task_category,
    EXISTS (
      SELECT 1
      FROM agent_runtime_status ars
      WHERE ars.current_task_key = t.task_key
        AND LOWER(ars.runtime_status) NOT IN ('idle', 'done', 'completed', 'failed')
    ) AS has_active_runtime,
    false AS has_active_lock
  FROM tasks t
  WHERE t.status = 'IN_PROGRESS'
)
SELECT
  i.task_key,
  i.title,
  i.agent,
  i.status,
  i.updated_at,
  i.age_hours,
  i.task_category,
  i.has_active_runtime,
  i.has_active_lock,
  CASE
    WHEN i.age_hours < $AI_COMPANY_STALE_TASK_AGE_HOURS THEN 'keep_if_recent'
    WHEN i.task_category = 'client' THEN 'stale_client_owner_review'
    WHEN i.has_active_runtime THEN
      CASE WHEN i.task_category = 'auto' THEN 'stale_auto_review' ELSE 'stale_internal_review' END
    ELSE 'release_claim_if_safe'
  END AS recommended_action
FROM in_progress i
ORDER BY i.age_hours DESC, i.updated_at ASC, i.task_key ASC
SQL

{
  echo "# Stale Task Recovery Plan"
  echo
  echo "- generated_at: $(date -Iseconds)"
  echo "- mode: report-only"
  echo "- output_scope: $([ "$RUNTIME_MODE" = "1" ] && echo runtime || echo tracked-report)"
  echo "- threshold_hours: $AI_COMPANY_STALE_TASK_AGE_HOURS"
  echo "- report_path: $REPORT"
  echo
  echo "## Safety"
  echo
  echo "- This runner does not mutate task status."
  echo "- Client tasks are owner-review only."
  echo "- Stale tasks are not marked DONE automatically."
  echo "- Tasks are not deleted."
  echo
  echo "## IN_PROGRESS Tasks"
  echo
  docker exec ai_company_postgres psql -U ai_company -d ai_company -P pager=off -c "$STALE_SQL"
  echo
  echo "## Counts"
  echo
  docker exec ai_company_postgres psql -U ai_company -d ai_company -P pager=off -c "
WITH plan AS ($STALE_SQL)
SELECT
  task_category,
  recommended_action,
  count(*) AS task_count
FROM plan
GROUP BY task_category, recommended_action
ORDER BY task_category, recommended_action;
"
} | tee "$REPORT"

cp "$REPORT" "$LATEST"

COUNT="$(docker exec ai_company_postgres psql -U ai_company -d ai_company -t -A -c "
SELECT count(*)
FROM tasks
WHERE status = 'IN_PROGRESS'
  AND updated_at < now() - interval '$AI_COMPANY_STALE_TASK_AGE_HOURS hours';
" | tr -d '[:space:]')"

./runners/log_event.sh \
  internal-ai-company-os \
  INTERNAL-086 \
  devops_agent \
  stale_task_recovery_plan \
  REPORT_ONLY \
  operations \
  "Stale task recovery plan generated" \
  "Found ${COUNT:-0} stale IN_PROGRESS task(s); report: $REPORT" >/dev/null 2>&1 || true

echo
echo "Report written: $REPORT"
