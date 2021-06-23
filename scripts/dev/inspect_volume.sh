#!/bin/bash

echo ""
echo "This script will mount a volume and launch bash in said directory, for the purposes of inspecting the volume contents."
echo "Ensure the volume you choose is not already in use by another container."

# -------------------------------------------------------------------------
# Prompt for software being online
echo ""
echo "Volumes available on your system: "
docker volume ls
read -p "Select volume: " volume_select

if docker volume ls | grep -q -E "\s+$volume_select$"; then
  echo "Found volume!"
else
  echo "WARNING: Specified volume '$volume_select' does not exist. Create?"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) echo "  --> Will create new volume '$volume_select'" ;;
    * ) echo "  --> Not creating volume, exiting"; exit ;;
  esac
fi

rm_arg="--rm"
echo ""
echo "Leave container mounted after exiting?"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Will leave container mounted"; rm_arg="" ;;
  * ) echo "  --> Will remove container after exit" ;;
esac

echo "Launching container 'inspect_volume'. Volume will be mounted @ '/$volume_select'"
docker run $rm_arg -it --name inspect_volume -v $volume_select:/$volume_select ubuntu /bin/bash
