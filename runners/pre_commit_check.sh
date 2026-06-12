#!/usr/bin/env bash
set -euo pipefail

echo "# AI Company OS Pre-Commit Check"
echo "Generated at: $(date)"

echo
echo "## System health"
./runners/health.sh

echo
echo "## Shell syntax checks"
find runners -maxdepth 1 -type f -name '*.sh' -print0 | sort -z | while IFS= read -r -d '' file; do
  echo "- checking $file"
  bash -n "$file"
done

echo
echo "## Git staged files"
git status --short

echo
echo "## Raw asset staging guard"
STAGED_FILES="$(git diff --cached --name-only || true)"

if printf "%s\n" "$STAGED_FILES" | grep -Eiq '(^|/)(raw|source|assets-original|jik.*raw|limezu.*raw|Modern_Office|MetroCity)(/|$)'; then
  echo "FAIL: possible raw/paid asset path is staged."
  printf "%s\n" "$STAGED_FILES" | grep -Ei '(^|/)(raw|source|assets-original|jik.*raw|limezu.*raw|Modern_Office|MetroCity)(/|$)' || true
  exit 1
fi

echo "No suspicious raw asset paths staged."

echo
echo "Pre-commit check passed."
