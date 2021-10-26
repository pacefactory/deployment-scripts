#!/bin/bash

echo ""
echo "Loading images..."
docker load < scv2.tar.gz

echo ""
echo "Loading images complete."
docker images

echo ""
echo "Updating deployment..."
docker compose -p deployment-scripts up --detach

echo ""
echo "Deployment complete; any errors will be noted above."
echo "To check the status of your deployment, run"
echo "'docker ps -a'"
echo ""