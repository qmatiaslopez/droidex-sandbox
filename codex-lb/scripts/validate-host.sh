#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-2455}"
BASE_URL="http://127.0.0.1:${PORT}/v1"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL" || true)

if [[ "$STATUS" != "404" ]]; then
  echo "Unexpected status from $BASE_URL: $STATUS" >&2
  exit 1
fi

echo "Host validation OK: $BASE_URL returned 404 as expected"
