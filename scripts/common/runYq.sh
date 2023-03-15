#!/bin/bash

YQ_USE_DOCKER=0
YQ_DOCKER_IMAGE="mikefarah/yq:latest"

runYq() {
  local expression=$1
  local path=$2
  local environmentSettings=$3

  if [[ "${YQ_USE_DOCKER}" -eq "1" ]]; then
    if [ -z "${environmentSettings}" ]; then      
      docker run --interactive --rm ${YQ_DOCKER_IMAGE} "$expression" < "$path" 
    else
      docker run --interactive --rm --env "$environmentSettings" ${YQ_DOCKER_IMAGE} "$expression" < "$path" 
    fi
  else
    if [ -z "${environmentSettings}" ]; then
      yq "$expression" < "$path"
    else
      (eval "export $environmentSettings" && yq "$expression" < "$path")
    fi
  fi
}

if ! [ -x "$(command -v yq)" ]; then
  echo "Using ${YQ_DOCKER_IMAGE} for 'yq' commands, for faster parsing install 'yq' command, possibly via 'snap install yq'"
  if [[ "$(docker images --quiet ${YQ_DOCKER_IMAGE} 2> /dev/null)" == "" ]]; then
    docker pull ${YQ_DOCKER_IMAGE}
  fi
  YQ_USE_DOCKER=1
fi