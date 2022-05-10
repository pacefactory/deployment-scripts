#!/bin/bash

# -------------------------------------------------------------------------
## Project name
PROJECT_NAME=$1

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
## Pathing
export_name="volume_backup-$(date +"%Y-%m-%dT%H_%M_%S")"
export_archive_name="$export_name.tar.gz"

backups_path="$HOME/scv2_backups"
output_folder_path="$backups_path/$export_name"
output_archive_path="$backups_path/$export_archive_name"

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

for name in $(cat volumes.json | jq '.[].name' -r)
do
  echo "Backing up $name"
  query=".[] | select(.name == \"${name}\")"
  volume=${PROJECT_NAME}$(cat volumes.json | jq "$query | .volume_suffix" -r)

  if [[ "$name" == "dbserver" ]];
  then
    read -p "Backup images from dbserver? (y/[N])"
    if [[ "$REPLY" == "y" ]];
    then
      echo "  --> Will backup dbserver images!"
      docker run --name ${name}_data -v ${volume}:/data ubuntu tar czvf /tmp/${name}.tar.gz data
    else
      echo "  --> Will NOT backup dbserver images!"
      docker run --name ${name}_data -v ${volume}:/data ubuntu /bin/bash -c 'find data -type f ! -name "*.jpg" | tar czvf /tmp/dbserver.tar.gz -T -'
    fi
  else
    docker run --name ${name}_data -v ${volume}:/data ubuntu tar czvf /tmp/${name}.tar.gz data
  fi

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
read -p "Remove the single volume backups? ([Y]/n) " user_response
case "$user_response" in
  n|N ) echo "  --> Will leave single volume backups in place." ;;
  * ) echo "  --> Will remove single volume archives." ; rm -r $output_folder_path ;;
esac

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