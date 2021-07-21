#!/bin/bash

model_path="/home/scv2/models"
dest_path="/home/scv2/volume/data"

echo ""
echo "This script will copy all models (*.pt) within a specified directory to the service_classifier:/home/scv2/volume/data/ directory"
echo "This requires the service_classifier service to be running."
echo "Continue? (existing model data may be lost and/or overwritten)"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Copying models..." ;;
  * ) echo "  --> Not copying; exiting"; exit ;;
esac

echo ""
echo "Override model source path? (default: '$model_path')"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y )
    read -e -p "  --> Enter model source path: " model_path
    # Replace tilde if given
    model_path="${model_path/#~/$HOME}"
    ;;
  * )
    echo "  --> Will copy models from '$model_path'"
    ;;
esac

echo ""
echo "Making dir (if it doesn't already exist)"
docker exec service_classifier mkdir $dest_path

echo "Copying models"
for i in $model_path/*.pt
do
  echo "Copying $i"
  docker cp $i service_classifier:/home/scv2/volume/data/
done

echo "Done! Any errors will be notes above"
