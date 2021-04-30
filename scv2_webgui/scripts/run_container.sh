#!/bin/bash

# -------------------------------------------------------------------------
# Set image-specific variables

# Set naming
image_name="scv2_webgui_image"
container_name="scv2_webgui"


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
echo "Overwrite default image_name to run?"
echo "Current: '$image_name'"
read -p "(y/[N])" user_response
case "$user_response" in
  y|Y ) read -p "  --> Enter the image_name to use: " image_name ;;
  * ) echo "  --> Will run '$image_name'";;
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


# -------------------------------------------------------------------------
# Automated commands

# Some feedback while stopping the container
echo ""
echo "Stopping existing container..."
docker stop $container_name > /dev/null 2>&1
echo "  --> Success!"

# Some feedback while removing the existing container
echo ""
echo "Removing existing container..."
docker rm $container_name > /dev/null 2>&1
echo "  --> Success!"

# Now run the container
echo ""
echo "Running container ($container_name)"
docker run -d \
           -p 81:80 \
           --name $container_name \
           --restart $container_restart \
           $image_name \
           > /dev/null
echo "  --> Success!"

# Ask about removing unused images
echo ""
read -p "Remove unused images? (y/[n]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Removing images..."; echo ""; docker image prune;;
  * ) echo "  --> Not removing images";;
esac

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
echo "docker exec -it $container_name sh"
echo ""
echo "-----------------------------------------------------------------"
echo ""


