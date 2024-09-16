#!/bin/bash

# Check if the configuration file exists
config_file="config.json"
if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file '$config_file' not found."
    exit 1
fi

# Check for Python availability
if command -v python3 &>/dev/null; then
    python_cmd="python3"
elif command -v python &>/dev/null; then
    python_cmd="python"
else
    echo "Error: Neither 'python3' nor 'python' is available on your system. Please install Python to proceed."
    exit 1
fi

# ANSI color codes using tput
if command -v tput &>/dev/null; then
    color_highlight=$(tput setaf 2) # Green text
    color_reset=$(tput sgr0)        # Reset to default colors
else
    color_highlight=""
    color_reset=""
fi

# ASCII title art
TITLE=$'\033[1;33m╭━━━╮╭╮\033[0m///\033[1;33m╭╮╭╮\033[0m//////\033[1;37m╭━━━╮\033[0m///\033[1;37m╭╮//////
\033[1;33m┃╭━╮┣╯╰╮\033[0m//\033[1;33m┃┃┃┃\033[0m//////\033[1;37m┃╭━╮┃\033[0m///\033[1;37m┃┃/////////
\033[1;33m┃╰━━╋╮╭╋━━┫┃┃┃╭━━┳━╮\033[1;37m┃┃\033[0m/\033[1;37m╰╋╮\033[0m/\033[1;37m╭┃╰━┳━━┳━┓/////////
\033[1;33m╰━━╮┃┃┃┃┃━┫┃┃┃┃╭╮┃╭╯\033[1;37m┃┃\033[0m/\033[1;37m╭┫┃\033[0m/\033[1;37m┃┃╭╮┃┃━┫╭╯//////
\033[1;33m┃╰━╯┃┃╰┫┃━┫╰┫╰┫╭╮┃┃\033[0m/\033[1;37m┃╰━╯┃╰━╯┃╰╯┃┃━┫┃/////
\033[1;33m╰━━━╯╰━┻━━┻━┻━┻╯╰┻╯\033[0m/\033[1;37m╰━━━┻━╮╭┻━━┻━━┻╯//
\033[0m////////////////////////\033[1;37m╭━╯┃\033[0m///////
     ///////////////////\033[1;37m╰━━╯\033[0m//
'

# Function to perform cleanup logic
cleanup_logic() {
    clear
    echo -e "${color_highlight}Warning${color_reset}: This will delete specific files or directories. Do you want to continue? (y/n)"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cleaning up files..."

        # Define the directory to clean up
        target_dir="./tools"

        # Check if the target directory exists
        if [[ -d "$target_dir" ]]; then
            # Delete the directory and its contents
            rm -rf "$target_dir"
            echo "Cleanup completed: $target_dir and its contents have been deleted."
        else
            echo "Directory $target_dir does not exist. No files were deleted."
        fi

        # Wait for the user to press any key before returning to the menu
        read -n 1 -s -r -p "Press any key to return to the menu..."
    else
        echo "Cleanup canceled."
        read -n 1 -s -r -p "Press any key to return to the menu..."
    fi
}

# Function to read options from config.json and populate initial_options dynamically
read_options_from_config() {
    local temp_options=()

    if command -v jq &>/dev/null; then
        # Read option names from config.json using jq
        while IFS= read -r name; do
            temp_options+=("$name")
        done < <(jq -r '.options[].name' "$config_file")
    else
        # Use Python to parse JSON and capture output and exit status
        output=$($python_cmd -c "
import json
import sys
try:
    with open('$config_file') as f:
        data = json.load(f)
    for option in data.get('options', []):
        name = option.get('name', '')
        if name:
            print(name)
except Exception as e:
    sys.exit(1)
")
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to parse '$config_file'. Please ensure it is valid JSON."
            exit 1
        fi

        # Read the output into an array, preserving spaces
        while IFS= read -r line; do
            temp_options+=("$line")
        done <<< "$output"
    fi

    # Assign to initial_options array
    initial_options=("${temp_options[@]}")

    # Append additional options like "Clean Up" and "Quit"
    initial_options+=("Clean Up" "Quit")
}

# Function to get description from config.json
get_description() {
    local option_name="$1"

    if command -v jq &>/dev/null; then
        jq -r --arg name "$option_name" '.options[] | select(.name == $name) | .description' "$config_file"
    else
        output=$($python_cmd -c "
import json
import sys
try:
    with open('$config_file') as f:
        data = json.load(f)
    for option in data.get('options', []):
        if option.get('name', '') == '$option_name':
            print(option.get('description', ''))
            break
except Exception as e:
    sys.exit(1)
")
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to parse description for '$option_name' in '$config_file'."
            exit 1
        fi

        echo "$output"
    fi
}

# Function to check if file exists and download if not
download_if_script_missing() {
    local option_name="$1"
    local script_path="tools/${option_name}.sh"
    local url

    if command -v jq &>/dev/null; then
        url=$(jq -r --arg name "$option_name" '.options[] | select(.name == $name) | .gist_URL' "$config_file")
    else
        url=$($python_cmd -c "
import json
import sys
try:
    with open('$config_file') as f:
        data = json.load(f)
    for option in data.get('options', []):
        if option.get('name', '') == '$option_name':
            print(option.get('gist_URL', ''))
            break
except Exception as e:
    sys.exit(1)
")
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to parse gist_URL for '$option_name' in '$config_file'."
            exit 1
        fi
    fi

    # Create the tools directory if it doesn't exist
    mkdir -p "tools" || {
        echo "Error: Unable to create 'tools' directory." >&2
        exit 1
    }

    # Check if the URL is valid
    if [[ -z "$url" ]]; then
        echo "Error: URL for '$option_name' not found in $config_file." >&2
        exit 1
    fi

    # Proceed to download script
    echo "Downloading script for '$option_name'..."
    if ! curl -s -f -L "$url" -o "$script_path"; then
        echo "Error: Failed to download script '$option_name' from $url. Please ensure the URL is valid." >&2
        exit 1
    else
        chmod +x "$script_path" || {
            echo "Error: Unable to make '$script_path' executable." >&2
            exit 1
        }
    fi
}

# Function to display the submenu for a selected option
display_submenu() {
    local option_name="$1"
    local description=$(get_description "$option_name")
    local submenu_options=("Run" "Help" "Simulate" "Back")
    local submenu_selection=0

    while true; do
        clear
        echo -e "$TITLE"
        echo -e "Submenu for ${option_name}:"
        echo

        for i in "${!submenu_options[@]}"; do
            if [[ $i == $submenu_selection ]]; then
                echo -e "${color_highlight}> ${submenu_options[$i]}${color_reset}"
            else
                echo "  ${submenu_options[$i]}"
            fi
        done

        read -s -n 1 key

        case $key in
            $'\x1b')
                read -s -n 2 key
                case $key in
                    '[A') ((submenu_selection--)) ;;
                    '[B') ((submenu_selection++)) ;;
                esac
                ((submenu_selection = (submenu_selection + ${#submenu_options[@]}) % ${#submenu_options[@]}))
                ;;
            '')
                case "${submenu_options[$submenu_selection]}" in
                    "Run")
                        download_if_script_missing "$option_name"
                        "./tools/${option_name}.sh"
                        read -n 1 -s -r -p "Press any key to return to submenu..."
                        ;;
                    "Help")
                        clear
                        echo -e "$TITLE"
                        echo -e "${color_highlight}> $option_name - Help${color_reset}\n"
                        echo "$description"
                        read -n 1 -s -r -p "Press any key to return to submenu..."
                        ;;
                    "Simulate")
                        echo "Simulating $option_name..."
                        # Add simulation logic here
                        read -n 1 -s -r -p "Press any key to return to submenu..."
                        ;;
                    "Back")
                        return
                        ;;
                esac
                ;;
        esac
    done
}

# Function to display options in the main menu
display_menu() {
    local menu_title="$1"
    shift
    local options=("$@")
    local selection=0

    while true; do
        clear
        echo -e "$menu_title"
        echo

        # Display the options with the highlighted selection
        for i in "${!options[@]}"; do
            if [[ $i == $selection ]]; then
                echo -e "${color_highlight}> ${options[$i]}${color_reset}"
            else
                echo "  ${options[$i]}"
            fi
        done

        read -s -n 1 key

        case $key in
            $'\x1b')
                read -s -n 2 key
                case $key in
                    '[A') ((selection--)) ;;  # Move selection up
                    '[B') ((selection++)) ;;  # Move selection down
                esac
                ((selection = (selection + ${#options[@]}) % ${#options[@]}))  # Wrap around
                ;;
            '')
                # Handle the selection when the Enter key is pressed
                case "${options[$selection]}" in
                    "Quit")
                        exit 0
                        ;;
                    "Clean Up")
                        echo "Performing Clean Up..."
                        cleanup_logic  # Perform cleanup
                        ;;
                    *)
                        display_submenu "${options[$selection]}"  # Display submenu for the selected option
                        ;;
                esac
                ;;
        esac
    done
}

# Call function to read options from config.json and populate initial_options
read_options_from_config

# Call the display_menu function with initial options and TITLE variable
display_menu "$TITLE" "${initial_options[@]}"
