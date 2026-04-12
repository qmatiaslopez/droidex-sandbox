#!/usr/bin/env bash
set -euo pipefail

STACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_MENU_SCRIPT="${SANDBOX_MENU_SCRIPT:-$STACK_ROOT/manage.sh}"

if [[ ! -x "$ROOT_MENU_SCRIPT" ]]; then
  echo "Missing menu script: $ROOT_MENU_SCRIPT" >&2
  exit 1
fi

exec "$ROOT_MENU_SCRIPT"
