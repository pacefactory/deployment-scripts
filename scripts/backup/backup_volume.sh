#!/bin/bash
set -o pipefail

# =========================================================================
# MIGRATION WORKFLOWS
#
# Same network (zero local disk on old server):
#   Old: ./scripts/backup/backup_volume.sh --mode ssh -r user@newserver
#   New: ./scripts/restore/restore_volume.sh -i ~/scv2_backups/...
#
# Same network (new server pulls, zero disk on new server):
#   Old: ./scripts/backup/backup_volume.sh
#   New: ./scripts/restore/restore_volume.sh --mode ssh -r user@oldserver -p /path/to/backup
#
# Not on same network:
#   Old: ./scripts/backup/backup_volume.sh --mode sequential
#   (transfer each file via USB/cloud when prompted)
#   New: ./scripts/restore/restore_volume.sh -i /path/where/files/were/placed
# =========================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/backup_utils.sh"

# -------------------------------------------------------------------------
# Usage
# -------------------------------------------------------------------------
usage() {
  cat <<'USAGE'
Usage: backup_volume.sh [OPTIONS]
       backup_volume.sh [PROJECT_NAME] [BACKUPS_ROOT]   (legacy positional args)

Backup Docker volumes to tar.gz archives.

Options:
  -n, --name NAME         Project name (default: auto-detect)
  -o, --output DIR        Local backup output directory (default: ~/scv2_backups)
  -m, --mode MODE         Backup mode: local (default), ssh, sequential
  -r, --remote USER@HOST  Remote destination for ssh/sequential mode
  -p, --remote-path PATH  Remote path for ssh mode (default: ~/scv2_backups/<timestamp>)
      --no-images         Skip .jpg files from dbserver (non-interactive)
      --check-only        Run disk space pre-flight check and exit
  -h, --help              Show this help message

Modes:
  local        Back up all volumes to local folder. (Default, original behavior)
  ssh          Stream each volume directly to remote via SSH. Zero local disk usage.
  sequential   Back up one volume at a time, prompt to transfer, delete before next.
USAGE
}

# -------------------------------------------------------------------------
# Parse arguments
# -------------------------------------------------------------------------
MODE="local"
REMOTE_SPEC=""
REMOTE_PATH=""
SKIP_IMAGES=""
CHECK_ONLY=""
PROJECT_NAME=""
BACKUPS_ROOT=""

# Backward compat: detect old positional usage (first arg not starting with -)
if [[ $# -ge 1 && "$1" != -* ]]; then
  PROJECT_NAME="$1"
  [[ $# -ge 2 && "$2" != -* ]] && BACKUPS_ROOT="$2"
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--name)        PROJECT_NAME="$2"; shift 2 ;;
      -o|--output)      BACKUPS_ROOT="$2"; shift 2 ;;
      -m|--mode)        MODE="$2"; shift 2 ;;
      -r|--remote)      REMOTE_SPEC="$2"; shift 2 ;;
      -p|--remote-path) REMOTE_PATH="$2"; shift 2 ;;
      --no-images)      SKIP_IMAGES=true; shift ;;
      --check-only)     CHECK_ONLY=true; shift ;;
      -h|--help)        usage; exit 0 ;;
      *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
  done
fi

# Validate mode
case "$MODE" in
  local|ssh|sequential) ;;
  *) echo "Error: Unknown mode '$MODE'. Use: local, ssh, sequential"; exit 1 ;;
esac

if [[ "$MODE" == "ssh" && -z "$REMOTE_SPEC" ]]; then
  echo "Error: --remote is required for ssh mode"
  exit 1
fi

# -------------------------------------------------------------------------
# Project name
# -------------------------------------------------------------------------
echo ""
prompt_project_name

# -------------------------------------------------------------------------
# Pathing
# -------------------------------------------------------------------------
export_name="volume_backup-$(date +"%Y-%m-%dT%H_%M_%S")"

backups_path="${BACKUPS_ROOT:-$HOME/scv2_backups}"
output_folder_path="$backups_path/$export_name"

if [[ "$MODE" == "ssh" && -z "$REMOTE_PATH" ]]; then
  REMOTE_PATH="~/scv2_backups/$export_name"
fi

# -------------------------------------------------------------------------
# Check-only mode: pre-flight disk check and exit
# -------------------------------------------------------------------------
if [[ "$CHECK_ONLY" == "true" ]]; then
  disk_space_check "$PROJECT_NAME" "$backups_path"
  exit $?
fi

# -------------------------------------------------------------------------
# Pre-flight check for local mode
# -------------------------------------------------------------------------
if [[ "$MODE" == "local" ]]; then
  if ! disk_space_check "$PROJECT_NAME" "$backups_path"; then
    echo ""
    read -r -p "Insufficient space detected. Continue anyway? (y/[n]): "
    if [[ "$REPLY" != "y" ]]; then
      echo "Aborting. Use --mode ssh or --mode sequential instead."
      exit 1
    fi
  fi
fi

# -------------------------------------------------------------------------
# Determine dbserver image handling
# -------------------------------------------------------------------------
if [[ -z "$SKIP_IMAGES" ]]; then
  # Will prompt interactively when we reach dbserver
  :
fi

# -------------------------------------------------------------------------
# Ensure software is offline
# -------------------------------------------------------------------------
stop_services "$PROJECT_NAME"

# =========================================================================
# MODE: local (original behavior)
# =========================================================================
if [[ "$MODE" == "local" ]]; then

  echo ""
  echo "Creating directory $output_folder_path"
  mkdir -p "$output_folder_path"

  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    echo "Backing up $name"
    volume=$(get_volume_name "$PROJECT_NAME" "$name")

    if [[ "$name" == "dbserver" ]]; then
      if [[ "$SKIP_IMAGES" == "true" ]]; then
        echo "  --> Will NOT backup dbserver images (--no-images)"
        docker run --rm -v "${volume}":/data:ro ubuntu /bin/bash -c 'find data -type f ! -name "*.jpg" | tar czf - -T -' > "$output_folder_path/${name}.tar.gz"
      else
        read -p "Backup images from dbserver? (y/[N])"
        if [[ "$REPLY" == "y" ]]; then
          echo "  --> Will backup dbserver images!"
          docker run --rm -v "${volume}":/data:ro ubuntu tar czf - data > "$output_folder_path/${name}.tar.gz"
        else
          echo "  --> Will NOT backup dbserver images!"
          docker run --rm -v "${volume}":/data:ro ubuntu /bin/bash -c 'find data -type f ! -name "*.jpg" | tar czf - -T -' > "$output_folder_path/${name}.tar.gz"
        fi
      fi
    else
      docker run --rm -v "${volume}":/data:ro ubuntu tar czf - data > "$output_folder_path/${name}.tar.gz"
    fi

    if [[ $? -ne 0 ]]; then
      echo "ERROR: Backup of $name failed!"
      rm -f "$output_folder_path/${name}.tar.gz"
      continue
    fi
  done

  echo ""
  echo "Backup complete: $output_folder_path"

# =========================================================================
# MODE: ssh (stream directly to remote, zero local disk)
# =========================================================================
elif [[ "$MODE" == "ssh" ]]; then

  check_ssh_connectivity "$REMOTE_SPEC" || exit 1

  echo ""
  echo "Creating remote directory ${REMOTE_SPEC}:${REMOTE_PATH}"
  ssh "$REMOTE_SPEC" "mkdir -p $REMOTE_PATH"

  # Copy volumes.json to remote for reference during restore
  scp -q "$VOLUMES_JSON" "${REMOTE_SPEC}:${REMOTE_PATH}/volumes.json"

  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    echo "Streaming $name to ${REMOTE_SPEC}:${REMOTE_PATH}/${name}.tar.gz"
    volume=$(get_volume_name "$PROJECT_NAME" "$name")

    if [[ "$name" == "dbserver" ]]; then
      if [[ "$SKIP_IMAGES" == "true" ]]; then
        echo "  --> Excluding dbserver images (--no-images)"
        docker run --rm -v "${volume}":/data:ro ubuntu /bin/bash -c 'find data -type f ! -name "*.jpg" | tar czf - -T -' \
          | ssh "$REMOTE_SPEC" "cat > ${REMOTE_PATH}/${name}.tar.gz"
      else
        read -p "Backup images from dbserver? (y/[N])"
        if [[ "$REPLY" == "y" ]]; then
          echo "  --> Will backup dbserver images!"
          docker run --rm -v "${volume}":/data:ro ubuntu tar czf - data \
            | ssh "$REMOTE_SPEC" "cat > ${REMOTE_PATH}/${name}.tar.gz"
        else
          echo "  --> Will NOT backup dbserver images!"
          docker run --rm -v "${volume}":/data:ro ubuntu /bin/bash -c 'find data -type f ! -name "*.jpg" | tar czf - -T -' \
            | ssh "$REMOTE_SPEC" "cat > ${REMOTE_PATH}/${name}.tar.gz"
        fi
      fi
    else
      docker run --rm -v "${volume}":/data:ro ubuntu tar czf - data \
        | ssh "$REMOTE_SPEC" "cat > ${REMOTE_PATH}/${name}.tar.gz"
    fi

    if [[ $? -ne 0 ]]; then
      echo "ERROR: Streaming backup of $name failed!"
      echo "  --> Removing partial remote file"
      ssh "$REMOTE_SPEC" "rm -f ${REMOTE_PATH}/${name}.tar.gz"
      continue
    fi

    echo "  --> $name streamed successfully"
  done

  echo ""
  echo "SSH backup complete: ${REMOTE_SPEC}:${REMOTE_PATH}"

# =========================================================================
# MODE: sequential (one-at-a-time, prompt to transfer, free disk between)
# =========================================================================
elif [[ "$MODE" == "sequential" ]]; then

  echo ""
  echo "Creating directory $output_folder_path"
  mkdir -p "$output_folder_path"

  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    volume=$(get_volume_name "$PROJECT_NAME" "$name")
    local_file="$output_folder_path/${name}.tar.gz"

    echo ""
    echo "=== Backing up: $name ==="

    # Per-volume disk space check
    vol_size=$(get_volume_size_bytes "$volume")
    if [[ -n "$vol_size" && "$vol_size" -gt 0 ]]; then
      estimated_compressed=$((vol_size / 2))
      available=$(get_available_disk_bytes "$output_folder_path")

      if [[ "$estimated_compressed" -gt "$available" ]]; then
        echo "WARNING: Estimated compressed size (~$(human_readable "$estimated_compressed")) may exceed"
        echo "         available disk space ($(human_readable "$available"))."
        read -r -p "Proceed anyway? (y/[n]): "
        if [[ "$REPLY" != "y" ]]; then
          echo "  --> Skipping $name"
          continue
        fi
      fi
    fi

    # Perform backup
    if [[ "$name" == "dbserver" ]]; then
      if [[ "$SKIP_IMAGES" == "true" ]]; then
        echo "  --> Excluding dbserver images (--no-images)"
        docker run --rm -v "${volume}":/data:ro ubuntu /bin/bash -c 'find data -type f ! -name "*.jpg" | tar czf - -T -' > "$local_file"
      else
        read -p "Backup images from dbserver? (y/[N])"
        if [[ "$REPLY" == "y" ]]; then
          echo "  --> Will backup dbserver images!"
          docker run --rm -v "${volume}":/data:ro ubuntu tar czf - data > "$local_file"
        else
          echo "  --> Will NOT backup dbserver images!"
          docker run --rm -v "${volume}":/data:ro ubuntu /bin/bash -c 'find data -type f ! -name "*.jpg" | tar czf - -T -' > "$local_file"
        fi
      fi
    else
      docker run --rm -v "${volume}":/data:ro ubuntu tar czf - data > "$local_file"
    fi

    if [[ $? -ne 0 ]]; then
      echo "ERROR: Backup of $name failed!"
      rm -f "$local_file"
      continue
    fi

    file_size=$(stat -c%s "$local_file" 2>/dev/null || stat -f%z "$local_file" 2>/dev/null)
    echo "  --> Created: $local_file ($(human_readable "${file_size:-0}"))"

    # If remote is specified, transfer automatically via scp
    if [[ -n "$REMOTE_SPEC" ]]; then
      remote_dest="${REMOTE_PATH:-~/scv2_backups/$export_name}"
      ssh "$REMOTE_SPEC" "mkdir -p $remote_dest" 2>/dev/null
      echo "  --> Transferring to ${REMOTE_SPEC}:${remote_dest}/${name}.tar.gz"
      scp -q "$local_file" "${REMOTE_SPEC}:${remote_dest}/${name}.tar.gz"
      if [[ $? -eq 0 ]]; then
        echo "  --> Transfer complete, removing local file"
        rm -f "$local_file"
      else
        echo "  --> WARNING: Transfer failed! Keeping local file."
      fi
    else
      # Manual transfer prompt
      echo ""
      echo "Transfer this file to the new server now."
      echo "  e.g.: scp $local_file user@newserver:/path/to/backups/"
      read -r -p "Press ENTER when transfer is complete (or type 'keep' to keep the file): " TRANSFER_REPLY
      if [[ "$TRANSFER_REPLY" != "keep" ]]; then
        echo "  --> Removing $local_file to free disk space"
        rm -f "$local_file"
      fi
    fi
  done

  # Copy volumes.json for reference
  if [[ -n "$REMOTE_SPEC" ]]; then
    remote_dest="${REMOTE_PATH:-~/scv2_backups/$export_name}"
    scp -q "$VOLUMES_JSON" "${REMOTE_SPEC}:${remote_dest}/volumes.json"
  else
    cp "$VOLUMES_JSON" "$output_folder_path/volumes.json" 2>/dev/null
  fi

  echo ""
  echo "Sequential backup complete."

fi

# -------------------------------------------------------------------------
# Prompt to restart service if we shut it down
# -------------------------------------------------------------------------
prompt_restart_services "$PROJECT_NAME"
