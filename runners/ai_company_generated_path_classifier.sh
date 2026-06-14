#!/usr/bin/env bash

ai_company_generated_path() {
  case "$1" in
    company/learning/*) return 0 ;;
    company/reports/learning/*) return 0 ;;
    company/reports/stale-task-recovery/*) return 0 ;;
    company/reports/post-update/*) return 0 ;;
    company/reports/autonomous-discovery/*) return 0 ;;
    company/runtime/*) return 0 ;;
    *) return 1 ;;
  esac
}

ai_company_git_status_path() {
  local line="$1"
  local path="${line:3}"
  case "$path" in
    *" -> "*) printf "%s\n" "${path##* -> }" ;;
    *) printf "%s\n" "$path" ;;
  esac
}

ai_company_paths_generated_only() {
  local file
  local total=0
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    total=$((total + 1))
    if ! ai_company_generated_path "$file"; then
      return 1
    fi
  done
  [ "$total" -gt 0 ]
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    is-generated)
      ai_company_generated_path "${1:-}"
      ;;
    classify)
      if ai_company_generated_path "${1:-}"; then
        echo "generated"
      else
        echo "source"
      fi
      ;;
    generated-only)
      ai_company_paths_generated_only
      ;;
    *)
      echo "Usage: $0 is-generated PATH | classify PATH | generated-only < paths" >&2
      exit 2
      ;;
  esac
fi
