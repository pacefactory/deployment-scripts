#!/bin/bash

# -------------------------------------------------------------------------

# Argument parsing

OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
PROMPT=true
BACKUP_DBSERVER_IMAGES=false
PROJECT_NAME=""
VERBOSE=false

while getopts "h?nivp:" opt; do
  case "$opt" in
    h|\?)
      echo "Usage: $0 [-n] [-i] [-p <project name>]"
      echo "-n : no prompt, skip all prompts, accept default answers"
      echo "-i : image backup, include images in DB server backup"
      echo "-p PROJECT_NAME"
      exit 0
      ;;
    i)
      BACKUP_DBSERVER_IMAGES=true
      ;;
    n)  
      PROMPT=false
      ;;
    v)
      VERBOSE=true
      ;;
    p)  PROJECT_NAME=$OPTARG
      ;;
  esac
done

## Project name

echo ""
if [[ -z $PROJECT_NAME ]];
then
    DEFAULT_PROJECT=scv2
    CURRENT_PROJECT=$(docker compose ls --all --quiet | head -1)
    PROJECT_NAME=${CURRENT_PROJECT:-$DEFAULT_PROJECT}

    if [[ "$PROMPT" = true ]];
    then
      read -r -p "Confirm project name [$PROJECT_NAME]: "
      if [[ ! -z "$REPLY" ]];
      then
          PROJECT_NAME=$REPLY
      fi
    fi
fi
echo "Project name: '$PROJECT_NAME'"

# -------------------------------------------------------------------------
## Pathing
export_name="volume_backup-$(date +"%Y-%m-%dT%H_%M_%S")"
export_archive_name="$export_name.tar.gz"

backups_path="$HOME/${PROJECT_NAME}_backups"
output_folder_path="$backups_path/$export_name"
output_archive_path="$backups_path/$export_archive_name"

volumes_json="$(dirname $0)/volumes.json"

# -------------------------------------------------------------------------
# Ensure  software being offline

running_service=$(docker compose ls --filter name=$PROJECT_NAME --quiet)
while [[ ! -z $running_service ]]
do
  echo "$PROJECT_NAME is running, stopping service..."
  docker compose -p $PROJECT_NAME stop --timeout 600
  service_shutdown=true
  
  running_service=$(docker compose ls --filter name=$PROJECT_NAME --quiet)
done


# -------------------------------------------------------------------------
# Create backup folder

echo "Creating directory $output_folder_path"
mkdir -p $output_folder_path

# -------------------------------------------------------------------------
# Backup all volumes individually

for name in $(cat $volumes_json | jq '.[].name' -r)
do
  echo "----------------"
  echo "Backing up $name"
  query=".[] | select(.name == \"${name}\")"
  volume=${PROJECT_NAME}$(cat $volumes_json | jq "$query | .volume_suffix" -r)

  if [[ "$name" == "dbserver" ]];
  then
    if [[ "$PROMPT" == true ]];
    then
      read -p "Backup images from dbserver? (y/[N])"
      if [[ "$REPLY" == "y" ]];
      then
        BACKUP_DBSERVER_IMAGES = true
      fi
    fi

    if [[ "$BACKUP_DBSERVER_IMAGES" == true ]];
    then
      echo "  --> Will backup dbserver images!"
      if [[ "$VERBOSE" == true ]];
      then
        docker run --name ${name}_data -v ${volume}:/data ubuntu tar czvf /tmp/${name}.tar.gz data
      else
        docker run --detach --name ${name}_data -v ${volume}:/data ubuntu tar czvf /tmp/${name}.tar.gz data
      fi
    else
      echo "  --> Will NOT backup dbserver images!"
      if [[ "$VERBOSE" == true ]];
      then
        docker run --name ${name}_data -v ${volume}:/data ubuntu /bin/bash -c 'find data -type f ! -name "*.jpg" | tar czvf /tmp/dbserver.tar.gz -T -' 
      else
        docker run --detach --name ${name}_data -v ${volume}:/data ubuntu /bin/bash -c 'find data -type f ! -name "*.jpg" | tar czvf /tmp/dbserver.tar.gz -T -' 
      fi
    fi
  else
    if [[ "$VERBOSE" == true ]];
    then
      docker run --name ${name}_data -v ${volume}:/data ubuntu tar czvf /tmp/${name}.tar.gz data
    else
      docker run --detach --name ${name}_data -v ${volume}:/data ubuntu tar czvf /tmp/${name}.tar.gz data
    fi
  fi
done

for name in $(cat $volumes_json | jq '.[].name' -r)
do
  docker wait ${name}_data
  docker cp ${name}_data:/tmp/${name}.tar.gz $output_folder_path/
  docker rm ${name}_data
done

# -------------------------------------------------------------------------
# Create a single archive
echo ""
echo "Individual volume backups complete!"
echo "Creating overall archive..."

pushd .
cd $output_folder_path
tar -czvf ../$export_archive_name .
popd

echo "Archive created @ '$output_archive_path'"


# -------------------------------------------------------------------------
# Prompt to remove the single volume archives
if [[ "$PROMPT" == true ]];
then
  read -p "Remove the single volume backups? ([Y]/n) " user_response
fi

case "$user_response" in
  n|N ) echo "  --> Will leave single volume backups in place." ;;
  * ) echo "  --> Will remove single volume archives." ; rm -r $output_folder_path ;;
esac

# -------------------------------------------------------------------------
# Prompt to restart service if we shut it down
if [[ ! -z $service_shutdown ]];
then
  if [[ "$PROMPT" == true ]];
  then
    read -r -p "Start $PROJECT_NAME service? ([y]/n/?)"
  fi

  if [[ "$REPLY" != "n" ]];
  then
    docker compose -p $PROJECT_NAME start
  fi
fi