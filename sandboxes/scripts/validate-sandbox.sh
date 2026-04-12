#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <sandbox-project-dir>" >&2
  exit 1
fi

PROJECT_DIR="$1"
SECRETS_FILE="$PROJECT_DIR/.env.local"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Sandbox not found: $PROJECT_DIR" >&2
  exit 1
fi

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

cd "$PROJECT_DIR"
payload="$(
  docker compose exec -T \
    -e VALIDATION_OPENAI_API_KEY="$OPENAI_API_KEY" \
    droid sh -lc 'curl -fsS -H "Authorization: Bearer $VALIDATION_OPENAI_API_KEY" http://codex-lb:2455/v1/models'
)"

python3 - <<'PY' "$payload"
import json
import sys

payload = json.loads(sys.argv[1])
models = payload.get("data")
if not isinstance(models, list) or not models:
    raise SystemExit("Sandbox validation failed: no models returned")

sample = models[0].get("id", "<unknown>")
print(f"Sandbox validation OK: {len(models)} models visible via codex-lb (sample: {sample})")
PY
