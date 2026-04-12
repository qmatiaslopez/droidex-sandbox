#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${CODEX_LB_BASE_URL:-http://127.0.0.1:2455/v1}"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <openai-api-key>" >&2
  exit 1
fi

OPENAI_API_KEY="$1"

if [[ -z "$OPENAI_API_KEY" ]]; then
  echo "OPENAI_API_KEY cannot be empty" >&2
  exit 1
fi

python3 - "$BASE_URL" "$OPENAI_API_KEY" <<'PY'
import json
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

base_url = sys.argv[1].rstrip("/")
api_key = sys.argv[2]

request = Request(
    f"{base_url}/models",
    headers={"Authorization": f"Bearer {api_key}"},
)

try:
    with urlopen(request, timeout=20) as response:
        payload = json.load(response)
except HTTPError as exc:
    detail = exc.read().decode("utf-8", errors="replace")
    raise SystemExit(f"Model discovery failed with HTTP {exc.code}: {detail}")
except URLError as exc:
    raise SystemExit(f"Model discovery failed: {exc}")

models = payload.get("data")
if not isinstance(models, list) or not models:
    raise SystemExit("Model discovery failed: no models returned")

def sort_key(item):
    metadata = item.get("metadata") or {}
    priority = metadata.get("priority")
    if not isinstance(priority, int):
        priority = 10**9
    return (priority, item.get("id", ""))

def slugify(value):
    cleaned = re.sub(r"[^A-Za-z0-9]+", "-", value).strip("-")
    return cleaned or "model"

def image_supported(item):
    metadata = item.get("metadata") or {}
    modalities = metadata.get("input_modalities") or []
    return "image" in modalities

sorted_models = sorted(models, key=sort_key)
custom_models = []
for index, item in enumerate(sorted_models):
    model_name = item.get("id")
    if not model_name:
        continue
    metadata = item.get("metadata") or {}
    display_name = metadata.get("display_name") or model_name
    custom_models.append(
        {
            "model": model_name,
            "id": f"custom:{slugify(display_name)}-{index}",
            "index": index,
            "baseUrl": "http://codex-lb:2455/v1",
            "apiKey": api_key,
            "displayName": f"{display_name} [Proxy]",
            "maxOutputTokens": 128000,
            "noImageSupport": not image_supported(item),
            "provider": "openai",
        }
    )

if not custom_models:
    raise SystemExit("Model discovery failed: no valid models after filtering")

default_model = custom_models[0]["id"]

settings = {
    "customModels": custom_models,
    "sessionDefaultSettings": {
        "model": default_model,
        "reasoningEffort": "none",
        "interactionMode": "auto",
        "autonomyLevel": "medium",
        "autonomyMode": "auto-medium",
    },
    "missionModelSettings": {
        "workerModel": default_model,
        "workerReasoningEffort": "none",
        "validationWorkerModel": default_model,
        "validationWorkerReasoningEffort": "none",
        "skipScrutiny": False,
        "skipUserTesting": False,
    },
    "missionOrchestratorModel": default_model,
    "missionOrchestratorReasoningEffort": "none",
}

json.dump(settings, sys.stdout, indent=2)
sys.stdout.write("\n")
PY
