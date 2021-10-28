#!/bin/bash

#---------------------------------------
# Arguments and Defaults 

PROJECT_NAME=$1

echo ""
if [[ -z $PROJECT_NAME ]];
then
    DEFAULT_PROJECT=scv2
    CURRENT_PROJECT=$(docker compose ls --all --quiet | head -1)
    PROJECT_NAME=${CURRENT_PROJECT:-$DEFAULT_PROJECT}

    read -r -p "Confirm project name [$PROJECT_NAME]: "
    if [[ ! -z "$REPLY" ]];
    then
        PROJECT_NAME=$REPLY
    fi;
fi
echo "Project name: '$PROJECT_NAME'"

#--------------------
# Docker

if [ ! -f /usr/bin/docker ];
then
    read -p "Do you want to install docker from binaries? (y/[N])"
    if [[ "$REPLY" == "y" ]];
    then
        echo "Installing docker"
        tar xzvf docker.tgz
        sudo cp docker/* /usr/bin
        sudo groupadd docker
        sudo usermod -aG docker $USER

        sudo cp systemd/* /etc/systemd/system

        sudo systemctl enable docker.service
        sudo systemctl enable containerd.service

        read -p "System needs reboot, do you want to reboot now? (y/[N])"
        if [[ "$REPLY" == "y" ]];
        then
            sudo reboot
        fi
    else
        echo "Install docker using package manager"
    fi
    exit
fi

#--------------------
# Docker Compose

DOCKER_COMPOSE=$(docker compose version)
if [[ -z $DOCKER_COMPOSE ]];
then
    echo ""
    echo "Installing docker compose"
    cp -f docker-cli-plugins/docker-compose ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
fi

echo ""
echo "Loading images..."
docker load < scv2.tar.gz

echo ""
echo "Loading images complete."
docker images

echo ""
echo "Updating deployment..."
docker compose -p $PROJECT_NAME up --detach

echo ""
echo "Deployment complete; any errors will be noted above."
echo "To check the status of your deployment, run"
echo "'docker ps -a'"
echo ""