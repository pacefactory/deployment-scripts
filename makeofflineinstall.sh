#!/bin/bash

hash jq 2>/dev/null || { printf >&2 "'jq' required, but not found.\nInstall via:\n  sudo apt install jq\nAborting.\n"; exit 1; }
hash yq 2>/dev/null || { printf >&2 "'yq' required, but not found.\nInstall via:\n  python3 -m pip install yq\nAborting.\n"; exit 1; }
hash docker compose 2>/dev/null || { printf >&2 "'docker compose' required, but not found.\nInstall via: https://docs.docker.com/compose/install/\nAborting.\n"; exit 1; }

DOCKER_VERSION=20.10.9

#---------------------------------------
# Arguments and Defaults 

SAVE_PROFILE_LABEL=$1

if [[ "$SAVE_PROFILE_LABEL" == "all" ]];
then
    SAVE_PROFILES=$(cat docker-compose.yml | yq '.services[].profiles | .[]?' -r | sort | uniq)
else   
    if [[  -z "$SAVE_PROFILE_LABEL" ]];
    then
        SAVE_PROFILE_LABEL="base"
    else
        SAVE_PROFILES=$SAVE_PROFILE_LABEL
        SAVE_PROFILE_LABEL=$(echo $SAVE_PROFILE_LABEL | tr " " "-")
    fi
fi

#---------------------------------------
# Install directory 

INSTALL_PATH=install/$SAVE_PROFILE_LABEL

echo "Creating offline install fileset in $INSTALL_PATH"
mkdir -p $INSTALL_PATH

#---------------------------------------
# Docker
docker_binary_file=$INSTALL_PATH/docker.tgz

if [ ! -f $docker_binary_file ];
then
    echo "Downloading docker $DOCKER_VERISON"
    curl -s https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz > $docker_binary_file
fi

echo "Downloading docker service definitions"
mkdir -p $INSTALL_PATH/systemd
curl -s https://raw.githubusercontent.com/moby/moby/master/contrib/init/systemd/docker.service > $INSTALL_PATH/systemd/docker.service
curl -s https://raw.githubusercontent.com/moby/moby/master/contrib/init/systemd/docker.socket > $INSTALL_PATH/systemd/docker.socket
curl -s https://raw.githubusercontent.com/containerd/containerd/main/containerd.service > $INSTALL_PATH/systemd/containerd.service

# fix paths for containerd
cat $INSTALL_PATH/systemd/containerd.service | sed 's/\/usr\/local\/bin\/containerd/\/usr\/bin\/containerd/' > $INSTALL_PATH/systemd/containerd.service

#---------------------------------------
# Docker Compose
if [ ! -f $INSTALL_PATH/docker-cli-plugins/docker-compose ];
then
    echo "Downloading docker-compose"
    mkdir -p $INSTALL_PATH/docker-cli-plugins/
    curl -sSL https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-linux-x86_64 -o $INSTALL_PATH/docker-cli-plugins/docker-compose
fi

#---------------------------------------
# Software images save
profile_str=""

if [ -z "$SAVE_PROFILES" ];
then
    echo "No profile(s) selected, using base images"
else
    echo "Finding images in profile(s): $SAVE_PROFILES"
    for p in $SAVE_PROFILES
    do
        profile_str="$profile_str --profile $p"
    done
fi

echo ""
read -r -p "Pull from DockerHub? ([y]/n)"
if [[ "$REPLY" == "n" ]];
then
  echo " -> Will NOT pull from DockerHub; using local images only..."
else
  echo " -> Will pull from DockerHub"
  echo "Log in to DockerHub:"
  docker login

  echo "Login complete; pulling..."
  docker compose --env-file .env $profile_str pull
  docker pull ubuntu
fi
echo "Creating $INSTALL_PATH/docker-compose.yml for selected profiles"

docker compose --env-file .env $profile_str config > $INSTALL_PATH/docker-compose.yml

all_images=$(cat $INSTALL_PATH/docker-compose.yml | yq '.services[].image' -r | sort | uniq)

ALL_IMAGES_ARCHIVE=$INSTALL_PATH/scv2.tar.gz

echo "Saving following images to $ALL_IMAGES_ARCHIVE:"
for image in $all_images
do
    echo " $image"
done

all_images="$all_images ubuntu"

docker save $all_images | gzip > $ALL_IMAGES_ARCHIVE

#---------------------------------------
# Install script
cp -f scripts/offline/install.sh $INSTALL_PATH/
mkdir -p $INSTALL_PATH/scripts
cp -f scripts/backup/backup_volume.sh $INSTALL_PATH/scripts/ 
cp -f scripts/backup/volumes.json $INSTALL_PATH/scripts/ 

echo "Offline install fileset complete in $INSTALL_PATH"