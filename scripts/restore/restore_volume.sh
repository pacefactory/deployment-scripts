#!/bin/bash

# -------------------------------------------------------------------------
# Get script args
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -f|--file)
    archive_file="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

## Pathing
backups_path="$HOME/scv2_backups"
output_folder_path="$backups_path/$export_name"
output_archive_path="$backups_path/$export_archive_name"

echo ""
echo "This script will restore volumes from an archive backup created by backup_volume.sh"
echo "Ensure the docker-compose stack is OFFLINE before proceeding"

# -------------------------------------------------------------------------
# Prompt for software being offline
echo ""
echo "Is the software stack offline? (i.e. you ran 'docker-compose down' and there are no containers running on 'docker ps -a')"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Confirmed containers offline; continuing..." ;;
  * ) echo "  --> Container not offline! Exiting..."; exit ;;
esac

# -------------------------------------------------------------------------
# Prompt to set archive_file path, if not already supplied
if [ -z ${archive_file+x} ]; then
  echo ""
  read -p "Enter the archive file path: " archive_file
fi

if [ -d restore_archive ]; then
  echo ""
  echo "WARNING: restore_archive directory already exists."
  echo "This means a previous restoration may have failed."
  echo "Exiting..."
  exit 1
fi

# -------------------------------------------------------------------------
# Extract main archive
echo ""
echo "Exracting archive..."
mkdir restore_archive
tar -xzvf $archive_file -C restore_archive

# -------------------------------------------------------------------------
# Restore all volumes individually, if they exist
echo ""
echo "Restoring mongo volume"
if [ -f restore_archive/mongo.tar.gz ]; then
  docker run -v deployment-scripts_mongodata:/data --name mongo_data ubuntu /bin/bash
  docker run --rm --volumes-from mongo_data -v "$(pwd)"/restore_archive:/backup ubuntu tar xzvf backup/mongo.tar.gz
  docker rm mongo_data
else
  echo "Mongo backup not found, skipping"
fi

echo ""
echo "Restoring dbserver volume"
if [ -f restore_archive/dbserver.tar.gz ]; then
  docker run -v deployment-scripts_dbserver-data:/data --name dbserver_data ubuntu /bin/bash
  docker run --rm --volumes-from dbserver_data -v "$(pwd)"/restore_archive:/backup ubuntu tar xzvf ../backup/dbserver.tar.gz
  docker rm dbserver_data
else
  echo "dbserver backup not found, skipping"
fi

echo ""
echo "Restoring realtime volume"
if [ -f restore_archive/realtime.tar.gz ]; then
  docker run -v deployment-scripts_realtime-data:/data --name realtime_data ubuntu /bin/bash
  docker run --rm --volumes-from realtime_data -v "$(pwd)"/restore_archive:/backup ubuntu tar xzvf backup/realtime.tar.gz
  docker rm realtime_data
else
  echo "realtime backup not found, skipping"
fi

echo ""
echo "Restoring service_dtreeserver volume"
if [ -f restore_archive/service_dtreeserver.tar.gz ]; then
  docker run -v deployment-scripts_service_dtreeserver-data:/data --name service_dtreeserver_data ubuntu /bin/bash
  docker run --rm --volumes-from service_dtreeserver_data -v "$(pwd)"/restore_archive:/backup ubuntu tar xzvf backup/service_dtreeserver.tar.gz
  docker rm service_dtreeserver_data
else
  echo "service_dtreeserver backup not found, skipping"
fi

echo ""
echo "Restoring service_classifier volume"
if [ -f restore_archive/service_classifier.tar.gz ]; then
  docker run -v deployment-scripts_service_classifier-data:/data --name service_classifier_data ubuntu /bin/bash
  docker run --rm --volumes-from service_classifier_data -v "$(pwd)"/restore_archive:/backup ubuntu tar xzvf backup/service_classifier.tar.gz
  docker rm service_classifier_data
else
  echo "service_classifier backup not found, skipping"
fi

echo ""
echo "Restoring social_video_server volume"
if [ -f restore_archive/social_video_server.tar.gz ]; then
  docker run -v deployment-scripts_social_video_server-data:/data --name social_video_server_data ubuntu /bin/bash
  docker run --rm --volumes-from social_video_server_data -v "$(pwd)"/restore_archive:/backup ubuntu tar xzvf backup/social_video_server.tar.gz
  docker rm social_video_server_data
else
  echo "social_video_server backup not found, skipping"
fi

# -------------------------------------------------------------------------
# Clean up
echo ""
echo "Individual volume restoration complete!"
echo "Cleaning up..."
rm -r restore_archive

echo "Restore complete!"
