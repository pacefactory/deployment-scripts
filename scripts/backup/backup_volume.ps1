
## Pathing
$export_name = "volume_backup-$(Get-Date -Format "yyyy-MM-ddTHH_mm_ss")"
$export_archive_name = "$export_name.tar.gz"

$backups_path = "$HOME/scv2_backups"
$output_folder_path = "$backups_path/$export_name"
$output_archive_path = "$backups_path/$export_archive_name"

Write-Host ""
Write-Host "This script will create an archive backup of all volumes in use by the docker-compose deployment"
Write-Host "Ensure the docker-compose stack is OFFLINE before proceeding"

# -------------------------------------------------------------------------
# Prompt for software being offline
Write-Host ""
Write-Host "Is the software stack offline? (i.e. you ran 'docker-compose down' and there are no containers running on 'docker ps -a')"
$docker_offline = Read-Host "(y/[N]) " 
if ($docker_offline -ne "y") {
  Write-Host "  --> Container not offline! Exiting..."
  exit
} else {
  Write-Host "  --> Confirmed containers offline; continuing..."
}

# -------------------------------------------------------------------------
# Create backup folder
Write-Host ""
Write-Host "Creating backup folder: '$output_folder_path'"
New-Item -Path $output_folder_path -ItemType "directory"

# -------------------------------------------------------------------------
# Backup all volumes individually
Write-Host ""
Write-Host "Backing up mongo volume"
docker run -v deployment-scripts_mongodata:/data --name mongo_data ubuntu /bin/bash
docker run --rm --volumes-from mongo_data --mount type=bind,src=$output_folder_path,dst=/backup ubuntu tar czf backup/mongo.tar.gz data
docker rm mongo_data

# -------------------------------------------------------------------------
# Prompt for image backup
Write-Host ""
Write-Host "Backing up dbserver volume"
docker run -v deployment-scripts_dbserver-data:/data --name dbserver_data ubuntu /bin/bash

Write-Host ""
Write-Host "Backup images from dbserver?"
$backup_images = Read-Host "(y/[N]) "
if ($backup_images -ne "y") {
  Write-Host "  --> Will NOT backup dbserver images!"
  docker run --rm --volumes-from dbserver_data --mount type=bind,src=$output_folder_path,dst=/backup ubuntu tar --exclude='*.jpg' -czf backup/dbserver.tar.gz data
} else {
  Write-Host "  --> Will backup dbserver images!"
  docker run --rm --volumes-from dbserver_data --mount type=bind,src=$output_folder_path,dst=/backup ubuntu tar -czf backup/dbserver.tar.gz data
}
docker rm dbserver_data

Write-Host ""
Write-Host "Backing up realtime volume"
docker run -v deployment-scripts_realtime-data:/data --name realtime_data ubuntu /bin/bash
docker run --rm --volumes-from realtime_data --mount type=bind,src=$output_folder_path,dst=/backup ubuntu tar czf backup/realtime.tar.gz data
docker rm realtime_data

Write-Host ""
Write-Host "Backing up service_dtreeserver volume"
docker run -v deployment-scripts_service_dtreeserver-data:/data --name service_dtreeserver_data ubuntu /bin/bash
docker run --rm --volumes-from service_dtreeserver_data --mount type=bind,src=$output_folder_path,dst=/backup ubuntu tar czf backup/service_dtreeserver.tar.gz data
docker rm service_dtreeserver_data

Write-Host ""
Write-Host "Backing up service_classifier volume"
docker run -v deployment-scripts_service_classifier-data:/data --name service_classifier_data ubuntu /bin/bash
docker run --rm --volumes-from service_classifier_data --mount type=bind,src=$output_folder_path,dst=/backup ubuntu tar czf backup/service_classifier.tar.gz data
docker rm service_classifier_data

Write-Host ""
Write-Host "Backing up social_video_server volume"
docker run -v deployment-scripts_social_video_server-data:/data --name social_video_server_data ubuntu /bin/bash
docker run --rm --volumes-from social_video_server_data --mount type=bind,src=$output_folder_path,dst=/backup ubuntu tar czf backup/social_video_server.tar.gz data
docker rm social_video_server_data

# -------------------------------------------------------------------------
# Create a single archive
Write-Host ""
Write-Host "Individual volume backups complete!"
Write-Host "Creating overall archive..."
Push-Location $output_folder_path
tar -czf ../$export_archive_name mongo.tar.gz dbserver.tar.gz realtime.tar.gz service_dtreeserver.tar.gz service_classifier.tar.gz social_video_server.tar.gz

Write-Host "Archive created @ '$output_archive_path'"

# -------------------------------------------------------------------------
# Prompt to remove the single volume archives
Write-Host ""
Write-Host "Remove the single volume backups?"
$remove_singles = Read-Host "([Y]/n) "
if ($remove_singles -eq "n") {
  Write-Host "  --> Will leave single volume backups in place."
} else {
  Write-Host "  --> Will remove single volume archives."
  Remove-Item -Recurse -Force $output_folder_path 
}

Pop-Location
