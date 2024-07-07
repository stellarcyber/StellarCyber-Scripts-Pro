#!/bin/bash

# ASCII title art
TITLE=$'\033[1;33m╭━━━╮╭╮\033[0m╱╱╱\033[1;33m╭╮╭╮\033[0m╱╱╱╱╱╱\033[1;37m╭━━━╮\033[0m╱╱╱\033[1;37m╭╮//////
\033[1;33m┃╭━╮┣╯╰╮\033[0m╱╱\033[1;33m┃┃┃┃\033[0m╱╱╱╱╱╱\033[1;37m┃╭━╮┃\033[0m╱╱╱\033[1;37m┃┃/////////
\033[1;33m┃╰━━╋╮╭╋━━┫┃┃┃╭━━┳━╮\033[1;37m┃┃\033[0m╱\033[1;37m╰╋╮\033[0m╱\033[1;37m╭┃╰━┳━━┳━┓/////////
\033[1;33m╰━━╮┃┃┃┃┃━┫┃┃┃┃╭╮┃╭╯\033[1;37m┃┃\033[0m╱\033[1;37m╭┫┃\033[0m╱\033[1;37m┃┃╭╮┃┃━┫╭╯//////
\033[1;33m┃╰━╯┃┃╰┫┃━┫╰┫╰┫╭╮┃┃\033[0m╱\033[1;37m┃╰━╯┃╰━╯┃╰╯┃┃━┫┃/////
\033[1;33m╰━━━╯╰━┻━━┻━┻━┻╯╰┻╯\033[0m╱\033[1;37m╰━━━┻━╮╭┻━━┻━━┻╯//
\033[0m//╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱\033[1;37m╭━╯┃\033[0m///////
   ╱╱╱╱╱╱/╱╱╱╱╱╱╱╱╱╱╱╱╱\033[1;37m╰━━╯\033[0m//
'

# Check if jq is installed, if not, prompt to install
if ! command -v jq &>/dev/null; then
  clear
  echo -e "$TITLE"

  read -p "jq is a required dependency that is currently not installed on your machine. Would you like to install it? (y/n): " choice
  if [ "$choice" == "y" ]; then
    case "$(uname -s)" in
    Linux)
      sudo apt-get update
      if [ $? -ne 0 ]; then
        echo "Failed to update package list. Please check your network connection and try again."
        exit 1
      fi
      sudo apt-get install -y jq
      if [ $? -ne 0 ]; then
        echo "Failed to install jq. Please try installing jq manually."
        exit 1
      fi
      ;;
    Darwin)
      brew install jq
      if [ $? -ne 0 ]; then
        echo "Failed to install jq using Homebrew. Please try installing jq manually."
        exit 1
      fi
      ;;
    *)
      echo "Unsupported OS. The script only supports Linux and Darwin environments. Please install jq manually from https://jqlang.github.io/jq/."
      echo "For Windows environments, use 'winget install jqlang.jq' to install jq."
      exit 1
      ;;
    esac
  else
    echo "jq is not installed. Please install jq before running the script. This script will now exit."
    exit 1
  fi
fi

# TODO: implement version check and prompt user to install latest version. if on latest version, display version number under title

config_file="config.json"

# ANSI color codes using tput
color_highlight=$(tput setaf 2) # Green text
color_reset=$(tput sgr0)        # Reset to default colors

# Function to display menu and handle selection
display_menu() {
  local menu_title="$1"
  shift
  local options=("$@")
  local selection=0
  local options_per_line=4

  # Function to display options horizontally
  display_options() {
    clear
    echo -e "$menu_title"
    local line=""
    for i in "${!options[@]}"; do
      if [[ $i == $selection ]]; then
        line+="$(tput bold)${color_highlight}> ${options[$i]}${color_reset}$(tput sgr0)"
      else
        line+="  ${options[$i]}"
      fi
      if [[ $((i % options_per_line)) != $((options_per_line - 1)) && $i != $((${#options[@]} - 1)) ]]; then
        line+="   "
      else
        echo "$line"
        line=""
      fi
    done
    echo
  }

  # Function to handle key presses
  read_key() {
    IFS= read -rsn1 key
    if [[ $key == $'\x1b' ]]; then
      IFS= read -rsn2 key
      case $key in
      '[A') echo up ;;
      '[B') echo down ;;
      '[D') echo left ;;
      '[C') echo right ;;
      esac
    elif [[ $key == "" ]]; then
      echo enter
    fi
  }

  # Function to check if file exists and download if not
  download_if_script_missing() {
    local option_name="$1"
    local script_path="tools/${option_name}.sh"
    local url=$(jq -r --arg name "$option_name" '.options[] | select(.name == $name) | .gist_URL' "$config_file")

    # Create the tools directory if it doesn't exist
    if ! mkdir -p "tools"; then
      echo "Error: Unable to create 'tools' directory." >&2
      exit 1
    fi

    # Check if the URL is valid
    if [[ -z "$url" ]]; then
      echo "Error: URL for '$option_name' not found in $config_file." >&2
      exit 1
    fi

    # Proceed to download script
    if ! curl -s -f -L "$url" -o "$script_path"; then
      echo "Error: Failed to download script '$option_name' from $url. Please ensure the URL is valid." >&2
      exit 1
    else
      chmod +x "$script_path"
    fi
  }

  # Function to display the submenu for a selected option
  display_submenu() {
    local option_name="$1"
    # Fetch description from config.json based on option_name
    local description=$(jq -r --arg name "$option_name" '.options[] | select(.name == $name) | .description' "$config_file")

    if [[ $option_name == "Clean Up" ]]; then
      local submenu_options=("Yes" "No")
      local wMsg="$(tput setaf 1)Warning${color_reset}: This will delete all files from the Stellar Cyber Scripts Pro root directory. Would you like to continue with the clean up?"
    else
      local submenu_options=("Run" "Help" "Simulate" "Back")
      local wMsg="Submenu for ${option_name}:"
    fi

    local submenu_selection=0
    local submenu_options_per_line=4

    while true; do
      display_options
      echo -e "$wMsg"

      local line=""
      for i in "${!submenu_options[@]}"; do
        if [[ $i == $submenu_selection ]]; then
          line+="$(tput bold)${color_highlight}> ${submenu_options[$i]}${color_reset}$(tput sgr0)"
        else
          line+="  ${submenu_options[$i]}"
        fi
        if [[ $((i % submenu_options_per_line)) != $((submenu_options_per_line - 1)) && $i != $((${#submenu_options[@]} - 1)) ]]; then
          line+="   "
        else
          echo "$line"
          line=""
        fi
      done

      case $(read_key) in
      left)
        ((submenu_selection--))
        if ((submenu_selection < 0)); then
          submenu_selection=$((${#submenu_options[@]} - 1))
        fi
        ;;
      right)
        ((submenu_selection++))
        if ((submenu_selection >= ${#submenu_options[@]})); then
          submenu_selection=0
        fi
        ;;
      enter)
        local selected_suboption="${submenu_options[$submenu_selection]}"
        if [[ $option_name == "Clean Up" ]]; then
          if [[ $selected_suboption == "Yes" ]]; then
            echo "Cleaning up... You may need to input your machine password"
            # Store the current directory name
            directory_name=$(pwd)

            # Count the number of files and directories in the current directory
            file_count=$(find "$directory_name" -type f | wc -l)
            dir_count=$(find "$directory_name" -type d | wc -l)
            total_count=$((file_count + dir_count))
            cd ..
            sudo rm -r "$directory_name"

            # Output the total count of files and directories deleted
            echo "Deleted $total_count items (files: $file_count, directories: $dir_count). The script will now exit."

            exit 0
          elif [[ $selected_suboption == "No" ]]; then
            echo "Clean up canceled. Returning to menu."
            read -n1 -r -p "Press any key to return to menu..."
            break
          fi
        fi

        if [[ $selected_suboption == "Back" ]]; then
          break
        elif [[ $selected_suboption == "Run" ]]; then
          download_if_script_missing "$option_name"
          "./tools/${option_name}.sh"
          read -n1 -r -p "Press any key to return to submenu..."
        elif [[ $selected_suboption == "Help" ]]; then
          clear
          echo -e "$TITLE"
          echo -e "$(tput setaf 2)> $option_name - Help$(tput sgr0)\n"
          echo "$description" # Display description fetched from config.json
          read -n1 -r -p "Press any key to return to submenu..."
        elif [[ $selected_suboption == "Simulate" ]]; then
          echo "Simulating $option_name"
          # TODO: Add simulation logic here
          read -n1 -r -p "Press any key to return to submenu..."
        fi
        ;;
      esac
    done
  }

  # Main loop
  while true; do
    display_options
    case $(read_key) in
    left)
      ((selection--))
      if ((selection < 0)); then
        selection=$((${#options[@]} - 1))
      fi
      ;;
    right)
      ((selection++))
      if ((selection >= ${#options[@]})); then
        selection=0
      fi
      ;;
    up)
      ((selection -= options_per_line))
      if ((selection < 0)); then
        selection=0
      fi
      ;;
    down)
      ((selection += options_per_line))
      if ((selection >= ${#options[@]})); then
        selection=$((${#options[@]} - 1))
      fi
      ;;
    enter)
      clear
      local selected_option="${options[$selection]}"
      if [[ $selected_option == "Clean Up" ]]; then
        display_submenu "Clean Up" "Are you sure?" "Yes" "No"
      elif [[ $selected_option == "Quit" ]]; then
        exit 0
      else
        display_submenu "$selected_option"
      fi
      ;;
    esac
  done
  clear
}

# Function to read options from config.json and populate initial_options
read_options_from_config() {
  local temp_options=()

  # Read option names from config.json using jq
  while IFS= read -r name; do
    temp_options+=("$name")
  done < <(jq -r '.options[].name' "$config_file")

  # Assign to initial_options array
  initial_options=("${temp_options[@]}")

  # Append "Back" and "Quit" options separately
  initial_options+=("Clean Up" "Quit")
}

# Call function to read options from config.json and populate initial_options
read_options_from_config

# Call the display_menu function with initial options and TITLE variable
display_menu "$TITLE" "${initial_options[@]}"
