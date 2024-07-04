#!/bin/bash

# TODO: implement dependency check for jq

# TODO: implement version check and prompt user to install latest version. if on latest version, display version number under title

# Define the TITLE variable with your ASCII art
TITLE=$'\033[1;33m╭━━━╮╭╮\033[0m╱╱╱\033[1;33m╭╮╭╮\033[0m╱╱╱╱╱╱\033[1;37m╭━━━╮\033[0m╱╱╱\033[1;37m╭╮//////
\033[1;33m┃╭━╮┣╯╰╮\033[0m╱╱\033[1;33m┃┃┃┃\033[0m╱╱╱╱╱╱\033[1;37m┃╭━╮┃\033[0m╱╱╱\033[1;37m┃┃/////////
\033[1;33m┃╰━━╋╮╭╋━━┫┃┃┃╭━━┳━╮\033[1;37m┃┃\033[0m╱\033[1;37m╰╋╮\033[0m╱\033[1;37m╭┃╰━┳━━┳━┓/////////
\033[1;33m╰━━╮┃┃┃┃┃━┫┃┃┃┃╭╮┃╭╯\033[1;37m┃┃\033[0m╱\033[1;37m╭┫┃\033[0m╱\033[1;37m┃┃╭╮┃┃━┫╭╯//////
\033[1;33m┃╰━╯┃┃╰┫┃━┫╰┫╰┫╭╮┃┃\033[0m╱\033[1;37m┃╰━╯┃╰━╯┃╰╯┃┃━┫┃/////
\033[1;33m╰━━━╯╰━┻━━┻━┻━┻╯╰┻╯\033[0m╱\033[1;37m╰━━━┻━╮╭┻━━┻━━┻╯//
\033[0m//╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱\033[1;37m╭━╯┃\033[0m///////
   ╱╱╱╱╱╱/╱╱╱╱╱╱╱╱╱╱╱╱╱\033[1;37m╰━━╯\033[0m//
'
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
      echo "Error: Failed to download script '$option_name' from $url. Please ensure the URL is valid" >&2
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
            echo "Cleaning up..."
            # TODO: add clean up functionality

            read -n1 -r -p "Press any key to return to menu..."
          elif [[ $selected_suboption == "No" ]]; then
            echo "Clean up canceled. Returning to menu"
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
          # TODO: Add your simulation logic here
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
