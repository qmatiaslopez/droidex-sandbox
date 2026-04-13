#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

if [[ "$cmd" =~ (^|[[:space:]])sudo([[:space:]]|$) ]]; then
  cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Este sandbox no permite sudo. Instala dependencias base en el Dockerfile y trabaja dentro de /workspace para el resto."
  }
}
JSON
  exit 0
fi

if [[ "$cmd" =~ (^|[[:space:]])systemctl([[:space:]]|$) ]] || \
   [[ "$cmd" =~ (^|[[:space:]])reboot([[:space:]]|$) ]] || \
   [[ "$cmd" =~ (^|[[:space:]])shutdown([[:space:]]|$) ]] || \
   [[ "$cmd" =~ (^|[[:space:]])docker([[:space:]]|$) ]]; then
  cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Este sandbox no permite systemctl/reboot/shutdown/docker. Usa el Dockerfile para dependencias del sistema."
  }
}
JSON
  exit 0
fi
