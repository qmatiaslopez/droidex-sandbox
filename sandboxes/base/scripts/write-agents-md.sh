#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <project-dir>" >&2
  exit 1
fi

PROJECT_DIR="$1"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Sandbox not found: $PROJECT_DIR" >&2
  exit 1
fi

PROJECT_NAME="$(basename "$PROJECT_DIR")"
DOCKERFILE="$PROJECT_DIR/Dockerfile"
PROJECT_PROFILE="custom"

if [[ -f "$DOCKERFILE" ]]; then
  first_line="$(head -n 1 "$DOCKERFILE" 2>/dev/null || true)"
  case "$first_line" in
    "FROM python:"*)
      PROJECT_PROFILE="python"
      ;;
    "FROM node:"*)
      PROJECT_PROFILE="npm"
      ;;
    "FROM debian:"*)
      PROJECT_PROFILE="base"
      ;;
  esac
fi

cat <<EOF | docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T droid sh -lc 'umask 077 && mkdir -p /home/dev/.factory && cat > /home/dev/.factory/AGENTS.md'
# Sandbox Operating Context

You are running inside an isolated development container for the \`$PROJECT_NAME\` sandbox.
The sandbox profile is \`$PROJECT_PROFILE\`.

## Workspace

- Work in \`/workspace\`.
- Treat \`/workspace\` as the project root.
- You may read, create, modify, move, and delete files in \`/workspace\`.
- Use Git normally inside the repository in \`/workspace\`.
- Prefer project-local dependency installs and project-local configuration.

## Constraints

- You are not running on the host machine.
- The container is isolated from the host system.
- Do not assume root access.
- \`sudo\` is unavailable.
- Do not attempt host administration or privileged system operations.
- If a system dependency is missing, update the sandbox \`Dockerfile\` instead of trying to install it with elevated privileges at runtime.

## Expectations

- Treat security as a primary concern across the project.
- Follow the CIA triad: protect confidentiality, integrity, and availability in all changes.
- Apply sound security principles when designing, modifying, testing, and documenting the project.
- Keep changes reproducible and scoped to the project files.
- Prefer local, repo-visible changes over global system changes.
- Commit meaningful changes to the repository as part of normal good practice.
- Keep documentation updated when behavior, setup, or workflows change.
- If a required capability is missing, adjust the sandbox definition or project configuration rather than bypassing restrictions.
EOF
