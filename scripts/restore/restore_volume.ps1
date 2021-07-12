Write-Output ""
Write-Output "This script will restore volumes from an archive backup created by backup_volume.sh"
Write-Output "Ensure the docker-compose stack is OFFLINE before proceeding"

Write-Output "Is the software stack offline? (i.e. you ran 'docker-compose down' and there are no containers running on 'docker ps -a')"
$docker_offline = Read-Host "(y/[n]) "
if ($docker_offline -ne "y") {
  exit
}

$archive_path = Read-Host "Enter the archive file path: "
Write-Output "Extracting archive..."
mkdir restore_archive
tar -xzvf $archive_path -C restore_archive

$mongo_path = Join-Path -Path ".\restore_archive" -ChildPath "mongo.tar.gz"
if (Test-Path $mongo_path -PathType Leaf) {
  docker run -v deployment-scripts_mongodata:/data --name mongo_data ubuntu /bin/bash
  docker run --rm --volumes-from mongo_data -v ./restore_archive:/backup ubuntu tar xzvf backup/mongo.tar.gz
  docker rm mongo_data
}
else {
  Write-Output "Mongo backup not found, skipping"
}

$dbserver_path = Join-Path -Path ".\restore_archive" -ChildPath "dbserver.tar.gz"
if (Test-Path $dbserver_path -PathType Leaf) {
  docker run -v deployment-scripts_dbserver-data:/data --name dbserver_data ubuntu /bin/bash
  docker run --rm --volumes-from dbserver_data -v ./restore_archive:/backup ubuntu tar xzvf backup/dbserver.tar.gz
  docker rm dbserver_data
}
else {
  Write-Output "Dbserver backup not found, skipping"
}

$realtime_path = Join-Path -Path ".\restore_archive" -ChildPath "realtime.tar.gz"
if (Test-Path $realtime_path -PathType Leaf) {
  docker run -v deployment-scripts_realtime-data:/data --name realtime_data ubuntu /bin/bash
  docker run --rm --volumes-from realtime_data -v ./restore_archive:/backup ubuntu tar xzvf backup/realtime.tar.gz
  docker rm realtime_data
}
else {
  Write-Output "Realtime backup not found, skipping"
}

$dtree_path = Join-Path -Path ".\restore_archive" -ChildPath "service_dtreeserver.tar.gz"
if (Test-Path $dtree_path -PathType Leaf) {
  docker run -v deployment-scripts_service_dtreeserver-data:/data --name service_dtreeserver_data ubuntu /bin/bash
  docker run --rm --volumes-from service_dtreeserver_data -v ./restore_archive:/backup ubuntu tar xzvf backup/service_dtreeserver.tar.gz
  docker rm service_dtreeserver_data
}
else {
  Write-Output "Dtree backup not found, skipping"
}

$classifier_path = Join-Path -Path ".\restore_archive" -ChildPath "service_classifier.tar.gz"
if (Test-Path $classifier_path -PathType Leaf) {
  docker run -v deployment-scripts_service_classifier-data:/data --name service_classifier_data ubuntu /bin/bash
  docker run --rm --volumes-from service_classifier_data -v ./restore_archive:/backup ubuntu tar xzvf backup/service_classifier.tar.gz
  docker rm service_classifier_data
}
else {
  Write-Output "Classifier backup not found, skipping"
}

$video_server_path = Join-Path -Path ".\restore_archive" -ChildPath "social_video_server.tar.gz"
if (Test-Path $video_server_path -PathType Leaf) {
  docker run -v deployment-scripts_social_video_server-data:/data --name social_video_server_data ubuntu /bin/bash
  docker run --rm --volumes-from social_video_server_data -v ./restore_archive:/backup ubuntu tar xzvf backup/social_video_server.tar.gz
  docker rm social_video_server_data
}
else {
  Write-Output "Video server backup not found, skipping"
}

Write-Output ""
Write-Output "Individual volume restoration complete!"
Write-Output "Cleaning up..."
rm -r restore_archive

Write-Output "Restore complete!"