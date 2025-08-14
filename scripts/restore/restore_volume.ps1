function Get-FileName($initialDirectory)
{   
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") |
    Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "scv2_backup files (*.tar.gz)|*.tar.gz|All files (*.*)|*.*"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

Write-Output "Script outdated. Do not use."
exit

Write-Output ""
Write-Output "This script will restore volumes from an archive backup created by backup_volume.sh"
Write-Output "Ensure the docker-compose stack is OFFLINE before proceeding"

Write-Output "Is the software stack offline? (i.e. you ran 'docker-compose down' and there are no containers running on 'docker ps -a')"
$docker_offline = Read-Host "(y/[n]) "
if ($docker_offline -ne "y") {
  exit
}

Write-Output "You will now be prompted for an archive file path."
$archive_path = Get-FileName
if (-Not (Test-Path $archive_path -PathType Leaf)) {
  Write-Output "Error: provided path is not a file"
  exit
}
Write-Output "Extracting archive..."
mkdir restore_archive
$unarchived_path = Join-Path -Path "." -ChildPath "restore_archive" | Resolve-Path
tar -xzvf $archive_path -C restore_archive

$mongo_path = Join-Path -Path $unarchived_path -ChildPath "mongo.tar.gz"
if (Test-Path $mongo_path -PathType Leaf) {
  docker run --mount type=volume,src=deployment-scripts_mongodata,dst=/data --name mongo_data ubuntu /bin/bash
  docker run --rm --volumes-from mongo_data --mount type=bind,src=$unarchived_path,dst=/backup ubuntu tar xzvf backup/mongo.tar.gz > /dev/null 2>&1
  docker rm mongo_data
}
else {
  Write-Output "Mongo backup not found, skipping"
}

$dbserver_path = Join-Path -Path $unarchived_path -ChildPath "dbserver.tar.gz"
if (Test-Path $dbserver_path -PathType Leaf) {
  docker run --mount type=volume,src=deployment-scripts_dbserver-data,dst=/data --name dbserver_data ubuntu /bin/bash
  docker run --rm --volumes-from dbserver_data --mount type=bind,src=$unarchived_path,dst=/backup ubuntu tar xzvf backup/dbserver.tar.gz > /dev/null 2>&1
  docker rm dbserver_data
}
else {
  Write-Output "Dbserver backup not found, skipping"
}

$realtime_path = Join-Path -Path $unarchived_path -ChildPath "realtime.tar.gz"
if (Test-Path $realtime_path -PathType Leaf) {
  docker run --mount type=volume,src=deployment-scripts_realtime-data,dst=/data --name realtime_data ubuntu /bin/bash
  docker run --rm --volumes-from realtime_data --mount type=bind,src=$unarchived_path,dst=/backup ubuntu tar xzvf backup/realtime.tar.gz > /dev/null 2>&1
  docker rm realtime_data
}
else {
  Write-Output "Realtime backup not found, skipping"
}

$dtree_path = Join-Path -Path $unarchived_path -ChildPath "service_dtreeserver.tar.gz"
if (Test-Path $dtree_path -PathType Leaf) {
  docker run --mount type=volume,src=deployment-scripts_service_dtreeserver-data,dst=/data --name service_dtreeserver_data ubuntu /bin/bash
  docker run --rm --volumes-from service_dtreeserver_data --mount type=bind,src=$unarchived_path,dst=/backup ubuntu tar xzvf backup/service_dtreeserver.tar.gz > /dev/null 2>&1
  docker rm service_dtreeserver_data
}
else {
  Write-Output "Dtree backup not found, skipping"
}

$classifier_path = Join-Path -Path $unarchived_path -ChildPath "service_classifier.tar.gz"
if (Test-Path $classifier_path -PathType Leaf) {
  docker run --mount type=volume,src=deployment-scripts_service_classifier-data,dst=/data --name service_classifier_data ubuntu /bin/bash
  docker run --rm --volumes-from service_classifier_data --mount type=bind,src=$unarchived_path,dst=/backup ubuntu tar xzvf backup/service_classifier.tar.gz > /dev/null 2>&1
  docker rm service_classifier_data
}
else {
  Write-Output "Classifier backup not found, skipping"
}

$video_server_path = Join-Path -Path $unarchived_path -ChildPath "social_video_server.tar.gz"
if (Test-Path $video_server_path -PathType Leaf) {
  docker run --mount type=volume,src=deployment-scripts_social_video_server-data,dst=/data --name social_video_server_data ubuntu /bin/bash
  docker run --rm --volumes-from social_video_server_data --mount type=bind,src=$unarchived_path,dst=/backup ubuntu tar xzvf backup/social_video_server.tar.gz > /dev/null 2>&1
  docker rm social_video_server_data
}
else {
  Write-Output "Video server backup not found, skipping"
}

Write-Output ""
Write-Output "Individual volume restoration complete!"
Write-Output "Cleaning up..."
Remove-Item -Recurse $unarchived_path

Write-Output "Restore complete!"
