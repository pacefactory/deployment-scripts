#!/bin/bash

settingsfile=".settings"
. "$settingsfile" 2>/dev/null || :

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -n|--name)
    PROJECT_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    -q|--quiet)
    QUIET_MODE=true
    shift # past argument
    ;;
    -d|--debug)
    DEBUG=true
    shift # past argument
    ;;
    -e|--edit|--quick-edit)
    QUICK_EDIT=true
    shift # past argument
    ;;
    --logout)
    DOCKER_LOGOUT="$2"
    shift # past argument
    shift # past value
    ;;
    --pull)
    DOCKER_PULL="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters

source scripts/common/prompts.sh

if [[ -z $QUIET_MODE ]];
then
echo ""
echo "This will update the Pacefactory SCV2 deployment running on this machine."
echo ""
fi

source scripts/common/projectName.sh

# Quick edit mode - launch interactive tag editor
if [[ "$QUICK_EDIT" == "true" ]];
then
  if [ ! -e .env ];
  then
    echo "No .env file found. Please run ./build.sh first."
    exit 1
  fi

  ./scripts/edit-tags.sh

  # After editing, ask if they want to continue with update
  if [[ -z $QUIET_MODE ]];
  then
    echo ""
    yn_prompt "Continue with deployment update" "CONTINUE_UPDATE"

    if [[ "$CONTINUE_UPDATE" == "false" ]];
    then
      echo "Exiting without updating deployment."
      exit 0
    fi
  fi
fi

# Check if docker-compose.yml exists
RECONFIGURE=false

if [ ! -e docker-compose.yml ]; 
then
  RECONFIGURE=true
else
  yn_prompt "Reconfigure deployment" "RECONFIGURE"
fi

if [[ "$RECONFIGURE" == "true" ]];
then
  ./build.sh --name $PROJECT_NAME
fi

echo "Updating deployment..."

DOCKER_PULL="${DOCKER_PULL:-true}"

yn_prompt "Pull from DockerHub" "DOCKER_PULL"

if [[ "$DOCKER_PULL" == "true" ]];
then
    echo " -> Will pull from DockerHub"
    
    if ! docker login;
    then
        echo >&2 "docker login failed. Aborting."
        exit 1
    fi

    NEEDS_LOGOUT=true

    pull_command="docker compose --project-name $PROJECT_NAME pull"
    echo $pull_command

    if $pull_command;
    then
        PULL_SUCCESS=true
    fi
    echo ""
else
  echo " -> Will NOT pull from DockerHub"
  PULL_SUCCESS=true
fi

if [[ "$PULL_SUCCESS" == "true" ]];
then  
  echo "Changing ownership of applicable volumes to user scv2..."
  echo ""
  source scripts/common/volumesToScv2User.sh

  up_command="docker compose --project-name $PROJECT_NAME up --detach --remove-orphans"

  echo "Updating deployment..."
  echo ""
  echo $up_command

  $up_command

  echo ""
  echo "Deployment complete; any errors will be noted above."
  echo "To check the status of your deployment, run"
  echo "'docker ps -a'"
  echo ""    
fi

DOCKER_LOGOUT="${DOCKER_LOGOUT:-false}"

if [[ "$NEEDS_LOGOUT" == "true" ]];
then
    echo ""
        
    yn_prompt "Logout from DockerHub" "DOCKER_LOGOUT"

    if [[ "$DOCKER_LOGOUT" == "true" ]];
    then
        docker logout
    fi
fi