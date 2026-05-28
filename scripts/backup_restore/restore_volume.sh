#!/bin/bash
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/backup_utils.sh"

# -------------------------------------------------------------------------
# Usage
# -------------------------------------------------------------------------
usage() {
  cat <<'USAGE'
Usage: restore_volume.sh [OPTIONS]

Restore Docker volumes from backup.

Options:
  -i, --input PATH        Path to backup folder or .tar/.tar.gz archive (local restore)
  -n, --name NAME         Project name (default: auto-detect)
  -m, --mode MODE         Restore mode: local (default), ssh
  -r, --remote USER@HOST  Remote source (the OLD server, for ssh mode)
  -p, --remote-path PATH  Remote path containing backup files (required for ssh mode)
  -h, --help              Show this help message

Modes:
  local   Restore from local folder or archive. (Default)
  ssh     Pull backup files directly from remote server via SSH into volumes.

Examples:
  ./restore_volume.sh -i ~/scv2_backups/volume_backup-2026-02-14T10_00_00
  ./restore_volume.sh -i ~/scv2_backups/volume_backup-2026-02-14T10_00_00.tar.gz
  ./restore_volume.sh --mode ssh -r user@oldbox -p ~/scv2_backups/volume_backup-2026-02-14T10_00_00
USAGE
}

# -------------------------------------------------------------------------
# Parse arguments
# -------------------------------------------------------------------------
MODE="local"
BACKUP_INPUT=""
PROJECT_NAME=""
REMOTE_SPEC=""
REMOTE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input)       BACKUP_INPUT="$2"; BACKUP_INPUT="${BACKUP_INPUT/#~/$HOME}"; shift 2 ;;
    -n|--name)        PROJECT_NAME="$2"; shift 2 ;;
    -m|--mode)        MODE="$2"; shift 2 ;;
    -r|--remote)      REMOTE_SPEC="$2"; shift 2 ;;
    -p|--remote-path) REMOTE_PATH="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Validate mode
case "$MODE" in
  local|ssh) ;;
  *) echo "Error: Unknown mode '$MODE'. Use: local, ssh"; exit 1 ;;
esac

if [[ "$MODE" == "ssh" ]]; then
  if [[ -z "$REMOTE_SPEC" ]]; then
    echo "Error: --remote is required for ssh mode"
    exit 1
  fi
  if [[ -z "$REMOTE_PATH" ]]; then
    echo "Error: --remote-path is required for ssh mode"
    exit 1
  fi
fi

# -------------------------------------------------------------------------
# Pre-pull the Docker image so it's cached before any piped commands.
# Without this, a pull during 'ssh ... | docker run ...' would stall
# the SSH side (no data flowing) and cause broken pipe errors.
# -------------------------------------------------------------------------
ensure_docker_image "ubuntu"

# Teardown ssh multiplex (if any) on exit.
trap teardown_ssh_multiplex EXIT

# find_backup_file PATH NAME
#   Echoes the first existing backup filename for volume NAME in PATH,
#   preferring uncompressed .tar over .tar.gz. Empty if neither exists.
find_backup_file() {
  local path="$1" name="$2"
  if [[ -f "${path}/${name}.tar" ]]; then
    echo "${name}.tar"
  elif [[ -f "${path}/${name}.tar.gz" ]]; then
    echo "${name}.tar.gz"
  fi
}

# remote_backup_file REMOTE PATH NAME
#   Same as find_backup_file but on a remote host. Empty if neither exists.
remote_backup_file() {
  local remote="$1" path="$2" name="$3"
  if ssh $(ssh_mux_opts) "$remote" "test -f ${path}/${name}.tar" 2>/dev/null; then
    echo "${name}.tar"
  elif ssh $(ssh_mux_opts) "$remote" "test -f ${path}/${name}.tar.gz" 2>/dev/null; then
    echo "${name}.tar.gz"
  fi
}

# tar_extract_flag FILENAME
#   Echoes "xzf" for .tar.gz, "xf" for .tar.
tar_extract_flag() {
  case "$1" in
    *.tar.gz) echo "xzf" ;;
    *.tar)    echo "xf" ;;
    *)        echo "xzf" ;;  # legacy default
  esac
}

# =========================================================================
# MODE: local
# =========================================================================
if [[ "$MODE" == "local" ]]; then

  # Prompt for input if not provided
  echo ""
  if [[ -z "$BACKUP_INPUT" ]]; then
    read -e -p "Enter the path to backup folder or archive: " BACKUP_INPUT
    # Replace tilde if given
    BACKUP_INPUT="${BACKUP_INPUT/#~/$HOME}"
  fi

  if [[ ! -e "$BACKUP_INPUT" ]]; then
    echo "Error: '$BACKUP_INPUT' does not exist."
    exit 1
  fi

  # Handle archive vs. directory input
  if [[ -f "$BACKUP_INPUT" && ( "$BACKUP_INPUT" == *.tar.gz || "$BACKUP_INPUT" == *.tar ) ]]; then
    echo "Archive file detected, extracting..."
    TEMP_DIR=$(mktemp -d)
    if [[ "$BACKUP_INPUT" == *.tar.gz ]]; then
      tar -xzf "$BACKUP_INPUT" -C "$TEMP_DIR"
    else
      tar -xf "$BACKUP_INPUT" -C "$TEMP_DIR"
    fi

    # Find the extracted directory (the backup folder inside the archive)
    EXTRACTED_DIRS=("$TEMP_DIR"/*/)
    if [[ ${#EXTRACTED_DIRS[@]} -eq 1 && -d "${EXTRACTED_DIRS[0]}" ]]; then
      BACKUP_PATH="${EXTRACTED_DIRS[0]}"
    else
      # Files extracted flat into TEMP_DIR
      BACKUP_PATH="$TEMP_DIR"
    fi
    CLEANUP_TEMP=true
  elif [[ -d "$BACKUP_INPUT" ]]; then
    BACKUP_PATH="$(cd "$BACKUP_INPUT" && pwd)"
    CLEANUP_TEMP=false
  else
    echo "Error: '$BACKUP_INPUT' is not a directory or .tar/.tar.gz file."
    exit 1
  fi

  echo "Backup path: $BACKUP_PATH"

  # Project name
  echo ""
  prompt_project_name

  # Verify backup contents
  echo ""
  echo "Checking backup contents in: $BACKUP_PATH"
  found_any=false
  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    backup_file=$(find_backup_file "$BACKUP_PATH" "$name")
    if [[ -n "$backup_file" ]]; then
      echo "  Found: $backup_file"
      found_any=true
    else
      echo "  Missing: ${name}.tar or ${name}.tar.gz (will skip)"
    fi
  done

  if [[ "$found_any" == "false" ]]; then
    echo ""
    echo "Error: No matching backup files found in '$BACKUP_PATH'."
    echo "Expected files like: dbserver.tar, mongo.tar (or .tar.gz)."
    exit 1
  fi

  # Ensure software is offline
  stop_services "$PROJECT_NAME"

  # Restore all volumes individually
  echo ""
  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    backup_file=$(find_backup_file "$BACKUP_PATH" "$name")
    if [[ -z "$backup_file" ]]; then
      echo "Skipping $name (no backup file found)"
      continue
    fi

    echo "Restoring $name from $backup_file"
    volume=$(get_volume_name "$PROJECT_NAME" "$name")
    flag=$(tar_extract_flag "$backup_file")

    docker run --rm \
      -v "${volume}":/data \
      --mount type=bind,src="$BACKUP_PATH",dst=/backup,readonly \
      ubuntu tar $flag /backup/${backup_file} -C /

    if [[ $? -eq 0 ]]; then
      echo "  --> $name restored successfully"
    else
      echo "  --> ERROR: Failed to restore $name"
    fi
  done

  # Clean up temp directory if we extracted an archive
  if [[ "$CLEANUP_TEMP" == "true" ]]; then
    echo ""
    echo "Cleaning up temporary extraction directory..."
    rm -rf "$TEMP_DIR"
  fi

# =========================================================================
# MODE: ssh (pull from remote server, zero local archive storage)
# =========================================================================
elif [[ "$MODE" == "ssh" ]]; then

  # Project name
  echo ""
  prompt_project_name

  check_ssh_connectivity "$REMOTE_SPEC" || exit 1
  setup_ssh_multiplex "$REMOTE_SPEC"

  # Verify remote backup contents
  echo ""
  echo "Checking remote backup contents at ${REMOTE_SPEC}:${REMOTE_PATH}..."
  declare -A REMOTE_BACKUP_FILES=()
  found_any=false
  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    backup_file=$(remote_backup_file "$REMOTE_SPEC" "$REMOTE_PATH" "$name")
    if [[ -n "$backup_file" ]]; then
      echo "  Found: $backup_file"
      REMOTE_BACKUP_FILES[$name]="$backup_file"
      found_any=true
    else
      echo "  Missing: ${name}.tar or ${name}.tar.gz (will skip)"
    fi
  done

  if [[ "$found_any" == "false" ]]; then
    echo ""
    echo "Error: No backup files found at ${REMOTE_SPEC}:${REMOTE_PATH}"
    exit 1
  fi

  # Ensure software is offline
  stop_services "$PROJECT_NAME"

  # Restore each volume by streaming from remote
  echo ""
  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    backup_file="${REMOTE_BACKUP_FILES[$name]}"
    if [[ -z "$backup_file" ]]; then
      echo "Skipping $name (not found on remote)"
      continue
    fi

    echo "Restoring $name from ${REMOTE_SPEC}:${REMOTE_PATH}/${backup_file}"
    volume=$(get_volume_name "$PROJECT_NAME" "$name")
    flag=$(tar_extract_flag "$backup_file")

    ssh $(fast_ssh_opts) "$REMOTE_SPEC" "cat ${REMOTE_PATH}/${backup_file}" \
      | docker run --rm -i -v "${volume}":/data ubuntu tar $flag - -C /

    if [[ $? -eq 0 ]]; then
      echo "  --> $name restored successfully"
    else
      echo "  --> ERROR: Failed to restore $name"
    fi
  done

fi

# -------------------------------------------------------------------------
# Prompt to restart service if we shut it down
# -------------------------------------------------------------------------
prompt_restart_services "$PROJECT_NAME"

echo ""
echo "Restore complete!"
