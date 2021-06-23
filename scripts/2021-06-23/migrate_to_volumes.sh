#!/bin/bash

echo ""
echo "This script is intended to migrate an existing docker-compose install from bind mounts (host OS directories) to Docker volumes"
echo "It is very important that the software stack is offline before proceeding"
echo "NOTE #1: This script will NOT work unless docker can be used without sudo permissions. Do not proceed otherwise."
echo "NOTE #2: Some container names have changed in this release. Be sure to run 'docker-compose down --remove-orphans' to remove all containers"

# -------------------------------------------------------------------------
# Prompt for software being offline
echo ""
echo "Is the software stack offline? (i.e. you ran 'docker-compose down' and there are no containers running on 'docker ps -a')"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Confirmed containers offline; continuing..." ;;
  * ) echo "  --> Container not offile! Exiting..."; exit ;;
esac

# -------------------------------------------------------------------------
# Disclaimer for container-by-container prompts
echo ""
echo "You will now be prompted, container-by-container, whether you want to migrate the container's data from a bind-mount to a volume."
echo "NOTE: If you migrate a container that has already been migrated, existing volume data may be deleted and/or corrupted."
echo "Take note of this for the 'mongo' container, specifically. If the 'mongo_volume_migrate.sh' script has already been run, DO NOT migrate again."

# -------------------------------------------------------------------------
# Mongo migrate
mongo_migrate="no"
mongo_existing_path="$HOME/scv2/volumes/mongo"
mongo_volume="deployment-scripts_mongodata"
mongo_continue_if_volume_exists="yes"

# Prompt to see if we want to migrate mongo
echo ""
echo "Migrate the mongo container to volume '$mongo_volume'?"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Will migrate mongo"; mongo_migrate="yes" ;;
  * ) echo "  --> Will NOT migrate mongo" ;;
esac

# Only migrate if the user confirmed
if [ "$mongo_migrate" = "yes" ]; then
  # Prompt to override the default path
  echo ""
  echo "Override existing mongo data path? (default: '$mongo_existing_path')"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) read -p "  --> Enter existing mongo data path: " mongo_existing_path ;;
    * ) echo "  --> Will migrate data from '$mongo_existing_path'" ;;
  esac

  # Check that a docker volume of that name already exists
  if docker volume ls | grep -q $mongo_volume; then
    mongo_continue_if_volume_exists="no"
    echo ""
    echo "WARNING: A Docker volume with name $mongo_volume appears to exist"
    echo "Continue anyways? (volume data may be lost and/or overwritten)"
    read -p "(y/[N]) " user_response
    case "$user_response" in
      y|Y ) echo "  --> Will migrate anyways"; mongo_continue_if_volume_exists="yes" ;;
      * ) echo "  --> Will NOT migrate mongo" ;;
    esac
  fi

  if [ "$mongo_continue_if_volume_exists" = "yes" ]; then
    echo ""
    echo "Mongo migration starting:"
    docker volume create $mongo_volume
    docker run -d --rm --name mongo_migrate -v $mongo_volume:/data alpine tail -f /dev/null
    docker cp $mongo_existing_path/. mongo_migrate:/data
    docker stop mongo_migrate
    echo "Mongo migration complete; any errors will be listed above"
  fi
fi

# -------------------------------------------------------------------------
# dbserver migrate
dbserver_migrate="no"
dbserver_existing_path="$HOME/scv2/volumes/dbserver"
dbserver_volume="deployment-scripts_dbserver-data"
dbserver_continue_if_volume_exists="yes"

# Prompt to see if we want to migrate dbserver
echo ""
echo "Migrate the dbserver container to volume '$dbserver_volume'?"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Will migrate dbserver"; dbserver_migrate="yes" ;;
  * ) echo "  --> Will NOT migrate dbserver" ;;
esac

# Only migrate if the user confirmed
if [ "$dbserver_migrate" = "yes" ]; then
  # Prompt to override the default path
  echo ""
  echo "Override existing dbserver data path? (default: '$dbserver_existing_path')"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) read -p "  --> Enter existing dbserver data path: " dbserver_existing_path ;;
    * ) echo "  --> Will migrate data from '$dbserver_existing_path'" ;;
  esac

  # Check that a docker volume of that name already exists
  if docker volume ls | grep -q $dbserver_volume; then
    dbserver_continue_if_volume_exists="no"
    echo ""
    echo "WARNING: A Docker volume with name $dbserver_volume appears to exist"
    echo "Continue anyways? (volume data may be lost and/or overwritten)"
    read -p "(y/[N]) " user_response
    case "$user_response" in
      y|Y ) echo "  --> Will migrate anyways"; dbserver_continue_if_volume_exists="yes" ;;
      * ) echo "  --> Will NOT migrate dbserver" ;;
    esac
  fi

  if [ "$dbserver_continue_if_volume_exists" = "yes" ]; then
    echo ""
    echo "dbserver migration starting:"
    docker volume create $dbserver_volume
    docker run -d --rm --name dbserver_migrate -v $dbserver_volume:/data alpine tail -f /dev/null
    docker cp $dbserver_existing_path/. dbserver_migrate:/data
    docker stop dbserver_migrate
    echo "dbserver migration complete; any errors will be listed above"
    echo ""
  fi
fi

# -------------------------------------------------------------------------
# realtime migrate
realtime_migrate="no"
realtime_existing_path="$HOME/scv2/volumes/realtime"
realtime_volume="deployment-scripts_realtime-data"
realtime_continue_if_volume_exists="yes"

# Prompt to see if we want to migrate realtime
echo ""
echo "Migrate the realtime container to volume '$realtime_volume'?"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Will migrate realtime"; realtime_migrate="yes" ;;
  * ) echo "  --> Will NOT migrate realtime" ;;
esac

# Only migrate if the user confirmed
if [ "$realtime_migrate" = "yes" ]; then
  # Prompt to override the default path
  echo ""
  echo "Override existing realtime data path? (default: '$realtime_existing_path')"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) read -p "  --> Enter existing realtime data path: " realtime_existing_path ;;
    * ) echo "  --> Will migrate data from '$realtime_existing_path'" ;;
  esac

  # Check that a docker volume of that name already exists
  if docker volume ls | grep -q $realtime_volume; then
    realtime_continue_if_volume_exists="no"
    echo ""
    echo "WARNING: A Docker volume with name $realtime_volume appears to exist"
    echo "Continue anyways? (volume data may be lost and/or overwritten)"
    read -p "(y/[N]) " user_response
    case "$user_response" in
      y|Y ) echo "  --> Will migrate anyways"; realtime_continue_if_volume_exists="yes" ;;
      * ) echo "  --> Will NOT migrate realtime" ;;
    esac
  fi

  if [ "$realtime_continue_if_volume_exists" = "yes" ]; then
    echo ""
    echo "realtime migration starting:"
    docker volume create $realtime_volume
    docker run -d --rm --name realtime_migrate -v $realtime_volume:/data alpine tail -f /dev/null
    docker cp $realtime_existing_path/. realtime_migrate:/data
    docker stop realtime_migrate
    echo "realtime migration complete; any errors will be listed above"
    echo ""
  fi
fi


# -------------------------------------------------------------------------
# service_dtreeserver migrate
service_dtreeserver_migrate="no"
service_dtreeserver_existing_path="$HOME/scv2/volumes/services_dtreeserver"
service_dtreeserver_volume="deployment-scripts_service_dtreeserver-data"
service_dtreeserver_continue_if_volume_exists="yes"

# Prompt to see if we want to migrate service_dtreeserver
echo ""
echo "Migrate the service_dtreeserver container to volume '$service_dtreeserver_volume'?"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Will migrate service_dtreeserver"; service_dtreeserver_migrate="yes" ;;
  * ) echo "  --> Will NOT migrate service_dtreeserver" ;;
esac

# Only migrate if the user confirmed
if [ "$service_dtreeserver_migrate" = "yes" ]; then
  # Prompt to override the default path
  echo ""
  echo "Override existing service_dtreeserver data path? (default: '$service_dtreeserver_existing_path')"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) read -p "  --> Enter existing service_dtreeserver data path: " service_dtreeserver_existing_path ;;
    * ) echo "  --> Will migrate data from '$service_dtreeserver_existing_path'" ;;
  esac

  # Check that a docker volume of that name already exists
  if docker volume ls | grep -q $service_dtreeserver_volume; then
    service_dtreeserver_continue_if_volume_exists="no"
    echo ""
    echo "WARNING: A Docker volume with name $service_dtreeserver_volume appears to exist"
    echo "Continue anyways? (volume data may be lost and/or overwritten)"
    read -p "(y/[N]) " user_response
    case "$user_response" in
      y|Y ) echo "  --> Will migrate anyways"; service_dtreeserver_continue_if_volume_exists="yes" ;;
      * ) echo "  --> Will NOT migrate service_dtreeserver" ;;
    esac
  fi

  if [ "$service_dtreeserver_continue_if_volume_exists" = "yes" ]; then
    echo ""
    echo "service_dtreeserver migration starting:"
    docker volume create $service_dtreeserver_volume
    docker run -d --rm --name service_dtreeserver_migrate -v $service_dtreeserver_volume:/data alpine tail -f /dev/null
    docker cp $service_dtreeserver_existing_path/. service_dtreeserver_migrate:/data
    docker stop service_dtreeserver_migrate
    echo "service_dtreeserver migration complete; any errors will be listed above"
    echo ""
  fi
fi


# -------------------------------------------------------------------------
# social_video_server migrate
social_video_server_migrate="no"
social_video_server_existing_path="$HOME/scv2/volumes/social_video_server"
social_video_server_volume="deployment-scripts_social_video_server-data"
social_video_server_continue_if_volume_exists="yes"

# Prompt to see if we want to migrate social_video_server
echo ""
echo "Migrate the social_video_server container to volume '$social_video_server_volume'?"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Will migrate social_video_server"; social_video_server_migrate="yes" ;;
  * ) echo "  --> Will NOT migrate social_video_server" ;;
esac

# Only migrate if the user confirmed
if [ "$social_video_server_migrate" = "yes" ]; then
  # Prompt to override the default path
  echo ""
  echo "Override existing social_video_server data path? (default: '$social_video_server_existing_path')"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) read -p "  --> Enter existing social_video_server data path: " social_video_server_existing_path ;;
    * ) echo "  --> Will migrate data from '$social_video_server_existing_path'" ;;
  esac

  # Check that a docker volume of that name already exists
  if docker volume ls | grep -q $social_video_server_volume; then
    social_video_server_continue_if_volume_exists="no"
    echo ""
    echo "WARNING: A Docker volume with name $social_video_server_volume appears to exist"
    echo "Continue anyways? (volume data may be lost and/or overwritten)"
    read -p "(y/[N]) " user_response
    case "$user_response" in
      y|Y ) echo "  --> Will migrate anyways"; social_video_server_continue_if_volume_exists="yes" ;;
      * ) echo "  --> Will NOT migrate social_video_server" ;;
    esac
  fi

  if [ "$social_video_server_continue_if_volume_exists" = "yes" ]; then
    echo ""
    echo "social_video_server migration starting:"
    docker volume create $social_video_server_volume
    docker run -d --rm --name social_video_server_migrate -v $social_video_server_volume:/data alpine tail -f /dev/null
    docker cp $social_video_server_existing_path/. social_video_server_migrate:/data
    docker stop social_video_server_migrate
    echo "social_video_server migration complete; any errors will be listed above"
    echo ""
  fi
fi

echo ""
echo "All migrations complete!"
