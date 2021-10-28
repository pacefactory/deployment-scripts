#!/bin/bash

echo ""
echo "This will update the Pacefactory SCV2 deployment running on this machine."
echo ""
echo "You will be prompted to enable optional services."
echo "For each prompt, you may enter 'y', 'n', or '?'"
echo "corresponding to yes, no, and help, respectively."
echo "If you are unsure of the importance of given service, select the '?' option."
echo ""
echo ""
echo "The final prompt will ask if you are running in ONLINE or OFFLINE mode."
echo ""
echo "ONLINE mode is to be used for client sites where the autodelete feature"
echo "must be enabled to manage storage constraints."
echo "OFFLINE mode is to be used when running videos using the Offline Processing"
echo "tool. This disabled the autodelete feature, so data persists in the dbserver."

# Init profiles string as empty (no optional profiles)
profile_str=""
# Init override string as empty
override_str=""
DEBUG=true

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

# Enable social profile?
echo ""
while read -r -p "Enable the social profile? (y/[n]/?) "
do
    if [[ "$REPLY" == "y" ]];
    then
        profile_str="$profile_str --profile social"
        echo " -> Will enable social profile"
        break;
    elif [[ "$REPLY" == "?" ]];
    then
      echo ""
      echo "The social profile enables the video-based social media web app and video server"
      echo "(social_web_app, social_video_server)"
    # Default option (assumed to be no). Break
    else
        echo " -> Will NOT enable social profile"
        break;
    fi
done

# Enable ml profile?
echo ""
while read -r -p "Enable the machine learning (ml) profile? (y/[n]/?) "
do
    if [[ "$REPLY" == "y" ]];
    then
        profile_str="$profile_str --profile ml"
        echo " -> Will enable machine learning profile"
        break;
    elif [[ "$REPLY" == "?" ]];
    then
      echo ""
      echo "The machine learning profile enables the machine learning service, used"
      echo "to enhance object classifications and detections within the webgui"
      echo "(service_classifier)"
    # Default option (assumed to be no). Break
    else
        echo " -> Will NOT enable machine learning profile"
        break;
    fi
done

# Enable rdb profile?
echo ""
while read -r -p "Enable the relational dbserver profile? (y/[n]/?) "
do
    if [[ "$REPLY" == "y" ]];
    then
        profile_str="$profile_str --profile rdb"
        echo " -> Will enable relational dbserver profile"
        break;
    elif [[ "$REPLY" == "?" ]];
    then
      echo ""
      echo "The relational dbserver profile enables the relational_dbserver service,"
      echo "which allows integrations between the webgui and a client's existing SQL database"
      echo "(relational_dbserver)"
    # Default option (assumed to be no). Break
    else
        echo " -> Will NOT enable relational dbserver profile"
        break;
    fi
done

# Enable proc profile?
echo ""
while read -r -p "Enable the report processing profile? (y/[n]/?) "
do
    if [[ "$REPLY" == "y" ]];
    then
        profile_str="$profile_str --profile proc"
        echo " -> Will enable report processing profile"
        break;
    elif [[ "$REPLY" == "?" ]];
    then
      echo ""
      echo "The report processing profile enables the processing of report data for"
      echo "a deployment as a periodic service. This means a user need not view the"
      echo "webgui to have report data processed and stored in the dbserver's uistore"
      echo "(service_processing)"
    # Default option (assumed to be no). Break
    else
        echo " -> Will NOT enable report processing profile"
        break;
    fi
done

# Prompt for online/offline mode
echo ""
echo "Which mode (ONLINE or OFFLINE) should be used?"
echo "1 - ONLINE"
echo "2 - OFFLINE"

# This needs to be an infinite loop
while true
do
    read -r -p "Select an option (1 or 2): "
    # Online mode: docker-compose.yml and docker-compose.override.yml used by default
    if [[ "$REPLY" == "1" ]];
    then
        echo " -> Will run in ONLINE mode"
        override_str=""
        break;
    elif [[ "$REPLY" == "2" ]];
    then
        echo " -> Will run in OFFLINE mode"
        override_str="-f docker-compose.yml -f docker-compose.override.yml -f docker-compose.dev.yml"
        break;
    # Default option (assumed to be no). Break
    else
        echo "Please select a valid option (1 or 2)";
    fi
done

if [ DEBUG ];
then
  echo ""
  echo "profile_str: $profile_str"
  echo "override_str: $override_str"
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

  NEEDS_LOGOUT=1

  echo "Login complete; pulling..."
  docker compose -p PROJECT_NAME --env-file .env $profile_str pull
fi

echo ""
echo "Updating deployment..."
if [ -f .env ];
then
  up_command="docker compose --project-name $PROJECT_NAME --env-file .env $profile_str $override_str up --detach"
else
  up_command="docker compose --project-name $PROJECT_NAME --env-file .env.example $profile_str $override_str up --detach"
fi
$up_command

if [[ "$NEEDS_LOGOUT" == "1" ]];
then
  echo ""
  read -r -p "Logout from DockerHub? ([y]/n)"
  if [[ "$REPLY" == "n" ]];
  then
    echo " -> Will NOT logout from DockerHub"
  else
    echo " -> Logging out from DockerHub"
    docker logout
  fi
fi

echo ""
echo "Deployment complete; any errors will be noted above."
echo "To check the status of your deployment, run"
echo "'docker ps -a'"
echo ""
