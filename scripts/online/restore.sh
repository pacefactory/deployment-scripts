#!/bin/bash

# Requirements

hash pv 2>/dev/null || { printf >&2 "'pv' required, but not found.\nInstall via: sudo apt install pv\nAborting.\n"; exit 1; }
hash xz 2>/dev/null || { printf >&2 "'xz' required, but not found.\n Install via: apt-get install xz-utils\n\Aborting.\n"; exit 1; }

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

# Restore
echo "Restoring mongo"
archive_path=mongo-mongodump.xz

if [[ -e $1/$archive_path ]];
then
  pv --delay-start 0.5 mongo-mongodump.xz | xz -d | docker exec --interactive "${PROJECT_PREFIX}mongo" mongorestore --quiet --archive
else
    echo "Skipping mongo, $path does not exist"
fi

for container in "${!SCV2_VOLUMES[@]}"; 
do 
  container_name="${PROJECT_PREFIX}${container}"
  location="${SCV2_VOLUMES[$container]}"
  archive_path=$1/$container.xz
  
  if [[ -e $1/$archive_path ]];
  then
    if [[ ! -z $(docker ps --filter=name="${container_name}" --quiet) ]];
    then
      echo "Restoring $container:$location"
      restoredir=$(dirname $location)
      pv --delay-start 0.5 $archive_path | xz -d | docker exec --interactive $container_name tar x -C $restoredir
    else
      echo "Skipping $container:$location, container '$container_name' does not exist"
    fi 
  else
    echo "Skipping $container:$location, $archive_path does not exist"
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
    save_state PROJECT_PREFIX PROJECT_NAME
fi