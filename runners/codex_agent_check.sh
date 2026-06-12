#!/usr/bin/env bash
set -euo pipefail

echo "# Codex Agent Check"

if ! command -v codex >/dev/null 2>&1; then
  echo "FAIL: codex CLI not found"
  exit 1
fi

echo "Codex path: $(command -v codex)"
echo "Codex version:"
codex --version

echo
echo "## Non-interactive read-only smoke test"
OUTPUT="$(timeout 180s codex exec --cd /opt/ai-company --sandbox read-only "Reply exactly: CODEX_OK" 2>&1 || true)"
echo "$OUTPUT"

if ! printf "%s\n" "$OUTPUT" | grep -q "CODEX_OK"; then
  echo "FAIL: Codex did not return CODEX_OK"
  exit 1
fi

echo
echo "Codex agent check passed."
