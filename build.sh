#!/bin/bash

# Check the operating system
if [[ "$(uname)" == "Darwin" ]]; then
  # If it's macOS, execute the mac-specific script
  echo "macOS detected. Running build-mac.sh..."
  ./scripts/build-mac.sh
  # Exit this script to prevent it from running further
  exit $?
fi

# This fixes issues on host systems that have Kereberos used as an identity manager. We don't want credentials forwarded to containers.
unset KRB5CCNAME

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
SCV2_PROFILES[tools]="true"
SCV2_PROFILES[rdb]="true"
SCV2_PROFILES[expresso-010]="true"

. "$settingsfile" 2>/dev/null || :

SCV2_PROFILES[base]="true"
SCV2_PROFILES[custom]="true"
SCV2_PROFILES[noaudit]="false"
SCV2_PROFILES[tools]="true"
SCV2_PROFILES[rdb]="true"
SCV2_PROFILES[expresso-010]="true"

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
        # Default_var is a default to be used for the prompt. That is defined by a variable. 
        # Enabling certian profiles can set a default_var. Prompting the user with a dynamic default value.
        default_var=$(runYq '.["x-pf-info"].settings[strenv(setting)].default_var // ""' $compose_file "setting=${setting}")
        description=$(runYq '.["x-pf-info"].settings[strenv(setting)].description // ""' $compose_file "setting=${setting}")
        # Hidden prompts are not shown to the user. They are for completing effects that can change the outcome of the compose script.
        # If a user enables a profile, a hidden prompt can be used for settings a variable
        # Prompts that are hidden, are set to thier provide "default"
        hidden=$(runYq '.["x-pf-info"].settings[strenv(setting)].hidden // false' $compose_file "setting=${setting}")

        # If default_var is set, use its value as the default. Otherwise, continue as normal.
        if [[ -n "$default_var" ]]; then
            default="${!default_var:-$default}"
        fi

        # For hidden settings, just set the default without prompting
        if [[ "$hidden" == "true" ]]; then
            if [[ -n "$default" ]]; then
                # This line here sets the "setting" to the "default" value
                printf -v "${setting}" "%s" "${default}"
            fi
        elif [[ -z $QUIET_MODE ]];
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

# Prompt for any sub-profiles listed in the parent profile's "sub-profiles" array.
# This reads the sub-profiles list once from the parent, then goes directly to those files.
prompt_sub_profiles() {
    local parent_profile=$1
    local parent_file="compose/docker-compose.${parent_profile}.yml"

    # Read sub-profiles list directly from parent (single yq call)
    readarray -t sub_profile_ids < <(runYq '.["x-pf-info"].sub-profiles // [] | .[]' "$parent_file")

    for sub_id in "${sub_profile_ids[@]}"; do
        [[ -z "$sub_id" ]] && continue
        local sub_compose_file="compose/docker-compose.${sub_id}.yml"

        if [[ ! -f "$sub_compose_file" ]]; then
            echo "Warning: sub-profile '$sub_id' not found at '$sub_compose_file'" >&2
            continue
        fi

        local sub_name=$(runYq '.["x-pf-info"].name // ""' $sub_compose_file)
        sub_name="${sub_name:-$sub_id}"

        # Only prompt interactively if not in quiet mode
        if [[ -z $QUIET_MODE ]]; then
            local sub_prompt=$(runYq '.["x-pf-info"].prompt // ""' $sub_compose_file)
            sub_prompt="${sub_prompt:-Enable $sub_name?}"

            echo ""
            if [[ "${SCV2_PROFILES[$sub_id]}" == "true" ]]; then
                local prompt_options="([y]/n/?)"
            else
                local prompt_options="(y/[n]/?)"
            fi

            while read -r -p "$sub_prompt $prompt_options "
            do
                case $REPLY in
                    y|yes)
                        SCV2_PROFILES[$sub_id]=true
                        break
                        ;;
                    n|no)
                        SCV2_PROFILES[$sub_id]=false
                        break
                        ;;
                    ?)
                        local description=$(runYq '.["x-pf-info"].description // ""' $sub_compose_file)
                        description="${description:-No description found}"
                        echo ""
                        echo $description
                        ;;
                    *)
                        break
                        ;;
                esac
            done
        fi

        if [[ "${SCV2_PROFILES[$sub_id]}" == "true" ]]; then
            profile_str="$profile_str --profile $sub_id"
            override_str="$override_str -f $sub_compose_file"
            echo " -> Will enable $sub_name"
            load_pf_compose_settings $sub_compose_file
        else
            echo " -> Will NOT enable $sub_name"
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

    # Skip sub-profiles - they are prompted directly after their parent via the sub-profiles array.
    # Sub-profiles are skipped by adding the field `sub-profile=true` in the x-pf-info
    is_sub_profile=$(runYq '.["x-pf-info"].sub-profile // false' $profile_compose_file)
    if [[ "$is_sub_profile" == "true" ]]; then
        continue
    fi

    name=$(runYq '.["x-pf-info"].name // ""' $profile_compose_file)
    name="${name:-$profile_id}"

    profile_prompt=$(runYq '.["x-pf-info"].prompt // ""' $profile_compose_file)
    profile_prompt="${profile_prompt:-Enable $name?}"    

    if [[ -z $QUIET_MODE && "$profile_id" != "custom" && "$profile_id" != "base" && "$profile_id" != "tools" ]] ;
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

        # Process sub-profiles before loading settings
        # This allows sub-profiles to override default values
        prompt_sub_profiles $profile_id

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
      while true; do
        read -r -p "Continue and write settings to '.env'? (y/n): "
        case "${REPLY,,}" in
          y|yes)
            break
            ;;
          n|no)
            printf >&2 "Aborting."
            exit 2
            ;;
          *)
            echo "Please enter 'y' or 'n'."
            ;;
        esac
      done
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

yn_prompt_strict "Save settings" "SAVE_SETTINGS"

if [[ "$SAVE_SETTINGS" == "true" ]];
then
    echo " -> Saving settings to '$settingsfile'"
    # Only save variables that are defined
    vars_to_save="SCV2_PROFILES PROJECT_NAME"
    [[ -n "${DOCKER_LOGOUT:-}" ]] && vars_to_save="$vars_to_save DOCKER_LOGOUT"
    [[ -n "${DOCKER_PULL:-}" ]] && vars_to_save="$vars_to_save DOCKER_PULL"
    save_state $vars_to_save
fi
