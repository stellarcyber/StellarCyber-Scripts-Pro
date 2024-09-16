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
        mapfile -t temp_options < <(jq -r '.options[].name' "$config_file")
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

        # Read the output into an array using mapfile
        mapfile -t temp_options <<< "$output"
    fi

    # Assign to initial_options array
    initial_options=("${temp_options[@]}")

    # Append additional options like "Clean Up" and "Quit"
    initial_options+=("Clean Up" "Quit")
}

# Function to get a property from config.json for a given option
get_option_property() {
    local option_name="$1"
    local property="$2"
    local value

    if command -v jq &>/dev/null; then
        value=$(jq -r --arg name "$option_name" --arg prop "$property" '.options[] | select(.name == $name) | .[$prop]' "$config_file")
    else
        value=$($python_cmd -c "
import json
import sys
try:
    with open('$config_file') as f:
        data = json.load(f)
    for option in data.get('options', []):
        if option.get('name', '') == '$option_name':
            print(option.get('$property', ''))
            break
except Exception as e:
    sys.exit(1)
")
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to parse '$property' for '$option_name' in '$config_file'."
            exit 1
        fi
    fi

    echo "$value"
}

# Function to get description from config.json
get_description() {
    get_option_property "$1" "description"
}

# Function to download the script and handle script types
download_if_script_missing() {
    local option_name="$1"
    local url
    local script_type
    local script_extension
    local script_path

    # Get the gist_URL and script_type from config.json
    url=$(get_option_property "$option_name" "gist_URL")
    script_type=$(get_option_property "$option_name" "script_type")

    # Determine the file extension based on script_type
    case "$script_type" in
        sh) script_extension="sh" ;;
        py) script_extension="py" ;;
        *)
            echo "Error: Unsupported script type '$script_type' for '$option_name'."
            exit 1
            ;;
    esac

    # Replace spaces in the option name with underscores for the filename
    sanitized_option_name="${option_name// /_}"
    script_path="tools/${sanitized_option_name}.${script_extension}"

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

# Function to execute the script with the appropriate interpreter
execute_script() {
    local option_name="$1"
    local script_type
    local script_extension
    local script_path
    local interpreter

    script_type=$(get_option_property "$option_name" "script_type")

    case "$script_type" in
        sh)
            script_extension="sh"
            interpreter="bash"
            ;;
        py)
            script_extension="py"
            interpreter="$python_cmd"
            ;;
        *)
            echo "Error: Unsupported script type '$script_type' for '$option_name'."
            exit 1
            ;;
    esac

    # Replace spaces in the option name with underscores for the filename
    sanitized_option_name="${option_name// /_}"
    script_path="tools/${sanitized_option_name}.${script_extension}"

    # Execute the script using the appropriate interpreter
    echo "Running '$option_name'..."
    "$interpreter" "$script_path"
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
                        execute_script "$option_name"
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
