#!/bin/bash

echo "This script will migrate the old mongo volume to a new docker volume"

echo "The docker-compose should be offline before proceeding."

docker volume create deployment-scripts_mongodata
docker run -d --rm --name dummy -v deployment-scripts_mongodata:/data alpine tail -f /dev/null
docker cp ~/scv2/volumes/mongo/. dummy:/data
docker stop dummy

echo "Finished! Unless noted above, no errors occured. You may now bring the docker-compose back online."
