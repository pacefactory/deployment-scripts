#!/bin/bash

# Get shared pathing info
this_script_relative_path=$0
this_script_full_path=$(realpath $this_script_relative_path)
backup_scripts_folder_path=$(dirname $this_script_full_path)

backup_location_name="backup_location"
backup_location_path=$backup_scripts_folder_path/$backup_location_name
export_name="metadata_backup-$(date +"%Y-%m-%dT%H_%M_%S%z").tar.gz"

output_folder="$HOME/scv2_backups"

echo ""
echo "This script will create a backup of all metadata in the dbserver through the restore_from_db script in realtime"
echo "Ensure the docker-compose stack is ONLINE before proceeding"

echo "SCRIPT INCOMPLETE, exiting"
exit

# -------------------------------------------------------------------------
# Prompt for software being online
echo ""
echo "Is the docker-compose stack online? (i.e. containers are running upon 'docker ps -a')"
read -p "(y/[N]) " user_response
case "$user_response" in
  y|Y ) echo "  --> Confirmed containers offline; continuing..." ;;
  * ) echo "  --> Container not offline! Exiting..."; exit ;;
esac

# TODO: Prompt user to overwrite the location_info.json host with something different
# host=dbserver will work for a local docker-compose restore, localhost should work for everything else(?)
docker cp $backup_location_path realtime:/home/scv2/locations
# TODO: docker exec -it realtime python3 /home/scv2/realtime/after_database/admin_tools/safe_restore_from_db.py
# But we need to modify the restore scripts to accept arguments for location select (backup_location_name) and camera
# and also an 'all cameras' option.
# ...docker exec goes here
# TODO: docker exec to tar + gzip backup_location_name
docker exec realtime tar -czvf /home/scv2/$export_name /home/scv2/locations/$backup_location_name
# TODO: Copy the restored location archive back out from the realtime container
docker cp realtime:/home/scv2/$export_name $output_folder/$export_name
