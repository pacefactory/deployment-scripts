#!/bin/bash
set -o pipefail

# =========================================================================
# MIGRATION WORKFLOWS
#
# Same network (zero local disk on old server):
#   Old: ./scripts/backup_restore/backup_volume.sh --mode ssh -r user@newserver
#   New: ./scripts/backup_restore/restore_volume.sh -i ~/scv2_backups/...
#
# Same network (new server pulls, zero disk on new server):
#   Old: ./scripts/backup_restore/backup_volume.sh
#   New: ./scripts/backup_restore/restore_volume.sh --mode ssh -r user@oldserver -p /path/to/backup
#
# Direct transfer (zero disk on BOTH servers, single command):
#   Old: ./scripts/backup_restore/backup_volume.sh --mode direct -r user@newserver
#   (optionally: --remote-name NEWPROJECT if project names differ)
#
# Not on same network:
#   Old: ./scripts/backup_restore/backup_volume.sh --mode sequential
#   (transfer each file via USB/cloud when prompted)
#   New: ./scripts/backup_restore/restore_volume.sh -i /path/where/files/were/placed
# =========================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/backup_utils.sh"

# -------------------------------------------------------------------------
# Signal handling: clean up containers and partial files on Ctrl+C
# -------------------------------------------------------------------------
_BACKUP_CONTAINER_PREFIX="scv2-backup-$$"
_CURRENT_OUTPUT_FILE=""
_CURRENT_REMOTE_FILE=""

cleanup() {
  echo ""
  echo "Interrupted! Cleaning up..."

  # Kill any backup containers we started
  local containers
  containers=$(docker ps --filter "name=${_BACKUP_CONTAINER_PREFIX}" -q 2>/dev/null)
  if [[ -n "$containers" ]]; then
    echo "Stopping backup containers..."
    docker kill $containers &>/dev/null
  fi

  # Remove partial local file
  if [[ -n "$_CURRENT_OUTPUT_FILE" && -f "$_CURRENT_OUTPUT_FILE" ]]; then
    echo "Removing partial file: $_CURRENT_OUTPUT_FILE"
    rm -f "$_CURRENT_OUTPUT_FILE"
  fi

  # Remove partial remote file
  if [[ -n "$_CURRENT_REMOTE_FILE" && -n "$REMOTE_SPEC" ]]; then
    echo "Removing partial remote file: $_CURRENT_REMOTE_FILE"
    ssh $(ssh_mux_opts) "$REMOTE_SPEC" "rm -f $_CURRENT_REMOTE_FILE" 2>/dev/null
  fi

  # Tell user how to restart services if we stopped them
  if [[ -n "$service_shutdown" || -n "$remote_service_shutdown" ]]; then
    echo ""
    echo "NOTE: Services were stopped before backup. To restart:"
    [[ -n "$service_shutdown" ]] && echo "  docker compose -p $PROJECT_NAME start"
    [[ -n "$remote_service_shutdown" ]] && echo "  ssh $REMOTE_SPEC \"docker compose -p '$REMOTE_PROJECT' start\""
  fi

  teardown_ssh_multiplex
  exit 130
}

trap cleanup INT TERM
trap teardown_ssh_multiplex EXIT

# -------------------------------------------------------------------------
# Usage
# -------------------------------------------------------------------------
usage() {
  cat <<'USAGE'
Usage: backup_volume.sh [OPTIONS]

Backup Docker volumes to tar archives (optionally gzip-compressed).

Options:
  -n, --name NAME         Project name (default: auto-detect)
  -o, --output DIR        Local backup output directory (default: ~/scv2_backups)
  -m, --mode MODE         Backup mode: local (default), ssh, sequential, direct
  -r, --remote USER@HOST  Remote destination for ssh/sequential/direct mode
  -p, --remote-path PATH  Remote path for ssh mode (default: ~/scv2_backups/<timestamp>)
      --remote-name NAME  Project name on remote server (for direct mode; default: local name)
      --compress MODE     auto (default) | always | never. auto compresses for
                          local/sequential, skips for ssh/direct (fastest on LAN).
      --no-compress       Shorthand for --compress never.
      --no-images         Skip .jpg files from dbserver (non-interactive)
      --check-only        Run disk space pre-flight check and exit
  -h, --help              Show this help message

Modes:
  local        Back up all volumes to local folder. (Default)
  ssh          Stream each volume directly to remote via SSH. Zero local disk usage.
  sequential   Back up one volume at a time, prompt to transfer, delete before next.
  direct       Stream volumes directly into Docker volumes on remote via SSH.
               Zero disk on both servers. Run from the OLD server.
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
REMOTE_PROJECT=""
BACKUPS_ROOT=""
COMPRESS_MODE="auto"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)        PROJECT_NAME="$2"; shift 2 ;;
    -o|--output)      BACKUPS_ROOT="$2"; shift 2 ;;
    -m|--mode)        MODE="$2"; shift 2 ;;
    -r|--remote)      REMOTE_SPEC="$2"; shift 2 ;;
    -p|--remote-path) REMOTE_PATH="$2"; shift 2 ;;
    --remote-name)    REMOTE_PROJECT="$2"; shift 2 ;;
    --compress)       COMPRESS_MODE="$2"; shift 2 ;;
    --no-compress)    COMPRESS_MODE="never"; shift ;;
    --no-images)      SKIP_IMAGES=true; shift ;;
    --check-only)     CHECK_ONLY=true; shift ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Validate mode
case "$MODE" in
  local|ssh|sequential|direct) ;;
  *) echo "Error: Unknown mode '$MODE'. Use: local, ssh, sequential, direct"; exit 1 ;;
esac

# Validate and resolve compression: auto = compress when writing to disk,
# skip when streaming over the network on a fast LAN.
case "$COMPRESS_MODE" in
  auto)
    case "$MODE" in
      local|sequential) COMPRESS=true ;;
      ssh|direct)       COMPRESS="" ;;
    esac
    ;;
  always) COMPRESS=true ;;
  never)  COMPRESS="" ;;
  *) echo "Error: --compress must be auto, always, or never (got '$COMPRESS_MODE')"; exit 1 ;;
esac

# File extension for produced archives.
if [[ -n "$COMPRESS" ]]; then
  ARCHIVE_EXT="tar.gz"
else
  ARCHIVE_EXT="tar"
fi

if [[ "$MODE" == "ssh" && -z "$REMOTE_SPEC" ]]; then
  echo "Error: --remote is required for ssh mode"
  exit 1
fi

if [[ "$MODE" == "direct" && -z "$REMOTE_SPEC" ]]; then
  echo "Error: --remote is required for direct mode"
  exit 1
fi

# -------------------------------------------------------------------------
# Project name
# -------------------------------------------------------------------------
echo ""
prompt_project_name

# For direct mode, default remote project name to local project name
if [[ "$MODE" == "direct" && -z "$REMOTE_PROJECT" ]]; then
  REMOTE_PROJECT="$PROJECT_NAME"
fi

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
# Ensure software is offline
# -------------------------------------------------------------------------
stop_services "$PROJECT_NAME"

# -------------------------------------------------------------------------
# Resolve dbserver image handling ONCE up-front (was previously prompted
# inside every mode's loop, which made parallelizing/refactoring awkward
# and produced duplicated logic across the four mode branches).
# -------------------------------------------------------------------------
BACKUP_IMAGES=""
dbserver_volume=$(get_volume_name "$PROJECT_NAME" "dbserver")
if volume_exists "$dbserver_volume"; then
  if [[ "$SKIP_IMAGES" == "true" ]]; then
    echo "dbserver images: SKIPPED (--no-images)"
  else
    read -p "Backup images from dbserver? (y/[N]) "
    if [[ "$REPLY" == "y" ]]; then
      BACKUP_IMAGES=true
      echo "  --> Will backup dbserver images"
    else
      echo "  --> Will NOT backup dbserver images"
    fi
  fi
fi

# stream_volume VOLUME_NAME_KEY DOCKER_VOLUME
#   Streams the volume's contents to stdout as a raw (uncompressed) tar.
#   Compression, if requested, happens downstream on the host (pigz/gzip)
#   so we can use multi-threaded compressors without modifying the ubuntu
#   image. Excludes .jpg files when the dbserver-images choice was "no".
stream_volume() {
  local volume_name_key="$1"
  local docker_volume="$2"
  if [[ "$volume_name_key" == "dbserver" && -z "$BACKUP_IMAGES" ]]; then
    docker run --rm --log-driver none --name "${_BACKUP_CONTAINER_PREFIX}" \
      -v "${docker_volume}":/data:ro ubuntu \
      tar --exclude='*.jpg' --exclude='*.JPG' -cf - data
  else
    docker run --rm --log-driver none --name "${_BACKUP_CONTAINER_PREFIX}" \
      -v "${docker_volume}":/data:ro ubuntu \
      tar -cf - data
  fi
}

# -------------------------------------------------------------------------
# Pre-pull the Docker image so it's cached before any piped commands.
# Without this, a pull during 'docker run ... | ssh ...' would stall
# the SSH side (no data flowing) and cause broken pipe errors.
# -------------------------------------------------------------------------
ensure_docker_image "ubuntu"

# -------------------------------------------------------------------------
# For remote modes: open one multiplexed SSH master connection now, so
# subsequent ssh/scp calls (one per volume, plus control calls) all
# reuse a single auth handshake.
# -------------------------------------------------------------------------
if [[ "$MODE" == "ssh" || "$MODE" == "direct" || ( "$MODE" == "sequential" && -n "$REMOTE_SPEC" ) ]]; then
  check_ssh_connectivity "$REMOTE_SPEC" || exit 1
  setup_ssh_multiplex "$REMOTE_SPEC"
fi

# -------------------------------------------------------------------------
# Pick host-side compressor (pigz if available, else gzip).
# Only relevant for paths that compress; harmless otherwise.
# -------------------------------------------------------------------------
HOST_COMPRESSOR="$(host_compressor)"
if [[ -n "$COMPRESS" ]]; then
  echo "Compression: $HOST_COMPRESSOR (mode: $COMPRESS_MODE)"
else
  echo "Compression: disabled (mode: $COMPRESS_MODE) — streaming raw tar"
fi

# =========================================================================
# MODE: local
# =========================================================================
if [[ "$MODE" == "local" ]]; then

  echo ""
  echo "Creating directory $output_folder_path"
  mkdir -p "$output_folder_path"

  backed_up_any=false
  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    volume=$(get_volume_name "$PROJECT_NAME" "$name")

    if ! volume_exists "$volume"; then
      echo "Skipping $name (volume '$volume' does not exist)"
      continue
    fi

    output_file="$output_folder_path/${name}.${ARCHIVE_EXT}"
    echo "Backing up $name --> ${output_file}"
    backed_up_any=true
    _CURRENT_OUTPUT_FILE="$output_file"

    if [[ -n "$COMPRESS" ]]; then
      stream_volume "$name" "$volume" | "$HOST_COMPRESSOR" > "$output_file"
    else
      stream_volume "$name" "$volume" > "$output_file"
    fi

    if [[ $? -ne 0 ]]; then
      echo "ERROR: Backup of $name failed!"
      rm -f "$output_file"
      _CURRENT_OUTPUT_FILE=""
      continue
    fi
    _CURRENT_OUTPUT_FILE=""
  done

  if [[ "$backed_up_any" == "false" ]]; then
    echo ""
    echo "ERROR: No volumes were available to back up."
    exit 1
  fi

  echo ""
  echo "Backup complete: $output_folder_path"

# =========================================================================
# MODE: ssh (stream directly to remote, zero local disk)
# =========================================================================
elif [[ "$MODE" == "ssh" ]]; then

  echo ""
  echo "Creating remote directory ${REMOTE_SPEC}:${REMOTE_PATH}"
  ssh $(ssh_mux_opts) "$REMOTE_SPEC" "mkdir -p $REMOTE_PATH"

  # Copy volumes.json to remote for reference during restore
  scp -q $(ssh_mux_opts) "$VOLUMES_JSON" "${REMOTE_SPEC}:${REMOTE_PATH}/volumes.json"

  backed_up_any=false
  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    volume=$(get_volume_name "$PROJECT_NAME" "$name")

    if ! volume_exists "$volume"; then
      echo "Skipping $name (volume '$volume' does not exist)"
      continue
    fi

    remote_file="${REMOTE_PATH}/${name}.${ARCHIVE_EXT}"
    echo "Streaming $name to ${REMOTE_SPEC}:${remote_file}"
    backed_up_any=true
    _CURRENT_REMOTE_FILE="$remote_file"

    if [[ -n "$COMPRESS" ]]; then
      stream_volume "$name" "$volume" \
        | "$HOST_COMPRESSOR" \
        | ssh $(fast_ssh_opts) "$REMOTE_SPEC" "cat > $remote_file"
    else
      stream_volume "$name" "$volume" \
        | ssh $(fast_ssh_opts) "$REMOTE_SPEC" "cat > $remote_file"
    fi

    if [[ $? -ne 0 ]]; then
      echo "ERROR: Streaming backup of $name failed!"
      echo "  --> Removing partial remote file"
      ssh $(ssh_mux_opts) "$REMOTE_SPEC" "rm -f $remote_file"
      _CURRENT_REMOTE_FILE=""
      continue
    fi

    _CURRENT_REMOTE_FILE=""
    echo "  --> $name streamed successfully"
  done

  if [[ "$backed_up_any" == "false" ]]; then
    echo ""
    echo "ERROR: No volumes were available to back up."
    exit 1
  fi

  echo ""
  echo "SSH backup complete: ${REMOTE_SPEC}:${REMOTE_PATH}"

# =========================================================================
# MODE: sequential (one-at-a-time, prompt to transfer, free disk between)
# =========================================================================
elif [[ "$MODE" == "sequential" ]]; then

  echo ""
  echo "Creating directory $output_folder_path"
  mkdir -p "$output_folder_path"

  backed_up_any=false
  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    volume=$(get_volume_name "$PROJECT_NAME" "$name")
    local_file="$output_folder_path/${name}.${ARCHIVE_EXT}"

    if ! volume_exists "$volume"; then
      echo ""
      echo "Skipping $name (volume '$volume' does not exist)"
      continue
    fi

    echo ""
    echo "=== Backing up: $name ==="
    backed_up_any=true

    # Per-volume disk space check
    vol_size=$(get_volume_size_bytes "$volume")
    if [[ -n "$vol_size" && "$vol_size" -gt 0 ]]; then
      if [[ -n "$COMPRESS" ]]; then
        estimated_size=$((vol_size / 2))
      else
        estimated_size="$vol_size"
      fi
      available=$(get_available_disk_bytes "$output_folder_path")

      if [[ "$estimated_size" -gt "$available" ]]; then
        echo "WARNING: Estimated size (~$(human_readable "$estimated_size")) may exceed"
        echo "         available disk space ($(human_readable "$available"))."
        read -r -p "Proceed anyway? (y/[n]): "
        if [[ "$REPLY" != "y" ]]; then
          echo "  --> Skipping $name"
          continue
        fi
      fi
    fi

    # Perform backup
    _CURRENT_OUTPUT_FILE="$local_file"
    if [[ -n "$COMPRESS" ]]; then
      stream_volume "$name" "$volume" | "$HOST_COMPRESSOR" > "$local_file"
    else
      stream_volume "$name" "$volume" > "$local_file"
    fi

    if [[ $? -ne 0 ]]; then
      echo "ERROR: Backup of $name failed!"
      rm -f "$local_file"
      _CURRENT_OUTPUT_FILE=""
      continue
    fi

    file_size=$(stat -c%s "$local_file" 2>/dev/null || stat -f%z "$local_file" 2>/dev/null)
    echo "  --> Created: $local_file ($(human_readable "${file_size:-0}"))"

    # If remote is specified, transfer automatically via scp
    if [[ -n "$REMOTE_SPEC" ]]; then
      remote_dest="${REMOTE_PATH:-~/scv2_backups/$export_name}"
      ssh $(ssh_mux_opts) "$REMOTE_SPEC" "mkdir -p $remote_dest" 2>/dev/null
      echo "  --> Transferring to ${REMOTE_SPEC}:${remote_dest}/${name}.${ARCHIVE_EXT}"
      scp -q $(fast_ssh_opts) "$local_file" "${REMOTE_SPEC}:${remote_dest}/${name}.${ARCHIVE_EXT}"
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
    _CURRENT_OUTPUT_FILE=""
  done

  # Copy volumes.json for reference
  if [[ -n "$REMOTE_SPEC" ]]; then
    remote_dest="${REMOTE_PATH:-~/scv2_backups/$export_name}"
    scp -q $(ssh_mux_opts) "$VOLUMES_JSON" "${REMOTE_SPEC}:${remote_dest}/volumes.json"
  else
    cp "$VOLUMES_JSON" "$output_folder_path/volumes.json" 2>/dev/null
  fi

  if [[ "$backed_up_any" == "false" ]]; then
    echo ""
    echo "ERROR: No volumes were available to back up."
    exit 1
  fi

  echo ""
  echo "Sequential backup complete."

# =========================================================================
# MODE: direct (stream directly into remote Docker volumes, zero disk both)
# =========================================================================
elif [[ "$MODE" == "direct" ]]; then

  echo ""
  echo "Direct transfer mode: streaming volumes into Docker volumes on $REMOTE_SPEC"
  echo "  Local project:  $PROJECT_NAME"
  echo "  Remote project: $REMOTE_PROJECT"

  # Pre-pull ubuntu on remote so piped docker run won't stall
  ensure_remote_docker_image "$REMOTE_SPEC" "ubuntu" || exit 1

  # Stop remote services (OK if not running)
  stop_remote_services "$REMOTE_SPEC" "$REMOTE_PROJECT"

  backed_up_any=false
  for name in $(jq '.[].name' -r "$VOLUMES_JSON"); do
    local_volume=$(get_volume_name "$PROJECT_NAME" "$name")

    if ! volume_exists "$local_volume"; then
      echo "Skipping $name (local volume '$local_volume' does not exist)"
      continue
    fi

    # Resolve remote volume name (same suffix, potentially different project prefix)
    remote_volume=$(get_volume_name "$REMOTE_PROJECT" "$name")

    echo "Transferring $name: $local_volume --> ${REMOTE_SPEC} $remote_volume"
    backed_up_any=true

    if [[ -n "$COMPRESS" ]]; then
      stream_volume "$name" "$local_volume" \
        | "$HOST_COMPRESSOR" \
        | ssh $(fast_ssh_opts) "$REMOTE_SPEC" "docker run --rm -i -v '${remote_volume}':/data ubuntu tar xzf - -C /"
    else
      stream_volume "$name" "$local_volume" \
        | ssh $(fast_ssh_opts) "$REMOTE_SPEC" "docker run --rm -i -v '${remote_volume}':/data ubuntu tar xf - -C /"
    fi

    if [[ $? -ne 0 ]]; then
      echo "ERROR: Direct transfer of $name failed!"
      continue
    fi

    echo "  --> $name transferred successfully"
  done

  if [[ "$backed_up_any" == "false" ]]; then
    echo ""
    echo "ERROR: No volumes were available to transfer."
    exit 1
  fi

  echo ""
  echo "Direct transfer complete."

fi

# -------------------------------------------------------------------------
# Prompt to restart service if we shut it down
# -------------------------------------------------------------------------
prompt_restart_services "$PROJECT_NAME"

# For direct mode, also prompt to restart remote services
if [[ "$MODE" == "direct" ]]; then
  prompt_restart_remote_services "$REMOTE_SPEC" "$REMOTE_PROJECT"
fi
