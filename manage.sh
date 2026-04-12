#!/usr/bin/env bash
set -euo pipefail

STACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MENU_SCRIPT="${SANDBOX_MENU_SCRIPT:-$STACK_ROOT/sandboxes/scripts/manage-projects.sh}"

if [[ ! -x "$MENU_SCRIPT" ]]; then
  echo "Missing menu script: $MENU_SCRIPT" >&2
  exit 1
fi

exec "$MENU_SCRIPT"
