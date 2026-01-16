#!/bin/bash

# Interactive TUI for editing container tags in .env file
# Uses whiptail for proper terminal UI handling

ENV_FILE=".env"

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found. Run ./build.sh first."
    exit 1
fi

# Check if whiptail is available
if ! command -v whiptail &> /dev/null; then
    echo "Error: whiptail is not installed."
    echo "Install it with: brew install newt (macOS) or apt install whiptail (Linux)"
    exit 1
fi

# Function to read .env file into arrays
declare -A ENV_VARS
declare -a ENV_KEYS

load_env_file() {
    ENV_KEYS=()
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        ENV_VARS["$key"]="$value"
        ENV_KEYS+=("$key")
    done < "$ENV_FILE"
}

# Function to save env file
save_env_file() {
    local temp_file=".env.temp"
    > "$temp_file"
    for key in "${ENV_KEYS[@]}"; do
        echo "${key}=${ENV_VARS[$key]}" >> "$temp_file"
    done
    mv "$temp_file" "$ENV_FILE"
}

# Main loop
main() {
    load_env_file
    local modified=false

    while true; do
        # Build menu items
        local menu_items=()
        for key in "${ENV_KEYS[@]}"; do
            menu_items+=("$key" "${ENV_VARS[$key]}")
        done

        # Calculate height based on number of items
        local menu_height=${#ENV_KEYS[@]}
        [[ $menu_height -gt 15 ]] && menu_height=15
        local total_height=$((menu_height + 8))

        # Show selection menu
        local selected
        selected=$(whiptail --title "Container Tag Editor" \
            --menu "Select a variable to edit (ESC to exit):" \
            $total_height 70 $menu_height \
            "${menu_items[@]}" \
            3>&1 1>&2 2>&3)

        local exit_status=$?

        # Check if user pressed Cancel/ESC
        if [[ $exit_status -ne 0 ]]; then
            if [[ "$modified" == "true" ]]; then
                if whiptail --title "Unsaved Changes" \
                    --yesno "You have unsaved changes. Save before exiting?" 8 50; then
                    save_env_file
                    whiptail --title "Saved" --msgbox "Changes saved to $ENV_FILE" 8 40
                fi
            fi
            break
        fi

        # Get current value and prompt for new value
        local current_value="${ENV_VARS[$selected]}"
        local new_value
        new_value=$(whiptail --title "Edit: $selected" \
            --inputbox "Enter new value:" 10 60 "$current_value" \
            3>&1 1>&2 2>&3)

        local input_status=$?

        # Update if changed and not cancelled
        if [[ $input_status -eq 0 && "$new_value" != "$current_value" ]]; then
            ENV_VARS["$selected"]="$new_value"
            modified=true
        fi
    done
}

# Run main function
main
