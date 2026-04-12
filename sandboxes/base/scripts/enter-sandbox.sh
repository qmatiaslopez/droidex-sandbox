#!/usr/bin/env bash
set -euo pipefail

MODE="droid"
if [[ "${1:-}" == "--shell" ]]; then
  MODE="shell"
  shift
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 [--shell] <project-name>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SANDBOX_HOME="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECTS_DIR="${SANDBOX_PROJECTS_DIR:-${SANDBOX_HOME:-$DEFAULT_SANDBOX_HOME}/projects}"
PROJECT_DIR="$PROJECTS_DIR/$1"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Sandbox not found: $PROJECT_DIR" >&2
  exit 1
fi

cd "$PROJECT_DIR"

running_services="$(docker compose ps --status running --services 2>/dev/null || true)"
if [[ -z "$running_services" ]]; then
  echo "Sandbox is not running; starting it now..."
  docker compose up -d
fi

docker compose exec -T droid sh -lc '
  chown -R dev:dev /workspace /home/dev/.factory /home/dev/.cache 2>/dev/null || true
  chown -R dev:dev /workspace/.git 2>/dev/null || true
  HOME=/home/dev su dev -c "git config --global --add safe.directory /workspace"
' >/dev/null

if [[ "$MODE" == "shell" ]]; then
  exec docker compose exec droid env HOME=/home/dev PATH=/home/dev/.local/bin:/home/dev/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin su dev
fi

exec docker compose exec droid sh -lc 'cd /workspace && exec env HOME=/home/dev PATH=/home/dev/.local/bin:/home/dev/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin su dev -c "cd /workspace && exec droid --settings /factory-config/settings.json"'
