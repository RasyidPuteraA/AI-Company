#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

MAX_AGE_HOURS="${1:-8}"
REPORT_DIR="company/reports/ops"
mkdir -p "$REPORT_DIR"
OUT="$REPORT_DIR/$(date +%F)-stale-internal-tasks.md"

echo "# Stale Internal Task Recovery Guard" > "$OUT"
echo >> "$OUT"
echo "Generated at: $(date)" >> "$OUT"
echo "Max age hours: $MAX_AGE_HOURS" >> "$OUT"
echo >> "$OUT"

docker exec ai_company_postgres psql -U ai_company -d ai_company -c "
SELECT
  task_key,
  title,
  status,
  assigned_agent_key AS agent,
  priority,
  updated_at,
  now() - updated_at AS stale_for,
  coalesce(handover_note, '') AS note
FROM tasks
WHERE task_key LIKE 'INTERNAL-%'
  AND status = 'IN_PROGRESS'
  AND updated_at < now() - interval '${MAX_AGE_HOURS} hours'
ORDER BY updated_at ASC;
" | tee -a "$OUT"

COUNT="$(docker exec ai_company_postgres psql -U ai_company -d ai_company -At -c "
SELECT count(*)
FROM tasks
WHERE task_key LIKE 'INTERNAL-%'
  AND status = 'IN_PROGRESS'
  AND updated_at < now() - interval '${MAX_AGE_HOURS} hours';
" | tr -d '[:space:]')"

echo >> "$OUT"
echo "## Result" >> "$OUT"
echo >> "$OUT"

if [ "$COUNT" -gt 0 ]; then
  echo "Found $COUNT stale internal task(s)." | tee -a "$OUT"
  echo "Recommendation: review stale tasks, then either resume, split, close, or reassign manually." | tee -a "$OUT"
else
  echo "No stale internal tasks found." | tee -a "$OUT"
fi

echo
echo "Report written:"
echo "$OUT"
