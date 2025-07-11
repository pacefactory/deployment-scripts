#!/bin/bash

declare -A SCV2_VOLUMES=()
SCV2_VOLUMES[realtime]=/home/scv2/locations/localhost
SCV2_VOLUMES[auditgui]=/home/scv2/volume
SCV2_VOLUMES[relational_dbserver]=/home/scv2/volume


# Parameter parsing

POSITIONAL=()

while [[ $# -gt 0 ]]
do

key="$1"

case $key in
    -p|--prefix)
    PROJECT_PREFIX="$2"
    shift # past argument
    shift # past value
    ;;
    -q|--quiet)
    QUIET_MODE=true
    shift # past argument
    ;;
    -d|--debug)
    DEBUG=true
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters

# Project prefix

PROJECT_PREFIX=

if [[ -z $QUIET_MODE ]];
then
  read -r -p "Confirm project prefix []: "
  if [[ ! -z "$REPLY" ]];
  then
      PROJECT_PREFIX=$REPLY
  fi;
fi

echo "Project prefix: '$PROJECT_PREFIX'"
echo ""

DEFAULT_BACKUP_DIR="${HOME}/scv2/backups/${PROJECT_PREFIX}${PROJECT_PREFIX:+/}$(date +%Y-%m-%d)"
BACKUP_DIR="${1:-$DEFAULT_BACKUP_DIR}"

if [[ ! -e $BACKUP_DIR ]];
then
    echo "Creating $BACKUP_DIR directory"
    mkdir -p $BACKUP_DIR
fi

# Backup

for container in "${!SCV2_VOLUMES[@]}";
do
    container_name="${PROJECT_PREFIX}${container}"
    location="${SCV2_VOLUMES[$container]}"
    archive_path="$BACKUP_DIR/$container.tar.gz"

    if [[ ! -z $(docker ps --filter=name="${container_name}" --quiet) ]];
    then
        echo "Backing up $container_name:$location"

        if [ "$container" = "realtime" ]; then
            backup_filename="backup-$(date +%Y-%m-%d).tar.gz"
            container_backup_path="/tmp/${backup_filename}"

            echo "  -> Step 1: Creating selective tar archive inside the container..."
            docker exec "${container_name}" sh -c " \
                cd ${location} && \
                find . -mindepth 2 -maxdepth 2 \( -name 'config' -o -name 'resources' \) | \
                tar -czf ${container_backup_path} --exclude='*/resources/backgrounds' --files-from - \
            "

            echo "  -> Step 2: Copying backup file from container to host..."
            docker cp "${container_name}:${container_backup_path}" "${archive_path}"

            echo "  -> Step 3: Removing temporary backup file from the container..."
            docker exec "${container_name}" rm "${container_backup_path}"

        else
            docker exec "${container_name}" tar -C "$location" -cz . > "${archive_path}"
        fi
        
        echo "  -> Backup complete: ${archive_path}"
        echo ""

    else
        echo "Skipping $container:$location, container '$container_name' does not exist"
        echo ""
    fi
done