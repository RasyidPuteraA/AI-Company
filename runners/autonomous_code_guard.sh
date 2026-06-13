#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -f company/config/autonomous_development.env ]; then
  # shellcheck disable=SC1091
  source company/config/autonomous_development.env
fi

: "${AI_COMPANY_AUTO_MAX_CHANGED_FILES:=25}"
: "${AI_COMPANY_AUTO_MAX_DIFF_LINES:=1800}"

fail=0

changed_files="$(
  {
    git diff --name-only || true
    git diff --cached --name-only || true
    git ls-files --others --exclude-standard || true
  } | sort -u
)"

changed_count="$(printf '%s\n' "$changed_files" | sed '/^$/d' | wc -l | tr -d ' ')"

echo "# Autonomous Code Guard"
echo "- changed files: $changed_count"
echo "- max changed files: $AI_COMPANY_AUTO_MAX_CHANGED_FILES"
echo

if [ "$changed_count" -gt "$AI_COMPANY_AUTO_MAX_CHANGED_FILES" ]; then
  echo "FAIL: too many changed files."
  fail=1
fi

deny_patterns=(
  ".env"
  ".env."
  ".pem"
  ".key"
  ".crt"
  ".p12"
  ".pfx"
  ".kube"
  ".ssh/"
  ".codex/"
  "codex/auth"
  "token"
  "secret"
  "password"
  "passwd"
  "credential"
  "credentials"
  "company/runtime/"
  ".git/config"
)

while IFS= read -r file; do
  [ -z "$file" ] && continue

  lower="$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')"

  for pat in "${deny_patterns[@]}"; do
    if printf '%s' "$lower" | grep -Fq "$pat"; then
      echo "FAIL: denied path pattern '$pat' matched: $file"
      fail=1
    fi
  done

  if printf '%s' "$lower" | grep -Eq '\.(png|jpg|jpeg|webp|gif|zip|tar|gz|7z|rar|sqlite|db)$'; then
    echo "FAIL: binary/archive/database file changed: $file"
    fail=1
  fi

done <<< "$changed_files"

diff_lines="$(git diff --numstat 2>/dev/null | awk '{add+=$1; del+=$2} END {print add+del+0}')"
cached_lines="$(git diff --cached --numstat 2>/dev/null | awk '{add+=$1; del+=$2} END {print add+del+0}')"
total_lines="$((diff_lines + cached_lines))"

echo "- changed diff lines: $total_lines"
echo "- max diff lines: $AI_COMPANY_AUTO_MAX_DIFF_LINES"

if [ "$total_lines" -gt "$AI_COMPANY_AUTO_MAX_DIFF_LINES" ]; then
  echo "FAIL: diff too large."
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "Autonomous code guard FAILED."
  exit 1
fi

echo
echo "Autonomous code guard passed."
