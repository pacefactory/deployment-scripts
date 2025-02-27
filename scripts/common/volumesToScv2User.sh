#!/bin/bash

SCV2_USER_ID=1234

# Source the project name to PROJECT_NAME
if [[ -z $PROJECT_NAME ]];
then
  source scripts/common/projectName.sh
fi

echo "Migrating volumes to user scv2 (${SCV2_USER_ID}:${SCV2_USER_ID}) for project '$PROJECT_NAME'"
echo ""


# List of eligible volumes (i.e. those that should be owned by the scv2 user)
BASE_VOLUMES=(
  "dbserver-data"
  "realtime-data"
  "webgui-data"
  "service_dtreeserver-data"
  "social_video_server-data"
  "swift-labeler-data"
  "relational_dbserver-data"
)

# Pre-create volumes (without starting containers)
echo "Creating docker compose resources (volumes, networks, etc.)..."
docker compose --project-name "$PROJECT_NAME" up --no-start

# For each base volume, append $PROJECT_NAME to the volume name, like `${PROJECT_NAME}_dbserver-data`
for BASE_VOLUME in "${BASE_VOLUMES[@]}"
do
  VOLUME_NAME="${PROJECT_NAME}_${BASE_VOLUME}"

  # Check if the volume exists
  if docker volume inspect "$VOLUME_NAME" > /dev/null 2>&1; then
    echo "Migrating volume '$VOLUME_NAME' to user scv2 if needed"
  
    docker run --rm -v "$VOLUME_NAME":/data alpine sh -c "\
      CURRENT_OWNER=\$(stat -c '%u:%g' /data 2>/dev/null || echo ''); \
      if [ \"\$CURRENT_OWNER\" != \"${SCV2_USER_ID}:${SCV2_USER_ID}\" ]; then \
        echo \"Current owner is \$CURRENT_OWNER. Changing to ${SCV2_USER_ID}:${SCV2_USER_ID}\"; \
        chown -R ${SCV2_USER_ID}:${SCV2_USER_ID} /data; \
      else \
        echo \"Permissions already set to ${SCV2_USER_ID}:${SCV2_USER_ID}. Skipping.\"; \
      fi"
  fi
done

echo "Migration complete."
echo ""