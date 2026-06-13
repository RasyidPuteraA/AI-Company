#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ASSET_ROOT="apps/dashboard/public/assets/office"
CONFIG_FILE="$ASSET_ROOT/config.json"
TILESET_DIR="$ASSET_ROOT/tilesets"
CHARACTER_DIR="$ASSET_ROOT/characters"

echo "# Pixel Office Asset Check"
echo "- Asset root: $ASSET_ROOT"
echo "- Time: $(date)"
echo

fail=0

check_dir() {
  local path="$1"
  if [ -d "$path" ]; then
    echo "PASS: directory exists: $path"
  else
    echo "FAIL: missing directory: $path"
    fail=1
  fi
}

check_dir "$ASSET_ROOT"
check_dir "$TILESET_DIR"
check_dir "$CHARACTER_DIR"

if [ -f "$CONFIG_FILE" ]; then
  echo "PASS: config exists: $CONFIG_FILE"
  python3 -m json.tool "$CONFIG_FILE" >/dev/null
  echo "PASS: config JSON is valid"
else
  echo "FAIL: missing config: $CONFIG_FILE"
  fail=1
fi

echo
echo "## Optional PNG assets"
echo "Tilesets:"
find "$TILESET_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.webp' -o -iname '*.jpg' -o -iname '*.jpeg' \) -printf '  - %f\n' || true

echo "Characters:"
find "$CHARACTER_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.webp' -o -iname '*.jpg' -o -iname '*.jpeg' \) -printf '  - %f\n' || true

echo
echo "Note: raw image assets are optional and ignored by git by default."

if [ "$fail" -ne 0 ]; then
  echo "Pixel Office asset check FAILED."
  exit 1
fi

echo "Pixel Office asset check passed."
