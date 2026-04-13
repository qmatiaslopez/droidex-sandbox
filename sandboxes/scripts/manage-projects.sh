#!/usr/bin/env bash
set -euo pipefail

STACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX_HOME="${SANDBOX_HOME:-$STACK_ROOT/sandboxes}"
PROJECTS_DIR="${SANDBOX_PROJECTS_DIR:-$SANDBOX_HOME/projects}"
INIT_SCRIPT="$SANDBOX_HOME/base/scripts/init-project.sh"
RESOLVE_MODELS_SCRIPT="$SANDBOX_HOME/scripts/resolve-models.sh"
ENTER_SCRIPT="$SANDBOX_HOME/base/scripts/enter-sandbox.sh"
CODEX_COMPOSE_FILE="${CODEX_COMPOSE_FILE:-$STACK_ROOT/codex-lb/docker-compose.yaml}"
SANDBOX_ENV_FILE="${SANDBOX_ENV_FILE:-$SANDBOX_HOME/.env}"

CSI=$'\033['
RESET="${CSI}0m"
BOLD="${CSI}1m"
DIM="${CSI}2m"
RED="${CSI}31m"
GREEN="${CSI}32m"
YELLOW="${CSI}33m"
BLUE="${CSI}34m"
MAGENTA="${CSI}35m"
CYAN="${CSI}36m"
WHITE="${CSI}37m"

color_enabled() {
  [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]
}

paint() {
  local color="$1"
  shift
  if color_enabled; then
    printf '%b%s%b' "$color" "$*" "$RESET"
  else
    printf '%s' "$*"
  fi
}

print_line() {
  printf '%s\n' "$*"
}

print_section() {
  print_line >&2
  paint "$BOLD$BLUE" "$1" >&2
  print_line >&2
  if [[ -n "${2:-}" ]]; then
    paint "$DIM" "$2" >&2
    print_line >&2
  fi
}

print_header() {
  clear 2>/dev/null || true
  print_line
  paint "$BOLD$CYAN" "Droidex Sandbox Control Center"
  print_line
  paint "$DIM" "Daily menu for sandbox creation and access"
  print_line
  print_line "$(paint "$DIM" "$(printf '%.0s─' {1..72})")"
  print_codex_summary
  print_line "$(paint "$DIM" "$(printf '%.0s─' {1..72})")"
}

pause_screen() {
  print_line
  read -r -p "Press Enter to continue..." _ || true
}

require_script() {
  local script_path="$1"
  if [[ ! -x "$script_path" ]]; then
    echo "Missing required script: $script_path" >&2
    exit 1
  fi
}

prompt_default() {
  local prompt="$1"
  local default_value="$2"
  local help_text="${3:-}"
  local value
  if [[ -n "$help_text" ]]; then
    paint "$DIM" "$help_text" >&2
    print_line >&2
  fi
  read -r -p "$prompt [$default_value]: " value
  if [[ -z "$value" ]]; then
    value="$default_value"
  fi
  printf '%s\n' "$value"
}

prompt_yes_no() {
  local prompt="$1"
  local default_answer="$2"
  local hint default_choice answer

  if [[ "$default_answer" == "y" ]]; then
    hint="Y/n"
    default_choice="y"
  else
    hint="y/N"
    default_choice="n"
  fi

  while true; do
    read -r -p "$prompt [$hint]: " answer
    answer="${answer:-$default_choice}"
    case "$answer" in
      y|Y|yes|YES)
        return 0
        ;;
      n|N|no|NO)
        return 1
        ;;
      *)
        echo "Please answer y or n."
        ;;
    esac
  done
}

prompt_numbered_choice() {
  local prompt="$1"
  local default_choice="$2"
  shift 2
  local options=("$@")
  local max_choice="${#options[@]}"
  local answer index label

  while true; do
    read -r -p "$prompt [1-$max_choice, default $default_choice]: " answer
    answer="${answer:-$default_choice}"

    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= max_choice )); then
      printf '%s\n' "${options[answer-1]}"
      return 0
    fi

    for index in "${!options[@]}"; do
      label="${options[index]}"
      if [[ "$answer" == "$label" ]]; then
        printf '%s\n' "$label"
        return 0
      fi
    done

    echo "Invalid selection. Choose a number from 1 to $max_choice."
  done
}

prompt_profile() {
  print_section "Sandbox profile" "Choose the runtime that new containers should include by default."
  print_line "  1) base    Minimal sandbox with Droid and common CLI tools only" >&2
  print_line "  2) python  Includes Python and pip for Python projects" >&2
  print_line "  3) npm     Includes Node.js and npm for JavaScript/TypeScript projects" >&2
  print_line >&2
  prompt_numbered_choice "Select the sandbox profile: 1=base, 2=python, 3=npm" "1" "base" "python" "npm"
}

read_env_value() {
  local env_file="$1"
  local variable_name="$2"

  [[ -f "$env_file" ]] || return 1

  python3 - "$env_file" "$variable_name" <<'PY'
import sys
from pathlib import Path

env_path = Path(sys.argv[1])
variable_name = sys.argv[2]

for raw_line in env_path.read_text().splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    if line.startswith("export "):
        line = line[7:].lstrip()
    if "=" not in line:
        continue
    key, value = line.split("=", 1)
    if key.strip() != variable_name:
        continue
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        value = value[1:-1]
    print(value)
    break
else:
    raise SystemExit(1)
PY
}

write_env_value() {
  local env_file="$1"
  local variable_name="$2"
  local variable_value="$3"

  python3 - "$env_file" "$variable_name" "$variable_value" <<'PY'
import sys
from pathlib import Path

env_path = Path(sys.argv[1])
variable_name = sys.argv[2]
variable_value = sys.argv[3]

lines = env_path.read_text().splitlines() if env_path.exists() else []
updated = False
output = []

for line in lines:
    stripped = line.strip()
    candidate = stripped
    if stripped.startswith("export "):
        candidate = stripped[7:].lstrip()
    if "=" in candidate:
        key = candidate.split("=", 1)[0].strip()
        if key == variable_name:
            output.append(f"{variable_name}={variable_value}")
            updated = True
            continue
    output.append(line)

if not updated:
    output.append(f"{variable_name}={variable_value}")

env_path.write_text("\n".join(output) + "\n")
PY
}

sanitize_env_value() {
  local raw_value="$1"

  python3 - "$raw_value" <<'PY'
import re
import sys

value = sys.argv[1]
value = re.sub(r"[\x00-\x1f\x7f]", "", value)
value = value.strip()

match = re.search(r"(sk-[A-Za-z0-9_-]+)", value)
if match:
    value = match.group(1)

print(value.strip())
PY
}

project_has_api_key() {
  local project="$1"
  local dir
  dir="$(project_dir "$project")"
  local api_key=""

  if api_key="$(read_env_value "$dir/.env.local" "OPENAI_API_KEY" 2>/dev/null)"; then
    [[ -n "$api_key" ]] && return 0
  fi

  if api_key="$(read_env_value "$dir/.env" "OPENAI_API_KEY" 2>/dev/null)"; then
    [[ -n "$api_key" ]] && return 0
  fi

  if api_key="$(read_env_value "$SANDBOX_ENV_FILE" "OPENAI_API_KEY" 2>/dev/null)"; then
    [[ -n "$api_key" ]] && return 0
  fi

  return 1
}

resolve_project_api_key() {
  local project_env_file="$1"
  local project_local_env_file="$2"
  local api_key=""

  if api_key="$(read_env_value "$project_local_env_file" "OPENAI_API_KEY" 2>/dev/null)"; then
    api_key="$(sanitize_env_value "$api_key")"
    if [[ -n "$api_key" ]]; then
      print_line "Using the project-specific codex-lb API key stored in $project_local_env_file" >&2
      printf '%s\n' "$api_key"
      return 0
    fi
  fi

  if api_key="$(read_env_value "$project_env_file" "OPENAI_API_KEY" 2>/dev/null)"; then
    api_key="$(sanitize_env_value "$api_key")"
    if [[ -n "$api_key" ]]; then
      if prompt_yes_no "Use the default codex-lb API key defined in $project_env_file for this sandbox?" "y"; then
        printf '%s\n' "$api_key"
        return 0
      fi
    fi
  fi

  if api_key="$(read_env_value "$SANDBOX_ENV_FILE" "OPENAI_API_KEY" 2>/dev/null)"; then
    api_key="$(sanitize_env_value "$api_key")"
    if [[ -n "$api_key" ]]; then
      if prompt_yes_no "Use the shared default codex-lb API key from $SANDBOX_ENV_FILE for this sandbox?" "y"; then
        printf '%s\n' "$api_key"
        return 0
      fi
    fi
  fi

  read -r -s -p "Enter the codex-lb API key this sandbox should use: " api_key
  echo >&2
  api_key="$(sanitize_env_value "$api_key")"
  if [[ -z "$api_key" ]]; then
    echo "The codex-lb API key cannot be empty." >&2
    return 1
  fi

  if [[ -n "$(read_env_value "$project_env_file" "OPENAI_API_KEY" 2>/dev/null || true)" ]]; then
    write_env_value "$project_local_env_file" "OPENAI_API_KEY" "$api_key"
    chmod 600 "$project_local_env_file"
    print_line "Saved the sandbox-specific codex-lb API key override to $project_local_env_file" >&2
  else
    write_env_value "$project_local_env_file" "OPENAI_API_KEY" "$api_key"
    chmod 600 "$project_local_env_file"
    print_line "Saved the sandbox-specific codex-lb API key to $project_local_env_file" >&2
  fi

  printf '%s\n' "$api_key"
}

project_names() {
  if [[ ! -d "$PROJECTS_DIR" ]]; then
    return 0
  fi

  local dir
  for dir in "$PROJECTS_DIR"/*; do
    [[ -d "$dir" ]] || continue
    basename "$dir"
  done | sort
}

project_dir() {
  printf '%s/%s\n' "$PROJECTS_DIR" "$1"
}

project_profile_label() {
  local project="$1"
  local dir dockerfile first_line
  dir="$(project_dir "$project")"
  dockerfile="$dir/Dockerfile"

  if [[ ! -f "$dockerfile" ]]; then
    printf 'unknown\n'
    return
  fi

  first_line="$(head -n 1 "$dockerfile" 2>/dev/null || true)"
  case "$first_line" in
    "FROM python:"*)
      printf 'python\n'
      ;;
    "FROM node:"*)
      printf 'npm\n'
      ;;
    "FROM debian:"*)
      printf 'base\n'
      ;;
    *)
      printf 'custom\n'
      ;;
  esac
}

project_running_services() {
  local dir="$1"
  docker compose -f "$dir/docker-compose.yml" ps --status running --services 2>/dev/null || true
}

project_status_label() {
  local project="$1"
  local dir
  dir="$(project_dir "$project")"

  if [[ ! -f "$dir/docker-compose.yml" ]]; then
    paint "$RED" "broken"
    return
  fi

  local running
  running="$(project_running_services "$dir")"
  if [[ -n "$running" ]]; then
    paint "$GREEN" "running"
  else
    paint "$YELLOW" "stopped"
  fi
}

print_codex_summary() {
  local summary="codex-lb: unknown"
  if [[ -f "$CODEX_COMPOSE_FILE" ]]; then
    local output
    output="$(docker ps --filter label=com.docker.compose.service=codex-lb --filter status=running --format {{.Names}} 2>/dev/null | tr -d "\r" || true)"
    if [[ -n "$output" ]]; then
      summary="codex-lb: $(paint "$GREEN" "running")"
    else
      summary="codex-lb: $(paint "$YELLOW" "not running")"
    fi
  else
    summary="codex-lb: $(paint "$YELLOW" "not configured")"
  fi
  print_line "$summary"
}

print_project_dashboard() {
  mapfile -t projects < <(project_names)
  if [[ ${#projects[@]} -eq 0 ]]; then
    print_line "No sandbox projects yet."
    return
  fi

  print_line "Projects:"
  local project dir repo_state secrets_state model_state running_state profile_label
  for project in "${projects[@]}"; do
    dir="$(project_dir "$project")"
    [[ -d "$dir/repo/.git" ]] && repo_state="git ready" || repo_state="repo folder"
    project_has_api_key "$project" && secrets_state="api key ready" || secrets_state="api key missing"
    [[ -f "$dir/.factory-container-settings.json" ]] && model_state="models configured" || model_state="models missing"
    running_state="$(project_status_label "$project")"
    profile_label="$(project_profile_label "$project")"
    print_line "  $(paint "$BOLD" "$project")  [$running_state]  $(paint "$DIM" "profile: $profile_label | $repo_state | $secrets_state | $model_state")"
  done
}

select_project() {
  local prompt="$1"
  local action_label="$2"
  mapfile -t projects < <(project_names)

  if [[ ${#projects[@]} -eq 0 ]]; then
    echo "No sandbox projects found in $PROJECTS_DIR" >&2
    return 1
  fi

  print_line >&2
  print_line "$prompt" >&2
  paint "$DIM" "Enter a number, or 0 to cancel." >&2
  print_line >&2
  local i=1
  local project profile_label
  for project in "${projects[@]}"; do
    profile_label="$(project_profile_label "$project")"
    print_line "  $i) $project [$(project_status_label "$project")] ($(paint "$DIM" "$profile_label"))" >&2
    ((i++))
  done
  print_line "  0) Cancel" >&2

  local choice
  while true; do
    read -r -p "$action_label [0-${#projects[@]}]: " choice >&2
    if [[ "$choice" == "0" ]]; then
      echo "Cancelled." >&2
      return 1
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#projects[@]} )); then
      printf '%s\n' "${projects[choice-1]}"
      return 0
    fi
    echo "Invalid selection. Choose a number from 0 to ${#projects[@]}." >&2
  done
}

setup_repository() {
  local repo_dir="$1"
  local repo_source

  print_section "Repository setup" "Optional. Enter a repository URL to clone, or leave this empty."
  read -r -p "Repository URL to clone, or press Enter to create an empty repo: " repo_source

  if [[ -n "$repo_source" ]]; then
    rm -rf "$repo_dir"
    git clone "$repo_source" "$repo_dir"
    return 0
  fi

  if [[ ! -d "$repo_dir/.git" ]]; then
    git -C "$repo_dir" init >/dev/null
    print_line "Initialized empty git repository in $repo_dir"
  else
    print_line "Repository already initialized in $repo_dir"
  fi
}

ensure_project_started() {
  local project="$1"
  local dir
  dir="$(project_dir "$project")"
  (
    cd "$dir"
    docker compose build
    docker compose up -d
  )
}

cleanup_project_dir() {
  local dir="$1"
  local removed=0

  rm -rf "$dir" 2>/dev/null && removed=1
  if (( removed == 1 )) || [[ ! -e "$dir" ]]; then
    return 0
  fi

  if [[ -f "$dir/docker-compose.yml" ]]; then
    (
      cd "$dir"
      docker compose run --rm --no-deps --user root -v "$dir":/cleanup droid \
        sh -lc 'rm -rf /cleanup/* /cleanup/.[!.]* /cleanup/..?* 2>/dev/null || true'
    ) >/dev/null 2>&1 || true
  fi

  rm -rf "$dir" 2>/dev/null && removed=1
  if (( removed == 1 )) || [[ ! -e "$dir" ]]; then
    return 0
  fi

  return 1
}

create_project_flow() {
  print_header
  print_section "Create sandbox project" ""

  local project_name
  project_name="$(prompt_default "Sandbox name" "my-project")"
  if [[ -z "$project_name" ]]; then
    echo "Sandbox name cannot be empty" >&2
    return 1
  fi

  local project_profile
  project_profile="$(prompt_profile)"

  local project_dir
  project_dir="$(project_dir "$project_name")"
  if [[ -e "$project_dir" ]]; then
    echo "A sandbox with this name already exists: $project_dir" >&2
    return 1
  fi

  export SANDBOX_HOME
  "$INIT_SCRIPT" "$project_name" "$project_profile" >/dev/null

  local repo_dir="$project_dir/repo"
  local env_file="$project_dir/.env"
  local secrets_file="$project_dir/.env.local"
  local settings_output="$project_dir/.factory-container-settings.json"
  local openai_api_key
  print_section "codex-lb API key" ""
  openai_api_key="$(resolve_project_api_key "$env_file" "$secrets_file")" || {
    rm -rf "$project_dir"
    return 1
  }

  "$RESOLVE_MODELS_SCRIPT" "$openai_api_key" > "$settings_output"
  setup_repository "$repo_dir"

  print_line
  paint "$GREEN" "Sandbox deployed"
  print_line
  print_line "Name: $project_name"
  print_line "Profile: $project_profile"
  print_line "Path: $project_dir"
  print_line "Repository: $repo_dir"
  print_line

  if prompt_yes_no "Build the image and start the sandbox now?" "y"; then
    ensure_project_started "$project_name"
    print_line
    print_line "Sandbox started."
    if prompt_yes_no "Open the persistent Droid session now?" "y"; then
      print_line
      print_line "Droid runs inside tmux, so it stays available after you disconnect."
      SANDBOX_PROJECTS_DIR="$PROJECTS_DIR" "$ENTER_SCRIPT" "$project_name"
    elif prompt_yes_no "Open an interactive shell instead?" "n"; then
      SANDBOX_PROJECTS_DIR="$PROJECTS_DIR" "$ENTER_SCRIPT" --shell "$project_name"
    fi
  fi
}

open_project_shell() {
  local project="$1"
  local dir
  dir="$(project_dir "$project")"
  local running
  running="$(project_running_services "$dir")"

  if [[ -z "$running" ]]; then
    if prompt_yes_no "This sandbox is stopped. Build and start it before opening a shell?" "y"; then
      ensure_project_started "$project"
    else
      return 0
    fi
  fi

  SANDBOX_PROJECTS_DIR="$PROJECTS_DIR" "$ENTER_SCRIPT" --shell "$project"
}

enter_project() {
  local project="$1"
  local dir
  dir="$(project_dir "$project")"
  local running
  running="$(project_running_services "$dir")"

  if [[ -z "$running" ]]; then
    if prompt_yes_no "This sandbox is stopped. Build and start it before opening or resuming Droid?" "y"; then
      ensure_project_started "$project"
    else
      return 0
    fi
  fi

  SANDBOX_PROJECTS_DIR="$PROJECTS_DIR" "$ENTER_SCRIPT" "$project"
}

delete_project() {
  local project="$1"
  local dir
  dir="$(project_dir "$project")"

  print_header
  print_section "Delete sandbox project" ""
  print_line "Project: $project"
  print_line "Path: $dir"
  print_line "This action permanently removes the sandbox and its local files."
  print_line

  local confirmation
  read -r -p "Type the exact project name to confirm deletion: " confirmation
  if [[ "$confirmation" != "$project" ]]; then
    echo "Deletion cancelled"
    return 0
  fi

  if [[ -f "$dir/docker-compose.yml" ]]; then
    (
      cd "$dir"
      docker compose down --remove-orphans -v || true
    )
  fi

  if cleanup_project_dir "$dir"; then
    echo "Deleted: $dir"
  else
    echo "Project cleanup failed: $dir" >&2
    echo "Some files are still owned by the container runtime. Rebuild or run cleanup from Docker before retrying." >&2
    return 1
  fi
}

show_menu() {
  print_header
  print_project_dashboard
  print_line
  paint "$BOLD$MAGENTA" "Actions"
  print_line
  print_line "  1) Create a new sandbox project"
  print_line "  2) Enter or resume Droid in a project"
  print_line "  3) Open a shell in a project"
  print_line "  4) Delete a project"
  print_line "  5) Refresh this screen"
  print_line "  0) Exit"
  print_line
}

run_action_with_project() {
  local prompt="$1"
  local action_label="$2"
  local action="$3"
  local project
  project="$(select_project "$prompt" "$action_label")" || return 0
  "$action" "$project" || true
}

require_script "$INIT_SCRIPT"
require_script "$RESOLVE_MODELS_SCRIPT"
require_script "$ENTER_SCRIPT"
mkdir -p "$PROJECTS_DIR"

while true; do
  show_menu
  read -r -p "Choose an action [0-5]: " option || exit 0

  case "$option" in
    1)
      create_project_flow
      ;;
    2)
      run_action_with_project "Choose the project where you want to open or resume Droid:" "Select project" enter_project
      ;;
    3)
      run_action_with_project "Choose the project where you want a shell:" "Select project" open_project_shell
      ;;
    4)
      run_action_with_project "Choose the project you want to delete:" "Select project" delete_project
      ;;
    5)
      ;;
    0)
      print_line "Bye"
      exit 0
      ;;
    *)
      echo "Invalid option"
      ;;
  esac

  pause_screen
done
