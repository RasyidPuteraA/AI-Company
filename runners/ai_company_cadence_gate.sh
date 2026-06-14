#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

DEFAULT_STATE_DIR="company/runtime/cadence"

usage() {
  cat <<'EOF'
Usage:
  ./runners/ai_company_cadence_gate.sh daily NAME [STATE_DIR]
  ./runners/ai_company_cadence_gate.sh mark-daily NAME [STATE_DIR]
  ./runners/ai_company_cadence_gate.sh interval NAME MINUTES [STATE_DIR]
  ./runners/ai_company_cadence_gate.sh mark-interval NAME [STATE_DIR]
  ./runners/ai_company_cadence_gate.sh git-head-changed NAME [STATE_DIR]
  ./runners/ai_company_cadence_gate.sh mark-git-head NAME [STATE_DIR]

Exit status 0 means the cadence condition allows work. Exit status 1 means
the work should be skipped. mark-* commands record successful completion.
EOF
}

safe_name() {
  local name="$1"
  if ! [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "ERROR: cadence name must contain only letters, numbers, dot, underscore, or dash: $name" >&2
    exit 2
  fi
  printf "%s" "$name"
}

state_dir_for() {
  local state_dir="${1:-$DEFAULT_STATE_DIR}"
  mkdir -p "$state_dir"
  printf "%s" "$state_dir"
}

read_first_line() {
  local file="$1"
  if [ -f "$file" ]; then
    sed -n '1p' "$file" 2>/dev/null || true
  fi
}

write_atomic() {
  local file="$1"
  local value="$2"
  local tmp
  mkdir -p "$(dirname "$file")"
  tmp="${file}.$$.$RANDOM.tmp"
  printf "%s\n" "$value" > "$tmp"
  mv "$tmp" "$file"
}

cmd="${1:-}"
case "$cmd" in
  -h|--help|"")
    usage
    [ -n "$cmd" ]
    exit $?
    ;;
esac
shift || true

case "$cmd" in
  daily)
    name="$(safe_name "${1:-}")"
    state_dir="$(state_dir_for "${2:-}")"
    today="$(date +%F)"
    last="$(read_first_line "$state_dir/$name.date")"
    [ "$last" != "$today" ]
    ;;
  mark-daily)
    name="$(safe_name "${1:-}")"
    state_dir="$(state_dir_for "${2:-}")"
    write_atomic "$state_dir/$name.date" "$(date +%F)"
    ;;
  interval)
    name="$(safe_name "${1:-}")"
    minutes="${2:-}"
    state_dir="$(state_dir_for "${3:-}")"
    if ! [[ "$minutes" =~ ^[0-9]+$ ]] || [ "$minutes" -lt 1 ]; then
      echo "ERROR: interval minutes must be a positive integer." >&2
      exit 2
    fi
    now="$(date +%s)"
    last="$(read_first_line "$state_dir/$name.epoch")"
    if ! [[ "$last" =~ ^[0-9]+$ ]]; then
      exit 0
    fi
    [ "$((now - last))" -ge "$((minutes * 60))" ]
    ;;
  mark-interval)
    name="$(safe_name "${1:-}")"
    state_dir="$(state_dir_for "${2:-}")"
    write_atomic "$state_dir/$name.epoch" "$(date +%s)"
    ;;
  git-head-changed)
    name="$(safe_name "${1:-}")"
    state_dir="$(state_dir_for "${2:-}")"
    head="$(git rev-parse HEAD 2>/dev/null || true)"
    if [ -z "$head" ]; then
      echo "ERROR: unable to resolve git HEAD." >&2
      exit 2
    fi
    last="$(read_first_line "$state_dir/$name.head")"
    [ "$last" != "$head" ]
    ;;
  mark-git-head)
    name="$(safe_name "${1:-}")"
    state_dir="$(state_dir_for "${2:-}")"
    head="$(git rev-parse HEAD 2>/dev/null || true)"
    if [ -z "$head" ]; then
      echo "ERROR: unable to resolve git HEAD." >&2
      exit 2
    fi
    write_atomic "$state_dir/$name.head" "$head"
    ;;
  *)
    echo "ERROR: unknown cadence command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
