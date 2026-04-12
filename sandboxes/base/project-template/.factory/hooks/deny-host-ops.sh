#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

if [[ "$cmd" =~ (^|[[:space:]])sudo([[:space:]]|$) ]] || \
   [[ "$cmd" =~ (^|[[:space:]])systemctl([[:space:]]|$) ]] || \
   [[ "$cmd" =~ (^|[[:space:]])reboot([[:space:]]|$) ]] || \
   [[ "$cmd" =~ (^|[[:space:]])shutdown([[:space:]]|$) ]] || \
   [[ "$cmd" =~ (^|[[:space:]])docker([[:space:]]|$) ]]; then
  cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Este sandbox no permite sudo/systemctl/reboot/shutdown/docker. Trabaja solo dentro de /workspace y pide cambios en Dockerfile o archivos del repo cuando falte algo."
  }
}
JSON
  exit 0
fi
