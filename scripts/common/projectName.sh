DEFAULT_PROJECT=deployment-scripts
CURRENT_PROJECT=$(docker compose ls --all --quiet | head -1)
CURRENT_PROJECT=${CURRENT_PROJECT:-$DEFAULT_PROJECT}
PROJECT_NAME=${PROJECT_NAME:-$CURRENT_PROJECT}

if [[ -z $QUIET_MODE ]];
then 
  read -r -p "Confirm project name [${PROJECT_NAME}]: "
  if [[ ! -z "$REPLY" ]];
  then
      PROJECT_NAME=$REPLY
  fi;
fi

echo "Project name: '$PROJECT_NAME'"
echo ""