#!/bin/bash

# =========================================================================
# Shared utility functions for backup/restore scripts
# =========================================================================

# Locate volumes.json relative to this file
_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOLUMES_JSON="$_UTILS_DIR/../backup_restore/volumes.json"

# Source prompts if not already loaded
if ! declare -f yn_prompt &>/dev/null; then
  source "$_UTILS_DIR/prompts.sh"
fi

# -------------------------------------------------------------------------
# stop_services PROJECT_NAME
#   Stops docker compose services if running. Sets service_shutdown=true.
# -------------------------------------------------------------------------
stop_services() {
  local project="$1"
  local running_service
  running_service=$(docker compose ls --filter name="$project" --quiet)
  while [[ -n "$running_service" ]]; do
    echo "$project is running, stopping service..."
    docker compose -p "$project" stop --timeout 600
    service_shutdown=true
    running_service=$(docker compose ls --filter name="$project" --quiet)
  done
}

# -------------------------------------------------------------------------
# prompt_restart_services PROJECT_NAME
#   Prompts to restart services if they were shut down.
# -------------------------------------------------------------------------
prompt_restart_services() {
  local project="$1"
  if [[ -n "$service_shutdown" ]]; then
    read -r -p "Start $project service? (y/[n])? "
    if [[ "$REPLY" == "y" ]]; then
      docker compose -p "$project" start
    fi
  fi
}

# -------------------------------------------------------------------------
# get_volume_name PROJECT_NAME ENTRY_NAME
#   Resolves the full Docker volume name from project name + volumes.json.
# -------------------------------------------------------------------------
get_volume_name() {
  local project="$1"
  local name="$2"
  local query=".[] | select(.name == \"${name}\")"
  echo "${project}$(jq "$query | .volume_suffix" -r "$VOLUMES_JSON")"
}

# -------------------------------------------------------------------------
# get_volume_size_bytes VOLUME_NAME
#   Returns raw byte count of a Docker volume's contents.
# -------------------------------------------------------------------------
get_volume_size_bytes() {
  local volume="$1"
  docker run --rm -v "${volume}":/data:ro alpine du -sb /data 2>/dev/null | awk '{print $1}'
}

# -------------------------------------------------------------------------
# get_available_disk_bytes PATH
#   Returns available bytes on the filesystem containing the given path.
# -------------------------------------------------------------------------
get_available_disk_bytes() {
  local path="$1"
  df --output=avail -B1 "$path" 2>/dev/null | tail -1 | tr -d ' '
}

# -------------------------------------------------------------------------
# human_readable BYTES
#   Converts bytes to human-readable format (e.g. "4.2 GiB").
# -------------------------------------------------------------------------
human_readable() {
  local bytes="$1"
  if command -v numfmt &>/dev/null; then
    numfmt --to=iec-i --suffix=B "$bytes"
  else
    awk "BEGIN {
      b=$bytes;
      if (b >= 1073741824) printf \"%.1f GiB\", b/1073741824;
      else if (b >= 1048576) printf \"%.1f MiB\", b/1048576;
      else if (b >= 1024) printf \"%.1f KiB\", b/1024;
      else printf \"%d B\", b;
    }"
  fi
}

# -------------------------------------------------------------------------
# check_ssh_connectivity REMOTE_SPEC
#   Validates SSH connectivity. Returns 0 on success, 1 on failure.
# -------------------------------------------------------------------------
check_ssh_connectivity() {
  local remote="$1"
  echo "Checking SSH connectivity to $remote..."
  if ssh -o ConnectTimeout=5 -o BatchMode=yes "$remote" "echo ok" &>/dev/null; then
    echo "  --> SSH connection OK"
    return 0
  else
    echo "  --> ERROR: Cannot connect to $remote via SSH"
    return 1
  fi
}

# -------------------------------------------------------------------------
# prompt_project_name [DEFAULT_NAME]
#   Interactively prompts for project name if not already set.
#   Sets PROJECT_NAME variable.
# -------------------------------------------------------------------------
prompt_project_name() {
  if [[ -z "$PROJECT_NAME" ]]; then
    local default_project="deployment-scripts"
    local current_project
    current_project=$(docker compose ls --all --quiet | head -1)
    PROJECT_NAME=${current_project:-$default_project}

    read -r -p "Confirm project name [$PROJECT_NAME]: "
    if [[ -n "$REPLY" ]]; then
      PROJECT_NAME="$REPLY"
    fi
  fi
  echo "Project name: '$PROJECT_NAME'"
}

# -------------------------------------------------------------------------
# disk_space_check PROJECT_NAME OUTPUT_PATH
#   Estimates backup sizes and compares against available disk space.
#   Returns 0 if sufficient, 1 if insufficient.
# -------------------------------------------------------------------------
disk_space_check() {
  local project="$1"
  local output_path="$2"

  echo ""
  echo "Checking disk space requirements..."
  echo ""

  local total_raw=0
  local total_estimated=0

  # Header
  printf "  %-20s %12s %16s\n" "Volume" "Raw Size" "Est. Compressed"
  printf "  %-20s %12s %16s\n" "------" "--------" "---------------"

  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    local volume
    volume=$(get_volume_name "$project" "$name")
    local raw_bytes
    raw_bytes=$(get_volume_size_bytes "$volume")

    if [[ -z "$raw_bytes" || "$raw_bytes" == "0" ]]; then
      printf "  %-20s %12s %16s\n" "$name" "(empty)" "~0 B"
      continue
    fi

    local estimated=$((raw_bytes / 2))
    total_raw=$((total_raw + raw_bytes))
    total_estimated=$((total_estimated + estimated))

    printf "  %-20s %12s %16s\n" "$name" "$(human_readable "$raw_bytes")" "~$(human_readable "$estimated")"
  done

  printf "  %-20s %12s %16s\n" "------" "--------" "---------------"
  printf "  %-20s %12s %16s\n" "Total" "$(human_readable "$total_raw")" "~$(human_readable "$total_estimated")"

  # Check available space
  mkdir -p "$output_path" 2>/dev/null
  local available
  available=$(get_available_disk_bytes "$output_path")

  echo ""
  echo "  Available disk:    $(human_readable "$available")"

  if [[ "$total_estimated" -gt "$available" ]]; then
    echo ""
    echo "  WARNING: Estimated backup size exceeds available disk space!"
    echo "  Recommendation: Use --mode ssh or --mode sequential"
    return 1
  else
    echo ""
    echo "  OK: Sufficient disk space for local backup."
    return 0
  fi
}
