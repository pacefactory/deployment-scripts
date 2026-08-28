#!/bin/bash
set -o pipefail

# =========================================================================
# Backup configuration files only (not data) from selected Docker volumes.
#
# Unlike backup_volume.sh which backs up entire volumes (data + config),
# this script targets only configuration files — useful for quick config
# snapshots without backing up large data stores.
#
# Supported containers:
#   realtime    - selective: config/ and resources/ only (excl. backgrounds)
#   auditgui    - entire volume (all config)
#   rdb         - entire volume (all config)
#   nodered     - entire volume (flows, settings)
#   ape         - entire volume (JSON configs)
#
# Services are NOT stopped — config-only backup is safe while running.
# =========================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/backup_utils.sh"

# -------------------------------------------------------------------------
# Config volume names (must match entries in volumes.json)
# -------------------------------------------------------------------------
CONFIG_VOLUMES=( realtime auditgui rdb nodered ape )

# -------------------------------------------------------------------------
# Signal handling: clean up containers and partial files on Ctrl+C
# -------------------------------------------------------------------------
_BACKUP_CONTAINER_PREFIX="scv2-cfgbackup-$$"
_CURRENT_OUTPUT_FILE=""

cleanup() {
  echo ""
  echo "Interrupted! Cleaning up..."

  local containers
  containers=$(docker ps --filter "name=${_BACKUP_CONTAINER_PREFIX}" -q 2>/dev/null)
  if [[ -n "$containers" ]]; then
    echo "Stopping backup containers..."
    docker kill $containers &>/dev/null
  fi

  if [[ -n "$_CURRENT_OUTPUT_FILE" && -f "$_CURRENT_OUTPUT_FILE" ]]; then
    echo "Removing partial file: $_CURRENT_OUTPUT_FILE"
    rm -f "$_CURRENT_OUTPUT_FILE"
  fi

  exit 130
}

trap cleanup INT TERM

# -------------------------------------------------------------------------
# Usage
# -------------------------------------------------------------------------
usage() {
  cat <<'USAGE'
Usage: backup_config.sh [OPTIONS]

Backup configuration files from Docker volumes (configs only, not data).

Backs up configs from: realtime, auditgui, rdb, nodered, ape.
Volumes that don't exist in the current deployment are skipped automatically.
Services are NOT stopped — config backup is safe while running.

Options:
  -n, --name NAME         Project name (default: auto-detect)
  -o, --output DIR        Backup output directory (default: ~/scv2_backups)
  -h, --help              Show this help message
USAGE
}

# -------------------------------------------------------------------------
# Parse arguments
# -------------------------------------------------------------------------
PROJECT_NAME=""
BACKUPS_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)   PROJECT_NAME="$2"; shift 2 ;;
    -o|--output) BACKUPS_ROOT="$2"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# -------------------------------------------------------------------------
# Project name
# -------------------------------------------------------------------------
echo ""
prompt_project_name

# -------------------------------------------------------------------------
# Output path
# -------------------------------------------------------------------------
export_name="config_backup-$(date +"%Y-%m-%dT%H_%M_%S")"
backups_path="${BACKUPS_ROOT:-$HOME/scv2_backups}"
output_folder_path="$backups_path/$export_name"

echo ""
echo "Creating directory $output_folder_path"
mkdir -p "$output_folder_path"

# -------------------------------------------------------------------------
# Pre-pull Docker image
# -------------------------------------------------------------------------
ensure_docker_image "ubuntu"

# -------------------------------------------------------------------------
# Backup each config volume
# -------------------------------------------------------------------------
backed_up_any=false

for name in "${CONFIG_VOLUMES[@]}"; do
  volume=$(get_volume_name "$PROJECT_NAME" "$name")

  if ! volume_exists "$volume"; then
    echo "Skipping $name (volume '$volume' does not exist)"
    continue
  fi

  echo "Backing up $name config"
  backed_up_any=true
  _CURRENT_OUTPUT_FILE="$output_folder_path/${name}.tar.gz"

  if [[ "$name" == "realtime" ]]; then
    # Realtime has data mixed with config. Only back up config/ and
    # resources/ directories under localhost/*/. Exclude backgrounds.
    docker run --rm --log-driver none \
      --name "${_BACKUP_CONTAINER_PREFIX}" \
      -v "${volume}":/data:ro ubuntu \
      /bin/bash -c 'cd /data && find localhost -mindepth 2 -maxdepth 2 \( -name "config" -o -name "resources" \) | tar czf - --exclude="*/resources/backgrounds" --files-from -' \
      > "$output_folder_path/${name}.tar.gz"
  else
    # All other config volumes: back up the entire volume contents
    docker run --rm --log-driver none \
      --name "${_BACKUP_CONTAINER_PREFIX}" \
      -v "${volume}":/data:ro ubuntu \
      tar czf - data \
      > "$output_folder_path/${name}.tar.gz"
  fi

  if [[ $? -ne 0 ]]; then
    echo "  --> ERROR: Backup of $name failed!"
    rm -f "$output_folder_path/${name}.tar.gz"
    _CURRENT_OUTPUT_FILE=""
    continue
  fi

  file_size=$(stat -c%s "$output_folder_path/${name}.tar.gz" 2>/dev/null || stat -f%z "$output_folder_path/${name}.tar.gz" 2>/dev/null)
  echo "  --> Backup complete: ${name}.tar.gz ($(human_readable "${file_size:-0}"))"
  _CURRENT_OUTPUT_FILE=""
done

if [[ "$backed_up_any" == "false" ]]; then
  echo ""
  echo "ERROR: No config volumes were available to back up."
  echo "Check that your project name is correct and that volumes exist."
  exit 1
fi

echo ""
echo "Config backup complete: $output_folder_path"
