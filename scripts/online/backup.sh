#!/bin/bash

echo "Script outdated. Do not use."
exit 1

# Requirements

hash pv 2>/dev/null || { printf >&2 "'pv' required, but not found.\nInstall via: sudo apt install pv\nAborting.\n"; exit 1; }
hash xz 2>/dev/null || { printf >&2 "'xz' required, but not found.\n Install via: apt-get install xz-utils\n\Aborting.\n"; exit 1; }
hash numfmt 2>/dev/null || { printf >&2 "'numfmt' required, but not found.\nAborting.\n"; exit 1; }

declare -A SCV2_VOLUMES=()
SCV2_VOLUMES[dbserver]=/home/scv2/volume
SCV2_VOLUMES[realtime]=/home/scv2/locations
SCV2_VOLUMES[service_dtreeserver]=/home/scv2/volume
SCV2_VOLUMES[webgui]=/home/scv2/volume
SCV2_VOLUMES[service_classifier]=/home/scv2/volume

# Settings: Load

settingsfile=".settings"

. "$settingsfile" 2>/dev/null || :

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

DEFAULT_BACKUP_DIR="${HOME}/scv2/backups/${PROJECT_PREFIX}${PROJECT_PREFIX:+/}$(date +'%Y%m%dT%H%M%S%Z')"
BACKUP_DIR="${1:-$DEFAULT_BACKUP_DIR}"

if [[ ! -e $BACKUP_DIR ]];
then
    echo "Creating $BACKUP_DIR directory"
    mkdir -p $BACKUP_DIR
fi

# Backup

echo -n "Backing up mongo, computing size..."
dump_size=$(docker exec "${PROJECT_PREFIX}mongo" mongo --quiet --eval 'total=0;db._adminCommand("listDatabases").databases.forEach(function (d){mdb=db.getSiblingDB(d.name);total+=mdb.stats().dataSize;});print(total);')
echo "done. Size: $(numfmt --to=iec-i $dump_size)"
docker exec "${PROJECT_PREFIX}mongo" mongodump --quiet --archive | pv --delay-start 0.5 -s $dump_size | xz > "$BACKUP_DIR/mongo-mongodump.xz"

for container in "${!SCV2_VOLUMES[@]}"; 
do 
    container_name="${PROJECT_PREFIX}${container}"
    location="${SCV2_VOLUMES[$container]}"
    archive_path=$BACKUP_DIR/$container.xz

    if [[ ! -z $(docker ps --filter=name="${container_name}" --quiet) ]];
    then    
        echo -n "Backing up $container:$location, computing size..."
        tar_size=$(docker exec "${container_name}" du -sb $location | awk '{print $1}')
        echo "done. Size: $(numfmt --to=iec-i $tar_size)"
        docker cp "${container_name}":$location - | pv --delay-start 0.5 -s $tar_size | xz > $archive_path
    else
        echo "Skipping $container:$location, container '$container_name' does not exist"
    fi
done

# Settings: Save

save_state () {
  typeset -p "$@" >"$settingsfile"
}

if [[ -z $QUIET_MODE ]];
then
    read -r -p "Save settings? ([y]/n)" SAVE_SETTINGS    
fi

if [[ "$SAVE_SETTINGS" != "n" ]];
then
    echo " -> Saving settings to '$settingsfile'"
    save_state PROJECT_PREFIX
fi