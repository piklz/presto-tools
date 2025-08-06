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
# author		: piklz
# github		: https://github.com/piklz/presto-tools.git
# web		   	: https://github.com/piklz/presto-tools.git
#
#########################################################################################################################

#install tools script
#presto toolkit xtras for future use

#!/usr/bin/env bash
set -e

# Get the user's home directory.
if [ -z "${HOME}" ]; then
    HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
fi

# Set the color variables using printf.
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_GREEN='\e[0;32m'
COL_LIGHT_RED='\e[1;31m'
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

# Function to update the existing git repository.
git_pull_update() {
    printf "[presto-tools]%b%s%b GIT pulling the presto-tools now:\n" "${COL_LIGHT_CYAN}" "${INFO}" "${COL_NC}"
    cd "$HOME/presto-tools" && git pull origin main
}

# Function to clone the git repository.
git_pull_clone() {
    printf "GIT cloning the presto-tools now:\n"
    git clone -b main https://github.com/piklz/presto-tools "$HOME/presto-tools"
    do_install_prestobashwelcome
}

# Function to install the welcome message in .bashrc.
do_install_prestobashwelcome() {
    if grep -Fxq ". $HOME/presto-tools/scripts/presto_bashwelcome.sh" "$HOME/.bashrc"; then
        printf "Found presto Welcome login link in bashrc. No changes needed.\n"
    else
        printf "presto Welcome Bash (in bash.rc) is missing. Adding now...\n"
        printf "\n#presto-tools Added: presto_bash_welcome scripty\n" >> "$HOME/.bashrc"
        printf ". $HOME/presto-tools/scripts/presto_bashwelcome.sh\n" >> "$HOME/.bashrc"
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
complete -F _complete_presto_drive_status "$HOME/presto-tools/scripts/presto_drive_status.sh"
EOF
}

# --- Bash Completion Installation Function ---
install_presto_completion() {
    local INSTALL_DIR="$HOME/.bash_completion.d"
    local COMPLETION_FILE="$INSTALL_DIR/presto_drive_status_completion"
    local BASHRC_FILE="$HOME/.bashrc"
    
    # Check and create the completion directory if it doesn't exist.
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR" || {
            printf "Error: Failed to create completion directory '%s'. Exiting.\n" "$INSTALL_DIR" >&2
            return 1
        }
    fi
    
    # Write the completion file.
    _get_completion_logic > "$COMPLETION_FILE"
    
    # Add the sourcing snippet to .bashrc if it doesn't exist.
    if ! grep -qF "Load custom Bash completion scripts" "$BASHRC_FILE"; then
        printf "\n# Load custom Bash completion scripts from %s\n" "$INSTALL_DIR" >> "$BASHRC_FILE"
        printf "for file in %s/*; do [ -f \"\$file\" ] && . \"\$file\"; done\n" "$INSTALL_DIR" >> "$BASHRC_FILE"
        printf "Bash completion added to ~/.bashrc. Please source it or restart your terminal.\n"
    fi

    printf "Bash completion for presto_drive_status.sh installed successfully.\n"
}

# --- Main script logic. ---
if [ ! -d "$HOME/presto-tools" ]; then
    git_pull_clone
else
    printf "presto-tools folder already exists. Checking for updates...\n"
    cd "$HOME/presto-tools" && git fetch
    if git status | grep -q "Your branch is up to date"; then
        [ -f "$HOME/presto-tools/.outofdate" ] && rm "$HOME/presto-tools/.outofdate"
        printf "%s %b PRESTO Git local/repo is up-to-date%b\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    else
        printf "%s %b PRESTO update is available%b ✓%b\n" "${INFO}" "${COL_GREEN}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        git_pull_update
        if [ ! -f "$HOME/presto-tools/.outofdate" ]; then
            whiptail --title "Project update" --msgbox "PRESTO update is available \nYou will not be reminded again until your next update" 8 78
            touch "$HOME/presto-tools/.outofdate"
        fi
    fi
fi

# --- Install completion after clone or update. ---
install_presto_completion