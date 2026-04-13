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
TMUX_SESSION_NAME="${DROID_TMUX_SESSION_NAME:-droid}"
RUNTIME_PATH="/home/dev/.local/bin:/home/dev/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

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
  git config --global --add safe.directory /workspace >/dev/null 2>&1 || true
' >/dev/null

if [[ "$MODE" == "shell" ]]; then
  exec docker compose exec droid env HOME=/home/dev PATH="$RUNTIME_PATH" bash
fi

docker compose exec -T droid sh -lc "
  if ! command -v tmux >/dev/null 2>&1; then
    echo 'tmux is not installed in this sandbox image.' >&2
    exit 1
  fi

  if tmux has-session -t '$TMUX_SESSION_NAME' 2>/dev/null; then
    if ! tmux list-panes -t '$TMUX_SESSION_NAME' -F '#{pane_dead}' 2>/dev/null | grep -qx '0'; then
      tmux kill-session -t '$TMUX_SESSION_NAME' >/dev/null 2>&1 || true
    fi
  fi

  if ! tmux has-session -t '$TMUX_SESSION_NAME' 2>/dev/null; then
    cd /workspace
    tmux new-session -d -s '$TMUX_SESSION_NAME' 'cd /workspace && exec env HOME=/home/dev PATH=$RUNTIME_PATH droid --settings /factory-config/settings.json'
  fi
"

echo "Opening persistent Droid session '$TMUX_SESSION_NAME'. Detach with Ctrl+b then d." >&2
exec docker compose exec droid env HOME=/home/dev PATH="$RUNTIME_PATH" tmux attach -t "$TMUX_SESSION_NAME"
