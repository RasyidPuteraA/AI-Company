#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SINCE_REF=""
SERVICES_ONLY=0
REPORT_DIR="company/reports/post-update"
RUNTIME_MODE=0

# shellcheck source=runners/ai_company_generated_path_classifier.sh
source ./runners/ai_company_generated_path_classifier.sh

while [ "$#" -gt 0 ]; do
  case "$1" in
    --since-ref)
      SINCE_REF="${2:-}"
      if [ -z "$SINCE_REF" ]; then
        echo "ERROR: --since-ref requires a ref." >&2
        exit 2
      fi
      shift 2
      ;;
    --services-only)
      SERVICES_ONLY=1
      shift
      ;;
    --runtime)
      RUNTIME_MODE=1
      REPORT_DIR="company/runtime/post-update"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./runners/post_update_service_plan.sh [--since-ref REF] [--runtime]

Detect changed files and report which AI Company OS systemd services would need
a post-update restart. This runner is report-only. Use --runtime for scheduler
cycle artifacts that should not dirty the tracked repo.
EOF
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

mkdir -p "$REPORT_DIR"

changed_files() {
  if [ -n "$SINCE_REF" ]; then
    git diff --name-only "$SINCE_REF"...HEAD 2>/dev/null || git diff --name-only "$SINCE_REF" HEAD 2>/dev/null || true
  fi

  git diff --name-only 2>/dev/null || true
  git diff --cached --name-only 2>/dev/null || true
  git status --porcelain=v1 2>/dev/null | while IFS= read -r line; do
    path="${line:3}"
    case "$path" in
      *" -> "*) printf "%s\n" "${path##* -> }" ;;
      *) printf "%s\n" "$path" ;;
    esac
  done
}

service_category() {
  case "$1" in
    ai-company-dashboard.service) printf "dashboard" ;;
    ai-company-multi-agent-scheduler.service) printf "scheduler" ;;
    ai-company-agent@*) printf "agent" ;;
    *) printf "unknown" ;;
  esac
}

add_service() {
  local service="$1"
  local -n add_services_ref="$2"
  local existing
  for existing in "${add_services_ref[@]}"; do
    [ "$existing" = "$service" ] && return 0
  done
  add_services_ref+=("$service")
}

affected_services_for_file() {
  local file="$1"
  local -n affected_services_ref="$2"

  case "$file" in
    apps/dashboard/server.js|apps/dashboard/package.json|apps/dashboard/package-lock.json|apps/dashboard/public/*)
      add_service "ai-company-dashboard.service" affected_services_ref
      ;;
    runners/ai_company_multi_agent_scheduler.sh|runners/ai_company_role_cycle.sh|runners/ai_company_scheduler_status.sh|runners/ai_company_work_hours_gate.sh|company/config/ai_company_scheduler.env|company/config/ai_company_os.env)
      add_service "ai-company-multi-agent-scheduler.service" affected_services_ref
      ;;
    runners/agent_worker_loop.sh|runners/agent_worker_loop_with_codex.sh|runners/agent_worker_once.sh|runners/agent_worker_once_with_codex.sh|runners/autonomous_agent_dispatcher.sh|runners/autonomous_codex_dispatcher_hook.sh)
      add_service "ai-company-agent@pm_agent.service" affected_services_ref
      add_service "ai-company-agent@engineer_agent.service" affected_services_ref
      add_service "ai-company-agent@qa_agent.service" affected_services_ref
      add_service "ai-company-agent@devops_agent.service" affected_services_ref
      ;;
  esac
}

mapfile -t files < <(
  changed_files | sed '/^[[:space:]]*$/d' | sort -u | while IFS= read -r file; do
    if ! ai_company_generated_path "$file"; then
      printf "%s\n" "$file"
    fi
  done
)
services=()
for file in "${files[@]}"; do
  affected_services_for_file "$file" services
done

timestamp="$(date -Iseconds)"
stamp="$(date +%Y%m%dT%H%M%S%z)"
report="$REPORT_DIR/${stamp}-service-plan.md"

{
  echo "# Post-Update Service Restart Plan"
  echo "- generated_at: $timestamp"
  echo "- mode: report-only"
  echo "- output_scope: $([ "$RUNTIME_MODE" = "1" ] && echo runtime || echo tracked-report)"
  echo "- since_ref: ${SINCE_REF:-none}"
  echo
  echo "## Changed Files"
  if [ "${#files[@]}" -eq 0 ]; then
    echo "- none"
  else
    for file in "${files[@]}"; do
      echo "- $file"
    done
  fi
  echo
  echo "## Affected Services"
  if [ "${#services[@]}" -eq 0 ]; then
    echo "- none"
  else
    for service in "${services[@]}"; do
      echo "- $service ($(service_category "$service"))"
    done
  fi
  echo
  echo "## Decision"
  if [ "${#services[@]}" -eq 0 ]; then
    echo "No restart is needed for the detected file changes."
  else
    echo "Restart candidates were detected. This plan did not restart anything."
  fi
} > "$report"

if [ "$SERVICES_ONLY" = "1" ]; then
  printf "%s\n" "${services[@]}"
  exit 0
fi

echo "# Post-Update Service Restart Plan"
echo "- report: $report"
echo "- mode: report-only"
echo
if [ "${#services[@]}" -eq 0 ]; then
  echo "No affected services."
  exit 0
fi

echo "Affected services:"
printf -- "- %s\n" "${services[@]}"
