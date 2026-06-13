#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

LOCK_NAME="${1:-}"
shift || true

if [ -z "$LOCK_NAME" ] || [ "$#" -eq 0 ]; then
  echo "Usage: ./runners/ai_company_lock.sh <repo_write|dashboard|devops|database|qa|name> <command> [args...]"
  exit 2
fi

if ! command -v flock >/dev/null 2>&1; then
  echo "ERROR: flock is required for AI Company OS shared-resource locking."
  exit 1
fi

case "$LOCK_NAME" in
  repo|repo_write)
    LOCK_FILE="company/runtime/locks/repo_write.lock"
    ;;
  dashboard)
    LOCK_FILE="company/runtime/locks/dashboard.lock"
    ;;
  devops|service|services)
    LOCK_FILE="company/runtime/locks/devops.lock"
    ;;
  database|db)
    LOCK_FILE="company/runtime/locks/database.lock"
    ;;
  qa)
    LOCK_FILE="company/runtime/locks/qa.lock"
    ;;
  *)
    safe_name="$(printf "%s" "$LOCK_NAME" | tr -c 'A-Za-z0-9_.-' '_')"
    LOCK_FILE="company/runtime/locks/${safe_name}.lock"
    ;;
esac

mkdir -p "$(dirname "$LOCK_FILE")"

echo "Acquiring lock: $LOCK_FILE"
exec 9>"$LOCK_FILE"
flock -x 9
printf "%s pid=%s command=%s\n" "$(date -Iseconds)" "$$" "$*" > "${LOCK_FILE}.holder"

cleanup() {
  rm -f "${LOCK_FILE}.holder"
}
trap cleanup EXIT

"$@"
