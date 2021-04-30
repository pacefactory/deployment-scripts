#!/bin/bash

# -------------------------------------------------------------------------
# Set image-specific variables

# Set image name
image_name="scv2_webgui_image"

# Get shared pathing info
this_script_relative_path=$0
this_script_full_path=$(realpath $this_script_relative_path)
scripts_folder_path=$(dirname $this_script_full_path)
root_project_folder_path=$(dirname $scripts_folder_path)

docker_folder_path="$root_project_folder_path/configs/docker"

# Get important paths
build_name=$(basename $root_project_folder_path)
dockerfile_path="$docker_folder_path/Dockerfile"


# -------------------------------------------------------------------------
# Prompt to run git pull

# Assume no by default, since we don't want to modify files accidentally
echo ""
read -p "Run git pull before build? (y/[n]) " user_response
case "$user_response" in
  y|Y ) pushd $root_project_folder_path > /dev/null; git pull; popd > /dev/null;;
  * ) ;;
esac

# -------------------------------------------------------------------------
# Prompt to overwrite image_name
echo ""
echo "Overwrite default image_name to use?"
echo "Current: '$image_name'"
read -p "(y/[N])" user_response
case "$user_response" in
  y|Y ) read -p "  --> Enter the image_name to use: " image_name ;;
  * ) echo "  --> Will build '$image_name'";;
esac

# -------------------------------------------------------------------------
# Prompt to set any env variables that will override the default in .env
echo ""
read -p "Override env vairables? (y/[N]) " user_response
case "$user_response" in
  y|Y )
    echo "Leave any of the following blank to use defaults set in .env"
    echo "Otherwise, enter the value to override with"
    read -p "DB_PROTOCOL=" user_db_protocol
    read -p "DB_HOST=" user_db_host
    read -p "DB_PORT=" user_db_port
    read -p "GIF_PORT=" user_gif_port
    read -p "CLASSIFIER_PORT=" user_classifier_port
    read -p "GHOST_DEFAULT=" user_ghost_default
    read -p "END_TIME=" user_end_time
    read -p "OFFLINE_DB=" user_offline_db
    read -p "DEBUG=" user_debug
    read -p "SERVICE_WORKER=" user_service_worker
    ;;
  * )
    ;;
esac

# -------------------------------------------------------------------------
# Automated commands

# Some feedback
echo ""
echo "*** $build_name ***"
echo "Building from dockerfile:"
echo "@ $dockerfile_path"
echo ""
echo ""

# Actual build command
docker build \
  --build-arg DB_PROTOCOL=$user_db_protocol \
  --build-arg DB_HOST=$user_db_host \
  --build-arg DB_PORT=$user_db_port \
  --build-arg GIF_PORT=$user_gif_port \
  --build-arg GHOST_DEFAULT=$user_ghost_default \
  --build-arg END_TIME=$user_end_time \
  --build-arg OFFLINE_DB=$user_offline_db \
  --build-arg DEBUG=$user_debug \
  --build-arg SERVICE_WORKER=$user_service_worker \
  --build-arg CLASSIFIER_PORT=$user_classifier_port \
  -t $image_name -f $dockerfile_path $root_project_folder_path

