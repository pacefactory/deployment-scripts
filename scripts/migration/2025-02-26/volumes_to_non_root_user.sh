#!/bin/bash

# Source the project name to PROJECT_NAME
source scripts/common/projectName.sh

echo "Migrating volumes to non-root user for project '$PROJECT_NAME'"
echo ""

# List the base volume names here to migrate
BASE_VOLUMES=(
  "dbserver-data"
  "realtime-data"
  "webgui-data"
  "service_dtreeserver-data"
  "social_video_server-data"
  "swift-labeler-data"
)

# For each base volume, append $PROJECT_NAME to the volume name, like `${PROJECT_NAME}_dbserver-data`
for BASE_VOLUME in "${BASE_VOLUMES[@]}"
do
  VOLUME_NAME="${PROJECT_NAME}_${BASE_VOLUME}"
  echo "Migrating volume '$VOLUME_NAME' to non-root user"
  docker run --rm -v $VOLUME_NAME:/data alpine chown -R 1234:1234 /data
  echo ""
done
