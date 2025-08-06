#!/usr/bin/env bash
# shellcheck disable=SC1090
#  __/\\\\\\\\\\\\\______/\\\\\\\\\______/\\\\\\\\\\\\\\\_____/\\\\\\\\\\\____/\\\\\\\\\\\\\\\_______/\\\\\______        
#   _\/\\\/////////\\\__/\\\///////\\\___\/\\\///////////____/\\\/////////\\\_\///////\\\/////______/\\\///\\\____       
#    _\/\\\_______\/\\\_\/\\\_____\/\\\___\/\\\______________\//\\\______\///________\/\\\_________/\\\/__\///\\\__      
#     _\/\\\\\\\\\\\\\/__\/\\\\\\\\\\\/____\/\\\\\\\\\\\_______\////\\\_______________\/\\\________/\\\______\//\\\_     
#      _\/\\\/////////____\/\\\//////\\\____\/\\\///////___________\////\\\____________\/\\\_______\/\\\_______\/\\\_    
#       _\/\\\_____________\/\\\____\//\\\___\/\\\_____________________\////\\\_________\/\\\_______\//\\\______/\\\__   
#        _\/\\\_____________\/\\\_____\//\\\__\/\\\______________/\\\______\//\\\________\/\\\________\///\\\__/\\\____  
#         _\/\\\_____________\/\\\______\//\\\_\/\\\\\\\\\\\\\\\_\///\\\\\\\\\\\/_________\/\\\__________\///\\\\\/_____ 
#          _\///______________\///________\///__\///////////////____\///////////___________\///_____________\/////_______

#######################################################  TOOLS  #########################################################
#-------------------------------------------------------------------------------------------------
# Welcome to the presto TOOLS INSTALL SCRIPT
#
# -presto-tools_install .sh  (The actual install script for this kit )
# -presto_bashwelcome.sh    (Gives you nice info on your pi' running state)
# -presto_update_full.py >
# 		    automatical one shot updates your whole docker-stacked system with 
# 			image cleanup at the end for a clean, space saving, smooth docker experience , ie. can be used 
# 			with a cron job ,for example to execute it every week and update the containers and prune the left
# 			over images? (see below for instructions )
#  			to use run:  sudo ./presto-tools_install.sh
#
#--------------------------------------------------------------------------------------------------
# version 2.0
# author		: piklz
# github		: https://github.com/piklz/presto-tools.git
# description	: This script installs the presto-tools and its dependencies.
# changes  		: - added bash completion for presto_drive_status.sh
#
#########################################################################################################################


set -e

# --- Determine the real user's home directory, even when run with sudo. ---
USER_HOME=""
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    USER_HOME="$HOME"
fi

# Set the color variables using printf.
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_GREEN='\e[0;32m'
COL_LIGHT_RED='\e[1;31m'
COL_INFO='\e[1;34m' # Blue for INFO messages
TICK="[${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="[${COL_LIGHT_RED}✗${COL_NC}]"
INFO="[i]"
DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
OVER="\\r\\033[K"
COL_PINK="\e[1;35m"
COL_LIGHT_CYAN="\e[1;36m"
COL_LIGHT_PURPLE="\e[1;34m"
COL_LIGHT_YELLOW="\e[1;33m"
COL_LIGHT_GREY="\e[1;2m"
COL_ITALIC="\e[1;3m"

# Dynamic log file path.
LOG_FILE=""

# Function to determine the correct log file path based on permissions.
set_log_file_path() {
    # Check if the script is being run as root.
    if [ "$(id -u)" -eq 0 ]; then
        LOG_FILE="/var/log/presto-tools_install.log"
    else
        # Fallback to user-owned directory.
        mkdir -p "$USER_HOME/.local/state/presto" || { printf "Error: Could not create user log directory.\n" >&2; exit 1; }
        LOG_FILE="$USER_HOME/.local/state/presto/presto-tools_install.log"
    fi
}

# Function to log messages to file and screen.
log_message() {
    local log_level="$1"
    local console_message="$2"
    local log_file_message="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log to file without color codes. Use provided log_file_message or default to console_message.
    if [ -z "$log_file_message" ]; then
        log_file_message="$console_message"
    fi
    printf "[%s] [presto-tools_install] %s %s\n" "$timestamp" "$log_level" "$log_file_message" >> "$LOG_FILE"

    # Print to console with color and prefix.
    printf "[presto-tools_install] %b%s%b %s\n" "${COL_INFO}" "$log_level" "${COL_NC}" "$console_message"
}

# --- Main script logic starts here ---
set_log_file_path

# Function to update the existing git repository.
git_pull_update() {
    log_message "INFO" "GIT pulling the presto-tools now."
    cd "$USER_HOME/presto-tools" && git pull origin main
}

# Function to clone the git repository.
git_pull_clone() {
    log_message "INFO" "GIT cloning the presto-tools now."
    git clone -b main https://github.com/piklz/presto-tools "$USER_HOME/presto-tools"
    do_install_prestobashwelcome
}

# Function to install the welcome message in .bashrc.
do_install_prestobashwelcome() {
    if grep -Fxq ". $USER_HOME/presto-tools/scripts/presto_bashwelcome.sh" "$USER_HOME/.bashrc"; then
        log_message "INFO" "Found presto Welcome login link in bashrc. No changes needed."
    else
        log_message "INFO" "presto Welcome Bash (in bash.rc) is missing. Adding now..."
        printf "\n#presto-tools Added: presto_bash_welcome scripty\n" >> "$USER_HOME/.bashrc"
        printf ". $USER_HOME/presto-tools/scripts/presto_bashwelcome.sh\n" >> "$USER_HOME/.bashrc"
    fi
}

# --- Bash Completion Logic (This is a helper function that stores text) ---
_get_completion_logic() {
    cat << 'EOF'
_complete_presto_drive_status() {
    local cur_word prev_word
    COMPREPLY=()
    
    if [ "${prev_word}" = "--device" ]; then
        local devices=$(lsblk -p -o NAME,TYPE -n | grep -E 'disk|part' | awk '{print $1}')
        COMPREPLY=( $(compgen -W "${devices}" -- "${cur_word}") )
    else
        local valid_options="--help --moreinfo --simple --device --all-partitions"
        COMPREPLY=( $(compgen -W "${valid_options}" -- "${cur_word}") )
    fi
}
complete -F _complete_presto_drive_status presto_drive_status
complete -F _complete_presto_drive_status "$USER_HOME/presto-tools/scripts/presto_drive_status.sh"
EOF
}

# --- Bash Completion Installation Function ---
install_presto_completion() {
    local INSTALL_DIR="$USER_HOME/.bash_completion.d"
    local COMPLETION_FILE="$INSTALL_DIR/presto_drive_status_completion"
    local BASHRC_FILE="$USER_HOME/.bashrc"
    
    # Check if completion is already installed.
    if [ -f "$COMPLETION_FILE" ] && grep -qF "Load custom Bash completion scripts" "$BASHRC_FILE"; then
        return 0 # Already installed, exit silently.
    fi
    
    log_message "INFO" "Installing Bash completion for presto_drive_status.sh..."
    
    # Check and create the completion directory if it doesn't exist.
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR" || {
            log_message "ERROR" "Failed to create completion directory '$INSTALL_DIR'. Exiting."
            return 1
        }
    fi
    
    # Write the completion file.
    _get_completion_logic > "$COMPLETION_FILE"
    
    # Add the sourcing snippet to .bashrc.
    if ! grep -qF "Load custom Bash completion scripts" "$BASHRC_FILE"; then
        printf "\n# Load custom Bash completion scripts from %s\n" "$INSTALL_DIR" >> "$BASHRC_FILE"
        printf "for file in %s/*; do [ -f \"\$file\" ] && . \"\$file\"; done\n" "$INSTALL_DIR" >> "$BASHRC_FILE"
        log_message "INFO" "Bash completion added to ~/.bashrc. Please source it or restart your terminal."
    fi

    log_message "INFO" "Bash completion for presto_drive_status.sh installed successfully."
}

# --- Main script logic. ---
if [ ! -d "$USER_HOME/presto-tools" ]; then
    git_pull_clone
else
    log_message "INFO" "presto-tools folder already exists. Checking for updates..."
    cd "$USER_HOME/presto-tools" && git fetch
    if git status | grep -q "Your branch is up to date"; then
        [ -f "$USER_HOME/presto-tools/.outofdate" ] && rm "$USER_HOME/presto-tools/.outofdate"
        log_message "INFO" "PRESTO Git local/repo is up-to-date."
    else
        log_message "INFO" "PRESTO update is available. Pulling..."
        git_pull_update
        if [ ! -f "$USER_HOME/presto-tools/.outofdate" ]; then
            whiptail --title "Project update" --msgbox "PRESTO update is available \nYou will not be reminded again until your next update" 8 78
            touch "$USER_HOME/presto-tools/.outofdate"
        fi
    fi
fi

# --- Install completion after clone or update. ---
install_presto_completion