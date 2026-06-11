#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="$ROOT_DIR/apps/dashboard/public/assets/jik"

echo "# JIK-A-4 Asset Validation"
echo "- Asset dir: $ASSET_DIR"
echo

if [[ ! -d "$ASSET_DIR" ]]; then
  echo "ERROR: JIK asset directory not found."
  exit 1
fi

echo "## Manifest"
if [[ -f "$ASSET_DIR/asset-manifest.json" ]]; then
  echo "FOUND: asset-manifest.json"
else
  echo "MISSING: asset-manifest.json"
fi

echo
echo "## Incoming archives"
find "$ASSET_DIR/_incoming" -maxdepth 2 -type f 2>/dev/null || true

echo
echo "## Processed files"
find "$ASSET_DIR/_processed" -maxdepth 4 -type f 2>/dev/null | head -80 || true

echo
echo "## Character sprite candidates"
if find "$ASSET_DIR" -type f \( -iname '*.png' -o -iname '*.aseprite' -o -iname '*.json' \) | grep -q .; then
  find "$ASSET_DIR" -type f \( -iname '*.png' -o -iname '*.aseprite' -o -iname '*.json' \) | head -80
else
  echo "WARNING: no image/sprite files found yet."
fi

echo
echo "Validation completed."
