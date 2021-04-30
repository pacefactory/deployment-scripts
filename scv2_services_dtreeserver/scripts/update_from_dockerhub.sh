#!/bin/bash

# -------------------------------------------------------------------------
# Set image-specific variables

# Set naming
image_name="pacefactory/service-dtreeserver"
container_name="services_dtreeserver"

# Set networking
network_setting="host"

# Set volume pathing
host_volume_path="$HOME/scv2/volumes/$container_name"
container_volume_path="/home/scv2/volume"


# -------------------------------------------------------------------------
# Get environment variables from script args

# Get script arguments for env variables
env_vars=""
if [[ $1 ]]
then
  # Build docker environment argument
  for arg in $@; do
    env_vars+="-e $arg "
  done
  
  # Some feedback about environment settings
  echo ""
  echo "Got environment variables:"
  echo "$env_vars"
fi


# -------------------------------------------------------------------------
# Prompt to force container to always restart

# Assume we always restart containers, but allow disabling
container_restart="always"
echo ""
read -p "Enable container auto-restart? ([y]/n) " user_response
case "$user_response" in
  n|N ) echo "  --> Auto-restart disabled!"; echo ""; container_restart="no";;
  * ) echo "  --> Enabling auto-restart!";;
esac

# -------------------------------------------------------------------------
# Prompt to overwrite image_name
echo ""
echo "Overwrite default image_name to pull from DockerHub?"
echo "Current: '$image_name'"
read -p "(y/[N])" user_response
case "$user_response" in
  y|Y ) read -p "  --> Enter the image_name to use: " image_name ;;
  * ) echo "  --> Will pull '$image_name'";;
esac

# -------------------------------------------------------------------------
# Prompt to overwrite container_name
echo ""
echo "Overwrite default container_name?"
echo "Current: '$container_name'"
read -p "(y/[N])" user_response
case "$user_response" in
  y|Y ) read -p "  --> Enter the container_name to use: " container_name ;;
  * ) echo "  --> Will run image as '$container_name'";;
esac

#-------------------------------------------------------------------------
# Automated commands

# For clarity
echo ""
echo "Updating $container_name"
echo "($image_name)"

# Some feedback about pulling new image
echo ""
echo "Pulling newest image... ($image_name)"
docker pull $image_name > /dev/null
echo "  --> Success!"

# Some feedback while stopping the container
echo ""
echo "Stopping existing container... ($container_name)"
docker stop $container_name > /dev/null 2>&1
echo "  --> Success!"

# Some feedback while removing the existing container
echo ""
echo "Removing existing container... ($container_name)"
docker rm $container_name > /dev/null 2>&1
echo "  --> Success!"

# Now run the container
echo ""
echo "Running container ($container_name)"
docker run -d \
           $env_vars \
           --network=$network_setting \
           -v $host_volume_path:$container_volume_path \
           --name $container_name \
           --restart $container_restart \
           $image_name \
           > /dev/null
echo "  --> Success!"


# Some final feedback
echo ""
echo "-----------------------------------------------------------------"
echo ""
echo "To check the status of all running containers use:"
echo "docker ps -a"
echo ""
echo "To stop this container use:"
echo "docker stop $container_name"
echo ""
echo "To 'enter' into the container (for debugging/inspection) use:"
echo "docker exec -it $container_name bash"
echo ""
echo "-----------------------------------------------------------------"
echo ""

