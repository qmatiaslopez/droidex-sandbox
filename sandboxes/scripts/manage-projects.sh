#!/usr/bin/env bash
set -euo pipefail

STACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX_HOME="${SANDBOX_HOME:-$STACK_ROOT/sandboxes}"
PROJECTS_DIR="${SANDBOX_PROJECTS_DIR:-$SANDBOX_HOME/projects}"
INIT_SCRIPT="$SANDBOX_HOME/base/scripts/init-project.sh"
RESOLVE_MODELS_SCRIPT="$SANDBOX_HOME/scripts/resolve-models.sh"
ENTER_SCRIPT="$SANDBOX_HOME/base/scripts/enter-sandbox.sh"
CODEX_COMPOSE_FILE="${CODEX_COMPOSE_FILE:-$STACK_ROOT/codex-lb/docker-compose.yaml}"

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
  local value
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
  local project dir repo_state secrets_state model_state running_state
  for project in "${projects[@]}"; do
    dir="$(project_dir "$project")"
    [[ -d "$dir/repo/.git" ]] && repo_state="git" || repo_state="repo"
    [[ -f "$dir/.env.local" ]] && secrets_state="secret" || secrets_state="no-secret"
    [[ -f "$dir/.factory-container-settings.json" ]] && model_state="models" || model_state="no-models"
    running_state="$(project_status_label "$project")"
    print_line "  $(paint "$BOLD" "$project")  [$running_state]  $(paint "$DIM" "$repo_state | $secrets_state | $model_state")"
  done
}

select_project() {
  local prompt="$1"
  mapfile -t projects < <(project_names)

  if [[ ${#projects[@]} -eq 0 ]]; then
    echo "No sandbox projects found in $PROJECTS_DIR" >&2
    return 1
  fi

  print_line >&2
  print_line "$prompt" >&2
  local i=1
  local project
  for project in "${projects[@]}"; do
    print_line "  $i) $project [$(project_status_label "$project")]" >&2
    ((i++))
  done

  local choice
  read -r -p "Select a project [1-${#projects[@]}]: " choice >&2
  if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#projects[@]} )); then
    echo "Invalid selection" >&2
    return 1
  fi

  printf '%s
' "${projects[choice-1]}"
}

setup_repository() {
  local repo_dir="$1"
  local repo_source

  print_line
  paint "$BOLD$BLUE" "Repository setup"
  print_line
  print_line "Leave blank to create a new local git repository."
  read -r -p "Repository URL to clone (optional): " repo_source

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

create_project_flow() {
  print_header
  paint "$BOLD$BLUE" "Create sandbox project"
  print_line

  local project_name
  project_name="$(prompt_default "Sandbox name" "my-project")"
  if [[ -z "$project_name" ]]; then
    echo "Sandbox name cannot be empty" >&2
    return 1
  fi

  local project_dir
  project_dir="$(project_dir "$project_name")"
  if [[ -e "$project_dir" ]]; then
    echo "Project sandbox already exists: $project_dir" >&2
    return 1
  fi

  local openai_api_key
  read -r -s -p "OPENAI_API_KEY: " openai_api_key
  echo
  if [[ -z "$openai_api_key" ]]; then
    echo "OPENAI_API_KEY cannot be empty" >&2
    return 1
  fi

  export SANDBOX_HOME
  "$INIT_SCRIPT" "$project_name"

  local repo_dir="$project_dir/repo"
  local secrets_file="$project_dir/.env.local"
  local settings_output="$project_dir/.factory-container-settings.json"

  cat > "$secrets_file" <<EOF_KEY
OPENAI_API_KEY=$openai_api_key
EOF_KEY
  chmod 600 "$secrets_file"

  "$RESOLVE_MODELS_SCRIPT" "$openai_api_key" > "$settings_output"
  setup_repository "$repo_dir"

  print_line
  paint "$GREEN" "Sandbox deployed"
  print_line
  print_line "Path: $project_dir"
  print_line "Repo: $repo_dir"

  if prompt_yes_no "Build and start the sandbox now?" "y"; then
    ensure_project_started "$project_name"
    print_line "Sandbox started."
    if prompt_yes_no "Open Droid now?" "y"; then
      SANDBOX_PROJECTS_DIR="$PROJECTS_DIR" "$ENTER_SCRIPT" "$project_name"
    elif prompt_yes_no "Open a shell in the sandbox now?" "n"; then
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
    if prompt_yes_no "Project is not running. Build and start it now?" "y"; then
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
    if prompt_yes_no "Project is not running. Build and start it now?" "y"; then
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
  paint "$BOLD$RED" "Delete sandbox project"
  print_line
  print_line "Project: $project"
  print_line "Path: $dir"
  print_line "This removes repo data, local secrets, Droid settings, and compose files."

  local confirmation
  read -r -p "Type the project name to confirm deletion: " confirmation
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

  rm -rf "$dir"
  echo "Deleted: $dir"
}

show_menu() {
  print_header
  print_project_dashboard
  print_line
  paint "$BOLD$MAGENTA" "Actions"
  print_line
  print_line "  1) Create project"
  print_line "  2) Enter Droid"
  print_line "  3) Open sandbox shell"
  print_line "  4) Delete project"
  print_line "  5) Refresh screen"
  print_line "  0) Exit"
  print_line
}

run_action_with_project() {
  local prompt="$1"
  local action="$2"
  local project
  project="$(select_project "$prompt")" || return 0
  "$action" "$project" || true
}

require_script "$INIT_SCRIPT"
require_script "$RESOLVE_MODELS_SCRIPT"
require_script "$ENTER_SCRIPT"
mkdir -p "$PROJECTS_DIR"

while true; do
  show_menu
  read -r -p "Choose an option [0-5]: " option || exit 0

  case "$option" in
    1)
      create_project_flow
      ;;
    2)
      run_action_with_project "Choose a project to enter:" enter_project
      ;;
    3)
      run_action_with_project "Choose a project shell:" open_project_shell
      ;;
    4)
      run_action_with_project "Choose a project to delete:" delete_project
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
