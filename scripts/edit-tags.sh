#!/bin/bash

# Interactive TUI for editing container tags in .env file
# Provides ranger-like navigation for quick tag editing

ENV_FILE=".env"
TEMP_ENV_FILE=".env.temp"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color
REVERSE='\033[7m'

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found. Run ./build.sh first."
    exit 1
fi

# Function to read .env file into associative array
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
    > "$TEMP_ENV_FILE"
    for key in "${ENV_KEYS[@]}"; do
        echo "${key}=${ENV_VARS[$key]}" >> "$TEMP_ENV_FILE"
    done
    mv "$TEMP_ENV_FILE" "$ENV_FILE"
}

# Function to draw the interface
draw_interface() {
    local selected_idx=$1
    local edit_mode=$2
    local total=${#ENV_KEYS[@]}

    clear
    echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}Container Tag Editor${NC}                                    ${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${BOLD}${CYAN}│${NC} ${DIM}Navigate: ↑/↓ or j/k  Edit: Enter  Save: s  Quit: q${NC}   ${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Calculate visible window
    local window_size=15
    local start_idx=0
    local end_idx=$total

    if [[ $total -gt $window_size ]]; then
        start_idx=$((selected_idx - window_size / 2))
        [[ $start_idx -lt 0 ]] && start_idx=0
        end_idx=$((start_idx + window_size))
        [[ $end_idx -gt $total ]] && end_idx=$total && start_idx=$((end_idx - window_size))
        [[ $start_idx -lt 0 ]] && start_idx=0
    fi

    # Display items
    for i in $(seq $start_idx $((end_idx - 1))); do
        local key="${ENV_KEYS[$i]}"
        local value="${ENV_VARS[$key]}"

        if [[ $i -eq $selected_idx ]]; then
            if [[ "$edit_mode" == "true" ]]; then
                echo -e "${REVERSE}${GREEN}►${NC} ${REVERSE}${BOLD}${key}${NC}${REVERSE} = ${value} ${NC} ${YELLOW}[EDITING]${NC}"
            else
                echo -e "${REVERSE}${GREEN}►${NC} ${REVERSE}${BOLD}${key}${NC}${REVERSE} = ${value} ${NC}"
            fi
        else
            echo -e "  ${BOLD}${key}${NC} ${DIM}=${NC} ${value}"
        fi
    done

    # Show scroll indicator if needed
    if [[ $total -gt $window_size ]]; then
        echo ""
        echo -e "${DIM}[Showing $((start_idx + 1))-${end_idx} of ${total}]${NC}"
    fi

    echo ""
    if [[ "$edit_mode" == "true" ]]; then
        echo -e "${YELLOW}Enter new value (or press Esc to cancel):${NC}"
    fi
}

# Function to edit a value
edit_value() {
    local key="${ENV_KEYS[$1]}"
    local current_value="${ENV_VARS[$key]}"

    # Draw interface in edit mode
    draw_interface $1 "true"

    # Read input with current value pre-filled
    read -e -i "$current_value" -p "> " new_value

    # Update if changed
    if [[ -n "$new_value" && "$new_value" != "$current_value" ]]; then
        ENV_VARS["$key"]="$new_value"
        echo -e "${GREEN}✓ Updated ${key} to ${new_value}${NC}"
        sleep 0.5
        return 0
    fi

    return 1
}

# Main interactive loop
main() {
    load_env_file

    local selected_idx=0
    local total=${#ENV_KEYS[@]}
    local modified=false

    # Hide cursor
    tput civis

    # Trap to restore cursor on exit
    trap 'tput cnorm; echo' EXIT

    while true; do
        draw_interface $selected_idx "false"

        # Read single key
        read -rsn1 input

        case "$input" in
            $'\x1b')  # ESC or arrow key
                read -rsn2 -t 0.1 input
                case "$input" in
                    '[A'|'[D')  # Up arrow
                        ((selected_idx--))
                        [[ $selected_idx -lt 0 ]] && selected_idx=$((total - 1))
                        ;;
                    '[B'|'[C')  # Down arrow
                        ((selected_idx++))
                        [[ $selected_idx -ge $total ]] && selected_idx=0
                        ;;
                esac
                ;;
            'k'|'K')  # Up (vim-style)
                ((selected_idx--))
                [[ $selected_idx -lt 0 ]] && selected_idx=$((total - 1))
                ;;
            'j'|'J')  # Down (vim-style)
                ((selected_idx++))
                [[ $selected_idx -ge $total ]] && selected_idx=0
                ;;
            '')  # Enter key
                if edit_value $selected_idx; then
                    modified=true
                fi
                ;;
            's'|'S')  # Save
                if [[ "$modified" == "true" ]]; then
                    save_env_file
                    echo -e "${GREEN}✓ Saved changes to $ENV_FILE${NC}"
                    sleep 1
                    modified=false
                else
                    echo -e "${YELLOW}No changes to save${NC}"
                    sleep 1
                fi
                ;;
            'q'|'Q')  # Quit
                if [[ "$modified" == "true" ]]; then
                    draw_interface $selected_idx "false"
                    echo -e "${YELLOW}You have unsaved changes!${NC}"
                    read -p "Save before quitting? (y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        save_env_file
                        echo -e "${GREEN}✓ Saved changes${NC}"
                    fi
                fi
                break
                ;;
        esac
    done

    # Restore cursor
    tput cnorm
    echo
}

# Run main function
main
