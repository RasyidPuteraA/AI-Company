#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR="company/runtime/autodev/context"
mkdir -p "$OUT_DIR"

STAMP="$(date +%Y%m%d%H%M%S)"
OUT="$OUT_DIR/${STAMP}-repo-context.md"

{
  echo "# AI Company OS Repository Context"
  echo
  echo "Generated at: $(date)"
  echo "Repo: $(pwd)"
  echo

  echo "## Git"
  echo
  echo "- branch: $(git branch --show-current 2>/dev/null || true)"
  echo "- latest commit: $(git log -1 --oneline 2>/dev/null || true)"
  echo
  echo "### Git status"
  echo
  git status --short || true
  echo
  echo "### Recent commits"
  git log --oneline -20 || true
  echo

  echo "## Important directories"
  echo
  for d in apps runners projects/internal company/config company/reports; do
    if [ -d "$d" ]; then
      echo "### $d"
      find "$d" -maxdepth 3 -type f \
        ! -path '*/node_modules/*' \
        ! -path '*/company/runtime/*' \
        ! -iname '*.png' \
        ! -iname '*.jpg' \
        ! -iname '*.jpeg' \
        ! -iname '*.webp' \
        ! -iname '*.gif' \
        | sort | sed 's#^#- #'
      echo
    fi
  done

  echo "## Dashboard files"
  echo
  find apps/dashboard -maxdepth 4 -type f \
    ! -path '*/node_modules/*' \
    ! -iname '*.png' \
    ! -iname '*.jpg' \
    ! -iname '*.jpeg' \
    ! -iname '*.webp' \
    2>/dev/null | sort | sed 's#^#- #' || true
  echo

  echo "## Package manifests"
  echo
  find . -maxdepth 4 -name package.json -type f \
    ! -path '*/node_modules/*' \
    | sort | while read -r f; do
      echo "### $f"
      python3 - "$f" << 'PYJSON'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
try:
    data = json.loads(p.read_text())
    print("- name:", data.get("name", ""))
    print("- scripts:", ", ".join(sorted((data.get("scripts") or {}).keys())))
    deps = data.get("dependencies") or {}
    dev = data.get("devDependencies") or {}
    print("- dependencies:", len(deps))
    print("- devDependencies:", len(dev))
except Exception as e:
    print("Could not parse:", e)
PYJSON
      echo
    done

  echo "## Managed services"
  echo
  for svc in \
    ai-company-dashboard.service \
    ai-company-agent@pm_agent.service \
    ai-company-agent@engineer_agent.service \
    ai-company-agent@qa_agent.service \
    ai-company-agent@devops_agent.service
  do
    state="$(systemctl is-active "$svc" 2>/dev/null || true)"
    echo "- $svc: ${state:-unknown}"
  done

  echo
  echo "## Safety reminder"
  echo
  echo "- Do not edit secrets, auth files, tokens, sudo passwords, .env files, or Codex credentials."
  echo "- Do not finalize client work without Owner approval."
  echo "- Prefer small auditable changes."
} > "$OUT"

echo "$OUT"
