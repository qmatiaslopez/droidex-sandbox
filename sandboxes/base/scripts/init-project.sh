#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <project-name> <base|python|npm>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SANDBOX_HOME="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASE_DIR="${SANDBOX_HOME:-$DEFAULT_SANDBOX_HOME}"
BASE_TEMPLATE="$BASE_DIR/base/project-template"
PROJECT_NAME="$1"
PROJECT_PROFILE="$2"
PROJECT_DIR="$BASE_DIR/projects/$PROJECT_NAME"

case "$PROJECT_PROFILE" in
  base|python|npm)
    ;;
  *)
    echo "Unsupported sandbox profile: $PROJECT_PROFILE" >&2
    exit 1
    ;;
esac

if [[ -e "$PROJECT_DIR" ]]; then
  echo "Project sandbox already exists: $PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR/repo"
cp "$BASE_DIR/base/Dockerfile.$PROJECT_PROFILE" "$PROJECT_DIR/Dockerfile"
cp "$BASE_DIR/base/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"
cp "$BASE_DIR/base/.env.example" "$PROJECT_DIR/.env"
mkdir -p "$PROJECT_DIR/.factory"
cp -R "$BASE_TEMPLATE/.factory/." "$PROJECT_DIR/.factory/"
cp "$BASE_TEMPLATE/.factory-container-settings.json" "$PROJECT_DIR/.factory-container-settings.json"

UID_VALUE=$(id -u)
GID_VALUE=$(id -g)
sed -i "s/^UID=.*/UID=${UID_VALUE}/" "$PROJECT_DIR/.env"
sed -i "s/^GID=.*/GID=${GID_VALUE}/" "$PROJECT_DIR/.env"

echo "Created sandbox at $PROJECT_DIR"
echo "Profile: $PROJECT_PROFILE"
echo "Next steps:"
echo "  1. Put or clone your repository into $PROJECT_DIR/repo"
echo "  2. cd $PROJECT_DIR"
echo "  3. docker compose build"
echo "  4. docker compose run --rm droid"
