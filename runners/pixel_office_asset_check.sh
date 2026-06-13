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
  echo
  echo "## Config summary"
  python3 - "$CONFIG_FILE" "$TILESET_DIR" "$CHARACTER_DIR" << 'PYCONFIG'
import json
import sys
from pathlib import Path

config_file = Path(sys.argv[1])
tileset_dir = Path(sys.argv[2])
character_dir = Path(sys.argv[3])

data = json.loads(config_file.read_text())
mode = data.get("mode", "template")

tileset_name = data.get("assets", {}).get("tileset", {}).get("filename", "")
character_name = data.get("assets", {}).get("characters", {}).get("filename", "")

print(f"- mode: {mode}")
print(f"- expected tileset: {tileset_name or '(not set)'}")
print(f"- expected characters: {character_name or '(not set)'}")

if tileset_name:
    tileset_path = tileset_dir / Path(tileset_name).name
    print(f"- tileset exists: {'yes' if tileset_path.exists() else 'no'}")

if character_name:
    character_path = character_dir / Path(character_name).name
    print(f"- character sheet exists: {'yes' if character_path.exists() else 'no'}")

if mode != "custom":
    print("- custom asset loading is disabled; synthetic renderer remains active.")
PYCONFIG
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
