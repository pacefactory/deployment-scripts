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

# Check if whiptail is available for interactive mode
if [[ -z $QUIET_MODE ]] && ! command -v whiptail &> /dev/null; then
    echo "Warning: whiptail is not installed. Using basic prompts."
    echo "Install it with: brew install newt (macOS) or apt install whiptail (Linux)"
    USE_WHIPTAIL=false
else
    USE_WHIPTAIL=true
fi

# Quick edit mode - launch interactive tag editor
if [[ "$QUICK_EDIT" == "true" ]];
then
  if [ ! -e .env ];
  then
    echo "No .env file found. Please run ./build.sh first."
    exit 1
  fi

  ./scripts/edit-tags.sh
fi

# Check if docker-compose.yml exists
COMPOSE_EXISTS=true
if [ ! -e docker-compose.yml ]; then
  COMPOSE_EXISTS=false
fi

# Set defaults
RECONFIGURE="${RECONFIGURE:-false}"
DOCKER_PULL="${DOCKER_PULL:-true}"
DOCKER_LOGOUT="${DOCKER_LOGOUT:-false}"

# Interactive mode with whiptail - show all options at once
if [[ -z $QUIET_MODE && "$USE_WHIPTAIL" == "true" ]];
then
    # Build checklist items based on current defaults
    # Format: "tag" "description" "ON/OFF"

    checklist_items=()

    if [[ "$COMPOSE_EXISTS" == "true" ]]; then
        if [[ "$RECONFIGURE" == "true" ]]; then
            checklist_items+=("RECONFIGURE" "Reconfigure deployment (run build.sh)" "ON")
        else
            checklist_items+=("RECONFIGURE" "Reconfigure deployment (run build.sh)" "OFF")
        fi
    fi

    if [[ "$DOCKER_PULL" == "true" ]]; then
        checklist_items+=("DOCKER_PULL" "Pull images from DockerHub" "ON")
    else
        checklist_items+=("DOCKER_PULL" "Pull images from DockerHub" "OFF")
    fi

    if [[ "$DOCKER_LOGOUT" == "true" ]]; then
        checklist_items+=("DOCKER_LOGOUT" "Logout from DockerHub after update" "ON")
    else
        checklist_items+=("DOCKER_LOGOUT" "Logout from DockerHub after update" "OFF")
    fi

    # Calculate height
    local_menu_height=${#checklist_items[@]}
    local_menu_height=$((local_menu_height / 3))  # 3 items per entry
    local_total_height=$((local_menu_height + 10))

    # Show checklist
    selected=$(whiptail --title "Update Options" \
        --checklist "Select options for deployment update:\n(Space to toggle, Enter to confirm)" \
        $local_total_height 60 $local_menu_height \
        "${checklist_items[@]}" \
        3>&1 1>&2 2>&3)

    exit_status=$?

    # Check if user cancelled
    if [[ $exit_status -ne 0 ]]; then
        echo "Update cancelled."
        exit 0
    fi

    # Parse selections - reset all to false first
    RECONFIGURE=false
    DOCKER_PULL=false
    DOCKER_LOGOUT=false

    # Set selected options to true
    if [[ "$selected" == *"RECONFIGURE"* ]]; then
        RECONFIGURE=true
    fi
    if [[ "$selected" == *"DOCKER_PULL"* ]]; then
        DOCKER_PULL=true
    fi
    if [[ "$selected" == *"DOCKER_LOGOUT"* ]]; then
        DOCKER_LOGOUT=true
    fi

elif [[ -z $QUIET_MODE ]];
then
    # Fallback to basic prompts if whiptail not available
    if [[ "$COMPOSE_EXISTS" == "false" ]]; then
        RECONFIGURE=true
    else
        yn_prompt "Reconfigure deployment" "RECONFIGURE"
    fi
    yn_prompt "Pull from DockerHub" "DOCKER_PULL"
    yn_prompt "Logout from DockerHub after update" "DOCKER_LOGOUT"
fi

# Force reconfigure if no compose file
if [[ "$COMPOSE_EXISTS" == "false" ]]; then
    RECONFIGURE=true
fi

if [[ "$RECONFIGURE" == "true" ]];
then
  ./build.sh --name $PROJECT_NAME
fi

echo "Updating deployment..."

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

if [[ "$NEEDS_LOGOUT" == "true" && "$DOCKER_LOGOUT" == "true" ]];
then
    docker logout
fi
