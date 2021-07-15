#!/bin/bash

## Pathing
export_name="volume_backup-$(date +"%Y-%m-%dT%H_%M_%S")"
export_archive_name="$export_name.tar.gz"

backups_path="$HOME/scv2_backups"
output_folder_path="$backups_path/$export_name"
output_archive_path="$backups_path/$export_archive_name"

echo ""
echo "This script will create an archive backup of all volumes in use by the docker-compose deployment"
echo "Ensure the docker-compose stack is OFFLINE before proceeding"

if [ "$EUID" -ne 0 ]; then
  echo ""
  echo "***************************************************************"
  echo "WARNING: script is not being run as root. Bad things may happen"
  echo "***************************************************************"
  echo ""
fi

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
# Create backup folder
echo ""
echo "Creating backup folder: '$output_folder_path'"
mkdir $output_folder_path

# -------------------------------------------------------------------------
# Backup all volumes individually
echo ""
echo "Backing up mongo volume"
docker run -v deployment-scripts_mongodata:/data --name mongo_data ubuntu /bin/bash
docker run --rm --volumes-from mongo_data -v $output_folder_path:/backup ubuntu tar czvf backup/mongo.tar.gz data
docker rm mongo_data

# -------------------------------------------------------------------------
# Prompt for image backup
echo ""
echo "Backup images from dbserver?"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Will backup dbserver images!"; dbserver_tar_cmd="tar czvf backup/dbserver.tar.gz data" ;;
  * ) echo "  --> Will NOT backup dbserver images!"; dbserver_tar_cmd="find data -type f ! -name '*.jpg' | tar czvf backup/dbserver.tar.gz -T -" ;;
esac

echo ""
echo "Backing up dbserver volume"
docker run -v deployment-scripts_dbserver-data:/data --name dbserver_data ubuntu /bin/bash
docker run --rm --volumes-from dbserver_data -v $output_folder_path:/backup ubuntu $dbserver_tar_cmd
docker rm dbserver_data

echo ""
echo "Backing up realtime volume"
docker run -v deployment-scripts_realtime-data:/data --name realtime_data ubuntu /bin/bash
docker run --rm --volumes-from realtime_data -v $output_folder_path:/backup ubuntu tar czvf backup/realtime.tar.gz data
docker rm realtime_data

echo ""
echo "Backing up service_dtreeserver volume"
docker run -v deployment-scripts_service_dtreeserver-data:/data --name service_dtreeserver_data ubuntu /bin/bash
docker run --rm --volumes-from service_dtreeserver_data -v $output_folder_path:/backup ubuntu tar czvf backup/service_dtreeserver.tar.gz data
docker rm service_dtreeserver_data

echo ""
echo "Backing up service_classifier volume"
docker run -v deployment-scripts_service_classifier-data:/data --name service_classifier_data ubuntu /bin/bash
docker run --rm --volumes-from service_classifier_data -v $output_folder_path:/backup ubuntu tar czvf backup/service_classifier.tar.gz data
docker rm service_classifier_data

echo ""
echo "Backing up social_video_server volume"
docker run -v deployment-scripts_social_video_server-data:/data --name social_video_server_data ubuntu /bin/bash
docker run --rm --volumes-from social_video_server_data -v $output_folder_path:/backup ubuntu tar czvf backup/social_video_server.tar.gz data
docker rm social_video_server_data

# -------------------------------------------------------------------------
# Create a single archive
echo ""
echo "Individual volume backups complete!"
echo "Creating overall archive..."
cd $output_folder_path
tar -czvf ../$export_archive_name mongo.tar.gz dbserver.tar.gz realtime.tar.gz service_dtreeserver.tar.gz service_classifier.tar.gz social_video_server.tar.gz

echo "Archive created @ '$output_archive_path'"

# -------------------------------------------------------------------------
# Prompt to remove the single volume archives
echo ""
echo "Remove the single volume backups?"
read -p "([Y]/n) " user_response
case "$user_response" in
  n|N ) echo "  --> Will leave single volume backups in place." ;;
  * ) echo "  --> Will remove single volume archives." ; rm -r $output_folder_path ;;
esac
