#!/bin/bash

# Requirements
docker compose version 2>/dev/null || { printf >&2 "'docker compose' required, but not found.\nInstall via: https://docs.docker.com/compose/install/\nAborting.\n"; exit 1; }

source scripts/common/runYq.sh

declare -A SCV2_PROFILES=()
POSITIONAL=()

settingsfile=".settings"

SCV2_PROFILES[base]="true"
SCV2_PROFILES[proc]="true"
SCV2_PROFILES[social]="true"
SCV2_PROFILES[audit]="true"

. "$settingsfile" 2>/dev/null || :

SCV2_PROFILES[base]="true"
SCV2_PROFILES[custom]="true"
SCV2_PROFILES[noaudit]="false"

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
    --*)
    profile_id="${key#--}"
    profile_compose_file="compose/docker-compose.${profile_id}.yml"
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

source scripts/common/prompts.sh

if [[ -z $QUIET_MODE ]];
then

echo ""
echo "This will configure the Pacefactory SCV2 deployment settings."
echo ""

fi

ENV_FILE=""

if [ -f .env ];
then
    ENV_FILE="--env-file .env"
    source .env
fi

source scripts/common/projectName.sh

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

for profile_compose_file in compose/docker-compose.*.yml
do
    profile_id="${profile_compose_file#compose/docker-compose.}"
    profile_id=${profile_id%.yml}

    if [[ "$profile_id" == "noaudit" ]];
    then
        continue
    fi    

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

# Enable noaudit profile if audit is disabled
if [[ "${SCV2_PROFILES[audit]}" == "false" ]];
then
    profile_compose_file="compose/docker-compose.noaudit.yml"
    override_str="$override_str -f $profile_compose_file"

    load_pf_compose_settings $profile_compose_file
fi

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

build_command="docker compose --project-name $PROJECT_NAME $ENV_FILE $profile_str $override_str config"
echo "Building docker-compose.yml..."
echo ""
echo $build_command

$build_command > docker-compose.yml

save_state () {
  typeset -p "$@" >"$settingsfile"
}

yn_prompt "Save settings" "SAVE_SETTINGS"

if [[ "$SAVE_SETTINGS" != "n" ]];
then
    echo " -> Saving settings to '$settingsfile'"
    save_state SCV2_PROFILES PROJECT_NAME DOCKER_LOGOUT DOCKER_PULL
fi
