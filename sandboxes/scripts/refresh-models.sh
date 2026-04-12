#!/usr/bin/env bash
set -euo pipefail

STACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX_HOME="${SANDBOX_HOME:-$STACK_ROOT/sandboxes}"
PROJECTS_DIR="${SANDBOX_PROJECTS_DIR:-$SANDBOX_HOME/projects}"
RESOLVE_MODELS_SCRIPT="$SANDBOX_HOME/scripts/resolve-models.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <project-name-or-path>" >&2
  exit 1
fi

if [[ ! -x "$RESOLVE_MODELS_SCRIPT" ]]; then
  echo "Missing model resolution script: $RESOLVE_MODELS_SCRIPT" >&2
  exit 1
fi

INPUT="$1"
if [[ -d "$INPUT" ]]; then
  PROJECT_DIR="$INPUT"
else
  PROJECT_DIR="$PROJECTS_DIR/$INPUT"
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Sandbox not found: $PROJECT_DIR" >&2
  exit 1
fi

SECRETS_FILE="$PROJECT_DIR/.env.local"
SETTINGS_OUTPUT="$PROJECT_DIR/.factory-container-settings.json"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Missing secrets file: $SECRETS_FILE" >&2
  exit 1
fi

OPENAI_API_KEY="$(
  python3 - "$SECRETS_FILE" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
for line in path.read_text().splitlines():
    if line.startswith("OPENAI_API_KEY="):
        print(line.split("=", 1)[1])
        break
else:
    raise SystemExit(1)
PY
)"

if [[ -z "$OPENAI_API_KEY" ]]; then
  echo "OPENAI_API_KEY is missing in $SECRETS_FILE" >&2
  exit 1
fi

"$RESOLVE_MODELS_SCRIPT" "$OPENAI_API_KEY" > "$SETTINGS_OUTPUT"
echo "Updated model settings: $SETTINGS_OUTPUT"
