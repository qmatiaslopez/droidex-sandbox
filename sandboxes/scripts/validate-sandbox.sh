#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <sandbox-project-dir>" >&2
  exit 1
fi

PROJECT_DIR="$1"
cd "$PROJECT_DIR"
docker compose exec -T droid sh -lc 'code=$(curl -s -o /dev/null -w "%{http_code}" http://codex-lb:2455/v1 || true); [ "$code" = "404" ]'
echo "Sandbox validation OK: codex-lb reachable from container"
