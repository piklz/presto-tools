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
#             automatical one shot updates your whole docker-stacked system with
#             image cleanup at the end for a clean, space saving, smooth docker experience , ie. can be used
#             with a cron job ,for example to execute it every week and update the containers and prune the left
#             over images? (see below for instructions )
#             to use run:  sudo ./presto-tools_install.sh
#
#--------------------------------------------------------------------------------------------------
# version 2.1
# author        : piklz
# github        : https://github.com/piklz/presto-tools.git
# description   : This script installs the presto-tools and its dependencies.
# changes       : - added bash completion for presto_drive_status.sh and log checks and updates
#
# Changelog:
#   Version 2.1 (2025-08-26): Consolidated logging to use systemd-cat, removed old file-based logging. Added robust check 
#     for ~/.bash_aliases in ~/.bashrc to ensure it's sourced correctly on DietPi. Implemented --help flag for user guidance and standardized code style.
#   Version 2.0 (2025-08-21): Refactored to use systemd-journald logging. Added --verbose flag. Improved error handling for whiptail and git commands.
#   Version 1.1 (2025-08-15): Added a check to ensure scripts are executable. Added bash completion for presto_drive_status.sh.
#   Version 1.0 (2025-08-01): Initial release with basic cloning and ~/.bashrc configuration.
#
#########################################################################################################################

# --- Configuration and variables
VERSION='2.1'
JOURNAL_TAG="presto-tools_install"
set -e

# --- Determine the real user's home directory, even when run with sudo. ---
USER_HOME=""
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    USER="$SUDO_USER"
else
    USER_HOME="$HOME"
    USER="$(id -un)"
fi

INSTALL_DIR="$USER_HOME/presto-tools"
BASHRC="$USER_HOME/.bashrc"
VERBOSE_MODE=0

# --- Color variables using C-style escapes
no_col='\e[0m'       # No Color
red='\e[31m'         # Red
yellow='\e[33m'      # Yellow
green='\e[32m'       # Green
blue='\e[34m'        # Blue
cyan='\e[36m'        # Cyan
magenta='\e[35m'     # Magenta

# --- Check if a command exists
is_command() {
    local check_command="$1"
    command -v "${check_command}" >/dev/null 2>&1
}

# --- Logging function using systemd-cat
log_message() {
    local log_level="$1"
    local console_message="$2"
    local priority

    # Map log levels to systemd priorities
    case "$log_level" in
        "ERROR") priority="err" ;;
        "WARNING") priority="warning" ;;
        "INFO") priority="info" ;;
        "DEBUG") [ "$VERBOSE_MODE" -eq 0 ] && return; priority="debug" ;;
        *) priority="info" ;;
    esac

    # Log to journald if systemd-cat is available
    if is_command systemd-cat; then
        systemd-cat -t "$JOURNAL_TAG" -p "$priority" <<< "$console_message" 2>/dev/null || {
            [ "$log_level" = "ERROR" ] && echo -e "${yellow}[$JOURNAL_TAG] [ERROR] Failed to log to journald: $console_message${no_col}" >&2
        }
    else
        [ "$log_level" = "ERROR" ] && echo -e "${yellow}[$JOURNAL_TAG] [ERROR] systemd-cat not available: $console_message${no_col}" >&2
    fi

    # Display to console for all log levels in this script
    local color
    case "$log_level" in
        "ERROR") color="${red}" ;;
        "WARNING") color="${yellow}" ;;
        "INFO") color="${cyan}" ;;
        "DEBUG") color="${no_col}" ;;
        *) color="${no_col}" ;;
    esac
    echo -e "${color}[$JOURNAL_TAG] [$log_level] $console_message${no_col}"
}

# --- Help message function
print_help() {
    printf "
presto-tool_install.sh (v${VERSION})
""
Usage: sudo ./presto-tools_install.sh [OPTIONS]

This script installs and configures presto-tools on your system.

Options:
  --help             Show this help message and exit.
  --verbose          Enable verbose output for debugging.

The script performs the following actions:
1.  Clones or updates the presto-tools git repository.
2.  Ensures required scripts are executable.
3.  Adds the presto_bashwelcome.sh script to your ~/.bashrc file.
4.  Adds a check for a ~/.bash_aliases file to your ~/.bashrc.
5.  Installs bash completion for presto_drive_status.sh.

To view journal logs for this script, use:
  journalctl -t presto-tools_install -n 10
""
"
}

# --- Main script logic ---

# Parse command-line arguments.
for arg in "$@"; do
    case "$arg" in
        --verbose)
            VERBOSE_MODE=1
            log_message "INFO" "Verbose mode enabled."
            shift
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            log_message "ERROR" "Unknown argument: $arg. Use --help for usage information."
            exit 1
            ;;
    esac
done

# Check if the presto-tools directory exists
if [ ! -d "$INSTALL_DIR" ]; then
    log_message "INFO" "presto-tools folder not found. Cloning repository."
    git clone -b main https://github.com/piklz/presto-tools "$INSTALL_DIR"
else
    log_message "INFO" "presto-tools folder already exists. Checking for updates..."
    cd "$INSTALL_DIR" && git fetch
    if git status | grep -q "Your branch is up to date"; then
        [ -f "$INSTALL_DIR/.outofdate" ] && rm "$INSTALL_DIR/.outofdate"
        log_message "INFO" "PRESTO Git local/repo is up-to-date."
    else
        log_message "INFO" "PRESTO update is available. Pulling..."
        git pull origin main
        if [ ! -f "$INSTALL_DIR/.outofdate" ]; then
            whiptail --title "Project update" --msgbox "PRESTO update is available \nYou will not be reminded again until your next update" 8 78
            touch "$INSTALL_DIR/.outofdate"
        fi
    fi
fi

# Ensure scripts are executable
chmod +x "$INSTALL_DIR/scripts/presto_bashwelcome.sh"
chmod +x "$INSTALL_DIR/scripts/presto_drive_status.sh"
chmod +x "$INSTALL_DIR/scripts/presto_update_full.py"
chmod +x "$INSTALL_DIR/scripts/.presto_bash_aliases"

# Add presto_bashwelcome.sh to .bashrc
WELCOME_SCRIPT="$INSTALL_DIR/scripts/presto_bashwelcome.sh"
if [ -f "$WELCOME_SCRIPT" ]; then
    if ! grep -q ". $WELCOME_SCRIPT" "$BASHRC"; then
        log_message "INFO" "Adding presto_bashwelcome.sh to .bashrc..."
        echo -e "\n#presto-tools Added: presto_bash_welcome script" >> "$BASHRC"
        echo ". $WELCOME_SCRIPT" >> "$BASHRC"
    else
        log_message "INFO" "presto_bashwelcome.sh already added to .bashrc."
    fi
else
    log_message "WARNING" "presto_bashwelcome.sh not found. Skipping addition to .bashrc."
fi

# Add the .bash_aliases check to .bashrc
ALIAS_CHECK_PATTERN="if \[ -f ~\/.bash_aliases \]; then"
if grep -q "$ALIAS_CHECK_PATTERN" "$BASHRC"; then
    log_message "INFO" "Your .bashrc is already configured to source ~/.bash_aliases."
else
    log_message "INFO" ".bash_aliases check not found in .bashrc. Adding now..."
    printf "\n# Alias definitions (added by presto-tools install).\n" >> "$BASHRC"
    cat << 'EOF' >> "$BASHRC"
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF
    log_message "INFO" ".bash_aliases check added to $BASHRC."
fi

# Install bash completion
install_presto_completion() {
    local INSTALL_DIR="$USER_HOME/.bash_completion.d"
    local COMPLETION_FILE="$INSTALL_DIR/presto_drive_status_completion"
    local BASHRC_FILE="$USER_HOME/.bashrc"

    # Check if completion is already installed.
    if [ -f "$COMPLETION_FILE" ] && grep -qF "Load custom Bash completion scripts" "$BASHRC_FILE"; then
        log_message "INFO" "Bash completion is already installed."
        return 0
    fi

    log_message "INFO" "Installing Bash completion for presto_drive_status.sh..."

    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR" || {
            log_message "ERROR" "Failed to create completion directory '$INSTALL_DIR'."
            return 1
        }
    fi

    cat << EOF > "$COMPLETION_FILE"
_complete_presto_drive_status() {
    local cur_word prev_word
    COMPREPLY=()

    if [ "\${prev_word}" = "--device" ]; then
        local devices=\$(lsblk -p -o NAME,TYPE -n | grep -E 'disk|part' | awk '{print \$1}')
        COMPREPLY=( \$(compgen -W "\${devices}" -- "\${cur_word}") )
    else
        local valid_options="--help --moreinfo --simple --device --all-partitions"
        COMPREPLY=( \$(compgen -W "\${valid_options}" -- "\${cur_word}") )
    fi
}
complete -F _complete_presto_drive_status presto_drive_status
complete -F _complete_presto_drive_status "$USER_HOME/presto-tools/scripts/presto_drive_status.sh"
EOF

    if ! grep -qF "Load custom Bash completion scripts" "$BASHRC_FILE"; then
        printf "\n# Load custom Bash completion scripts from %s\n" "$INSTALL_DIR" >> "$BASHRC_FILE"
        printf "for file in %s/*; do [ -f \"\$file\" ] && . \"\$file\"; done\n" "$INSTALL_DIR" >> "$BASHRC_FILE"
        log_message "INFO" "Bash completion added to ~/.bashrc. Please source it or restart your terminal."
    fi

    log_message "INFO" "Bash completion for presto_drive_status.sh installed successfully."
}

install_presto_completion

log_message "INFO" "Presto-tools installation complete!"
log_message "INFO" "Please run 'source ~/.bashrc' or start a new terminal to use the welcome script."