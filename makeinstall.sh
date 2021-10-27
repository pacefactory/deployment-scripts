#!/bin/bash

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

INSTALL_PATH=install/$SAVE_PROFILE_LABEL

mkdir -p $INSTALL_PATH


rm -f images.tmp

profile_str=""

if [ -z "$SAVE_PROFILES" ];
then
    echo "Finding images in base compose"
    docker compose config --resolve-image-digests > $INSTALL_PATH/docker-compose.yml
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
fi

echo "Creating $INSTALL_PATH/docker-compose.yml image digests resolved for selected profiles"

docker compose --env-file .env $profile_str config > $INSTALL_PATH/docker-compose.yml

all_images=$(cat $INSTALL_PATH/docker-compose.yml | yq '.services[].image' -r | sort | uniq)

ALL_IMAGES_ARCHIVE=$INSTALL_PATH/scv2.tar.gz

echo "Saving following images to $ALL_IMAGES_ARCHIVE:"
for image in $all_images
do
    echo " $image"
done

docker save $all_images | gzip > $ALL_IMAGES_ARCHIVE

cp -f install.sh $INSTALL_PATH/