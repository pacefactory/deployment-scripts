#!/bin/bash

# -------------------------------------------------------------------------
## Input path (backup folder or archive)
BACKUP_INPUT=$1
PROJECT_NAME=$2

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

# -------------------------------------------------------------------------
## Handle archive vs. directory input
if [[ -f "$BACKUP_INPUT" && "$BACKUP_INPUT" == *.tar.gz ]]; then
  echo "Archive file detected, extracting..."
  TEMP_DIR=$(mktemp -d)
  tar -xzf "$BACKUP_INPUT" -C "$TEMP_DIR"

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
  echo "Error: '$BACKUP_INPUT' is not a directory or .tar.gz file."
  exit 1
fi

echo "Backup path: $BACKUP_PATH"

# -------------------------------------------------------------------------
## Project name
echo ""
if [[ -z $PROJECT_NAME ]];
then
    DEFAULT_PROJECT=deployment-scripts
    CURRENT_PROJECT=$(docker compose ls --all --quiet | head -1)
    PROJECT_NAME=${CURRENT_PROJECT:-$DEFAULT_PROJECT}

    read -r -p "Confirm project name [$PROJECT_NAME]: "
    if [[ ! -z "$REPLY" ]];
    then
        PROJECT_NAME=$REPLY
    fi;
fi
echo "Project name: '$PROJECT_NAME'"

# -------------------------------------------------------------------------
## Locate volumes.json
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOLUMES_JSON="$SCRIPT_DIR/../backup/volumes.json"

if [[ ! -f "$VOLUMES_JSON" ]]; then
  echo "Error: volumes.json not found at '$VOLUMES_JSON'"
  exit 1
fi

# -------------------------------------------------------------------------
# Verify backup contents
echo ""
echo "Checking backup contents in: $BACKUP_PATH"
found_any=false
for name in $(cat "$VOLUMES_JSON" | jq '.[].name' -r)
do
  if [[ -f "$BACKUP_PATH/${name}.tar.gz" ]]; then
    echo "  Found: ${name}.tar.gz"
    found_any=true
  else
    echo "  Missing: ${name}.tar.gz (will skip)"
  fi
done

if [[ "$found_any" == "false" ]]; then
  echo ""
  echo "Error: No matching backup files found in '$BACKUP_PATH'."
  echo "Expected files like: dbserver.tar.gz, mongo.tar.gz, etc."
  exit 1
fi

# -------------------------------------------------------------------------
# Ensure software being offline

running_service=$(docker compose ls --filter name=$PROJECT_NAME --quiet)
while [[ ! -z $running_service ]]
do
  echo "$PROJECT_NAME is running, stopping service..."
  docker compose -p $PROJECT_NAME stop --timeout 600
  service_shutdown=true

  running_service=$(docker compose ls --filter name=$PROJECT_NAME --quiet)
done

# -------------------------------------------------------------------------
# Restore all volumes individually

echo ""
for name in $(cat "$VOLUMES_JSON" | jq '.[].name' -r)
do
  if [[ ! -f "$BACKUP_PATH/${name}.tar.gz" ]]; then
    echo "Skipping $name (no backup file found)"
    continue
  fi

  echo "Restoring $name"
  query=".[] | select(.name == \"${name}\")"
  volume=${PROJECT_NAME}$(cat "$VOLUMES_JSON" | jq "$query | .volume_suffix" -r)

  docker run --rm \
    -v ${volume}:/data \
    --mount type=bind,src="$BACKUP_PATH",dst=/backup,readonly \
    ubuntu tar xzf /backup/${name}.tar.gz -C /

  if [[ $? -eq 0 ]]; then
    echo "  --> $name restored successfully"
  else
    echo "  --> ERROR: Failed to restore $name"
  fi
done

# -------------------------------------------------------------------------
# Clean up temp directory if we extracted an archive
if [[ "$CLEANUP_TEMP" == "true" ]]; then
  echo ""
  echo "Cleaning up temporary extraction directory..."
  rm -rf "$TEMP_DIR"
fi

# -------------------------------------------------------------------------
# Prompt to restart service if we shut it down
if [[ ! -z $service_shutdown ]];
then
  read -r -p "Start $PROJECT_NAME service? (y/[n]/?)"
  if [[ "$REPLY" == "y" ]];
  then
    docker compose -p $PROJECT_NAME start
  fi
fi

echo ""
echo "Restore complete!"
