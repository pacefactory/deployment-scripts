#!/bin/bash

# Requirements
hash docker compose 2>/dev/null || { printf >&2 "'docker compose' required, but not found.\nInstall via: https://docs.docker.com/compose/install/\nAborting.\n"; exit 1; }

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

declare -A SCV2_PROFILES=()
POSITIONAL=()

settingsfile=".settings"

. "$settingsfile" 2>/dev/null || :

SCV2_PROFILES[custom]="true"
SCV2_PROFILES[base]="true"

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
    --*)
    profile_id="${key#--}"
    profile_compose_file="docker-compose.${profile_id}.yml"
    if [ -e $profile_compose_file ]; 
    then
        SCV2_PROFILES[$profile_id]=true
    else
        echo >&2 "Invalid profile '${profile_id}': '$profile_compose_file' does not exist."
        exit 1
    fi

    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters


yn_prompt() {
  local prompt_text=$1
  local var_name=$2

  if [[ -z $QUIET_MODE ]];
  then
      if [[ "${!var_name}" == "false" ]];
      then
        local prompt_options="(y/[n])"
        local prompt_nondefault="y"
        local value_nondefault="true"
      else
        local prompt_options="([y]/n)"
        local prompt_nondefault="n"
        local value_nondefault="false"
      fi  

      read -r -p "${prompt_text}? ${prompt_options}" INPUT_VALUE
      if [[ "${INPUT_VALUE}" == "${prompt_nondefault}" ]];
      then
        printf -v "${var_name}" "%s" "${value_nondefault}"
      fi
  fi
}

if [[ -z $QUIET_MODE ]];
then

echo ""
echo "This will update the Pacefactory SCV2 deployment running on this machine."
echo ""

fi

ENV_FILE=""

if [ -f .env ];
then
    ENV_FILE="--env-file .env"
    source .env
fi

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

rm -f .env.new
load_pf_compose_settings() {
    local compose_file=$1

    readarray settings < <(runYq '.["x-pf-info"].settings // {} | keys | .[]' $compose_file)

    for setting in ${settings[@]}
    do
        default=$(runYq '.["x-pf-info"].settings[strenv(setting)].default' $compose_file "setting=${setting}")
        description=$(runYq '.["x-pf-info"].settings[strenv(setting)].description // ""' $compose_file "setting=${setting}")

        if [[ -z $QUIET_MODE ]];
        then 
            read -r -p "${setting} ${description} [${!setting:-$default}]: "
            if [[ ! -z "$REPLY" ]];
            then
                printf -v "${setting}" "%s" "${REPLY}"
            fi
        fi

        if [[ ! -z "${!setting}" ]];
        then    
            echo "${setting}=${!setting}" >> .env.new
        fi
    done
}

override_str=""
profile_str=""

if [[ -z $QUIET_MODE ]];
then 
  echo "You will be prompted to enable optional services."
  echo "For each prompt, you may enter 'y', 'n', or '?'"
  echo "corresponding to yes, no, and help, respectively."
  echo "If you are unsure of the importance of given service, select the '?' option."
fi

for profile_compose_file in docker-compose.*.yml
do
    profile_id="${profile_compose_file#docker-compose.}"
    profile_id=${profile_id%.yml}

    name=$(runYq '.["x-pf-info"].name // ""' $profile_compose_file)
    name="${name:-$profile_id}"

    profile_prompt=$(runYq '.["x-pf-info"].prompt // ""' $profile_compose_file)
    profile_prompt="${profile_prompt:-Enable $name?}"    

    if [[ -z $QUIET_MODE && "$profile_id" != "custom" && "$profile_id" != "base" ]] ;
    then
        echo ""
        if [[ "${SCV2_PROFILES[$profile_id]}" == "true" ]];
        then
          prompt_options="([y]/n/?)"
        else
          prompt_options="(y/[n]/?)"
        fi

        while read -r -p "$profile_prompt $prompt_options "
        do
          case $REPLY in
              y|yes)
                SCV2_PROFILES[$profile_id]=true
                break
                ;;
              n|no)
                SCV2_PROFILES[$profile_id]=false
                break
                ;;
              ?)
                description=$(runYq '.["x-pf-info"].description // ""' $profile_compose_file)
                description="${description:-No description found in '$profile_compose_file' at x-pf-info.description}"
                echo ""
                echo $description
                ;;
              *)
                # keep existing value
                break
                ;;
          esac        
        done
    fi

    if [[ "${SCV2_PROFILES[$profile_id]}" == "true" ]];
    then    
        profile_str="$profile_str --profile $profile_id"
        override_str="$override_str -f $profile_compose_file"
        echo " -> Will enable $name"

        load_pf_compose_settings $profile_compose_file
    else
        echo " -> Will NOT enable $name"
    fi
done

if [[ -f ".env.new" ]];
then
  if [[ -f ".env" ]];
  then
    env_diff=$(diff .env .env.new)
    if [[ "${env_diff}" != "" ]];
    then
      printf >&2 "New settings:\n${env_diff}\n"
      read -r -p "Continue and write settings to '.env'? (y/[n])"
      if [[ "${REPLY}" != "y" ]];
      then
        printf >&2 "Aborting."
        exit 2
      fi
    fi
    
    mv -f .env .env.backup
  fi

  mv .env.new .env
  ENV_FILE="--env-file .env"
fi

if [[ -f .env ]];
then
  printf "\nSettings:\n\n$(cat .env)\n\n"
fi

if [ -n "$DEBUG" ];
then
  echo "profile_str: $profile_str"
  echo "override_str: $override_str"
fi

build_command="docker compose --project-name $PROJECT_NAME $ENV_FILE $profile_str $override_str convert --output docker-compose.yml"
echo "Building docker-compose.yml"
echo $build_command
$build_command

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

save_state () {
  typeset -p "$@" >"$settingsfile"
}

yn_prompt "Save settings" "SAVE_SETTINGS"

if [[ "$SAVE_SETTINGS" != "n" ]];
then
    echo " -> Saving settings to '$settingsfile'"
    save_state SCV2_PROFILES PROJECT_NAME DOCKER_LOGOUT DOCKER_PULL
fi
