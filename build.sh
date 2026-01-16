#!/bin/bash

# Check the operating system
if [[ "$(uname)" == "Darwin" ]]; then
  echo "macOS detected. Running build-mac.sh..."
  ./scripts/build-mac.sh "$@"
  exit $?
fi

# This fixes issues on host systems that have Kereberos used as an identity manager. We don't want credentials forwarded to containers.
unset KRB5CCNAME

# Requirements
docker compose version 2>/dev/null || { printf >&2 "'docker compose' required, but not found.\nInstall via: https://docs.docker.com/compose/install/\nAborting.\n"; exit 1; }

# Check if whiptail is available
if ! command -v whiptail &> /dev/null; then
    echo "Error: whiptail is not installed."
    echo "Install it with: apt install whiptail (Linux)"
    exit 1
fi

# Check if yq is available
if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed."
    echo "Install it with: snap install yq (Linux)"
    exit 1
fi

declare -A SCV2_PROFILES=()
POSITIONAL=()

settingsfile=".settings"

SCV2_PROFILES[base]="true"
SCV2_PROFILES[proc]="true"
SCV2_PROFILES[social]="true"
SCV2_PROFILES[audit]="true"
SCV2_PROFILES[tools]="true"

. "$settingsfile" 2>/dev/null || :

SCV2_PROFILES[base]="true"
SCV2_PROFILES[custom]="true"
SCV2_PROFILES[noaudit]="false"
SCV2_PROFILES[tools]="true"

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

# Collect all settings from enabled profiles for whiptail editing
declare -A ALL_SETTINGS
declare -A ALL_DEFAULTS
declare -A ALL_DESCRIPTIONS
declare -a SETTINGS_ORDER

load_pf_compose_settings() {
    local compose_file=$1

    # Get all setting keys using yq
    local settings_keys=$(yq '.["x-pf-info"].settings // {} | keys | .[]' "$compose_file" 2>/dev/null)

    for setting in $settings_keys; do
        local default=$(yq ".\"x-pf-info\".settings.\"${setting}\".default // \"\"" "$compose_file" 2>/dev/null)
        local description=$(yq ".\"x-pf-info\".settings.\"${setting}\".description // \"\"" "$compose_file" 2>/dev/null)

        # Use existing value if set, otherwise use default
        local current_value="${!setting:-$default}"

        ALL_SETTINGS["$setting"]="$current_value"
        ALL_DEFAULTS["$setting"]="$default"
        ALL_DESCRIPTIONS["$setting"]="$description"
        SETTINGS_ORDER+=("$setting")
    done
}

override_str=""
profile_str=""

# Build list of available profiles for whiptail checklist
declare -a PROFILE_LIST
declare -A PROFILE_NAMES

for profile_compose_file in compose/docker-compose.*.yml
do
    profile_id="${profile_compose_file#compose/docker-compose.}"
    profile_id=${profile_id%.yml}

    # Skip special profiles
    if [[ "$profile_id" == "noaudit" || "$profile_id" == "custom" || "$profile_id" == "base" || "$profile_id" == "tools" ]];
    then
        continue
    fi

    name=$(yq '.["x-pf-info"].name // ""' "$profile_compose_file" 2>/dev/null)
    name="${name:-$profile_id}"

    PROFILE_LIST+=("$profile_id")
    PROFILE_NAMES["$profile_id"]="$name"
done

# Show profile selection with whiptail checklist
if [[ -z $QUIET_MODE ]];
then
    # Build checklist items
    checklist_items=()
    for profile_id in "${PROFILE_LIST[@]}"; do
        name="${PROFILE_NAMES[$profile_id]}"
        if [[ "${SCV2_PROFILES[$profile_id]}" == "true" ]]; then
            checklist_items+=("$profile_id" "$name" "ON")
        else
            checklist_items+=("$profile_id" "$name" "OFF")
        fi
    done

    # Calculate height
    menu_height=${#PROFILE_LIST[@]}
    [[ $menu_height -gt 15 ]] && menu_height=15
    total_height=$((menu_height + 10))

    # Show checklist
    selected=$(whiptail --title "Profile Selection" \
        --checklist "Select profiles to enable:\n(Space to toggle, Enter to confirm)" \
        $total_height 70 $menu_height \
        "${checklist_items[@]}" \
        3>&1 1>&2 2>&3)

    exit_status=$?

    if [[ $exit_status -ne 0 ]]; then
        echo "Configuration cancelled."
        exit 0
    fi

    # Reset all optional profiles to false
    for profile_id in "${PROFILE_LIST[@]}"; do
        SCV2_PROFILES[$profile_id]=false
    done

    # Enable selected profiles
    # whiptail returns quoted items like: "item1" "item2"
    for profile_id in "${PROFILE_LIST[@]}"; do
        if [[ "$selected" == *"\"$profile_id\""* ]]; then
            SCV2_PROFILES[$profile_id]=true
        fi
    done
fi

# Process enabled profiles
for profile_compose_file in compose/docker-compose.*.yml
do
    profile_id="${profile_compose_file#compose/docker-compose.}"
    profile_id=${profile_id%.yml}

    if [[ "$profile_id" == "noaudit" ]];
    then
        continue
    fi

    name=$(yq '.["x-pf-info"].name // ""' "$profile_compose_file" 2>/dev/null)
    name="${name:-$profile_id}"

    if [[ "${SCV2_PROFILES[$profile_id]}" == "true" ]];
    then
        profile_str="$profile_str --profile $profile_id"
        override_str="$override_str -f $profile_compose_file"
        echo " -> Will enable $name"

        load_pf_compose_settings $profile_compose_file
    elif [[ "$profile_id" != "custom" && "$profile_id" != "base" && "$profile_id" != "tools" ]];
    then
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

# Show settings editor with whiptail if not in quiet mode
if [[ -z $QUIET_MODE && ${#SETTINGS_ORDER[@]} -gt 0 ]];
then
    # Loop to allow editing settings
    while true; do
        # Build menu items for settings (deduplicated)
        menu_items=()
        declare -A seen_settings
        for setting in "${SETTINGS_ORDER[@]}"; do
            if [[ -z "${seen_settings[$setting]}" ]]; then
                seen_settings[$setting]=1
                menu_items+=("$setting" "${ALL_SETTINGS[$setting]}")
            fi
        done
        unset seen_settings

        # Calculate height
        unique_count=$((${#menu_items[@]} / 2))
        menu_height=$unique_count
        [[ $menu_height -gt 15 ]] && menu_height=15
        total_height=$((menu_height + 10))

        # Show menu
        selected=$(whiptail --title "Settings Configuration" \
            --menu "Select a setting to edit (ESC when done):" \
            $total_height 70 $menu_height \
            "${menu_items[@]}" \
            3>&1 1>&2 2>&3)

        exit_status=$?

        # Exit loop if cancelled/ESC
        if [[ $exit_status -ne 0 ]]; then
            break
        fi

        # Edit selected setting
        current_value="${ALL_SETTINGS[$selected]}"
        description="${ALL_DESCRIPTIONS[$selected]}"
        default="${ALL_DEFAULTS[$selected]}"

        prompt_text="Enter value for $selected"
        [[ -n "$description" ]] && prompt_text="$description"
        [[ -n "$default" ]] && prompt_text="$prompt_text\n(Default: $default)"

        new_value=$(whiptail --title "Edit: $selected" \
            --inputbox "$prompt_text" 12 70 "$current_value" \
            3>&1 1>&2 2>&3)

        input_status=$?

        if [[ $input_status -eq 0 ]]; then
            ALL_SETTINGS["$selected"]="$new_value"
            printf -v "$selected" "%s" "$new_value"
        fi
    done
fi

# Write settings to .env.new
declare -A WRITTEN_SETTINGS
for setting in "${SETTINGS_ORDER[@]}"; do
    if [[ -n "${WRITTEN_SETTINGS[$setting]}" ]]; then
        continue
    fi
    WRITTEN_SETTINGS["$setting"]=1

    value="${ALL_SETTINGS[$setting]}"
    if [[ -n "$value" ]]; then
        echo "${setting}=${value}" >> .env.new
    fi
done

if [[ -f ".env.new" ]];
then
  if [[ -f ".env" ]];
  then
    env_diff=$(diff .env .env.new 2>/dev/null || echo "new file")
    if [[ "${env_diff}" != "" ]];
    then
      if whiptail --title "Confirm Settings" \
          --yesno "Settings have changed. Save to .env?" 8 50;
      then
          mv -f .env .env.backup
          mv .env.new .env
          ENV_FILE="--env-file .env"
      else
          rm .env.new
          echo "Settings not saved. Using existing .env"
      fi
    else
      rm .env.new
    fi
  else
    mv .env.new .env
    ENV_FILE="--env-file .env"
  fi
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

if whiptail --title "Save Settings" \
    --yesno "Save profile selections for future runs?" 8 50;
then
    echo " -> Saving settings to '$settingsfile'"
    vars_to_save="SCV2_PROFILES PROJECT_NAME"
    [[ -n "${DOCKER_LOGOUT:-}" ]] && vars_to_save="$vars_to_save DOCKER_LOGOUT"
    [[ -n "${DOCKER_PULL:-}" ]] && vars_to_save="$vars_to_save DOCKER_PULL"
    save_state $vars_to_save
fi
