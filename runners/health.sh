#!/usr/bin/env bash
set -euo pipefail

# Owner shortcut for the unified AI Company OS health check.
exec ./runners/system_health_check.sh "$@"
