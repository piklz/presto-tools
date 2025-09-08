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

##################################################################################################
#-------------------------------------------------------------------------------------------------
# presto-tools Welcome Script
# Version: 1.0.7
# Author: piklz
# GitHub: https://github.com/piklz/presto-tools.git
# Description:
#   Displays a colorful system information dashboard for Raspberry Pi, including CPU/GPU temperatures, disk usage,
#   Docker status, and weather. Customizable via a configuration file. Logs to systemd-journald, with rotation
#   managed by journald (compatible with future log2ram integration).
#
# Changelog:
#   Version 1.0.8 (2025-09-02):
#     - Added VERBOSE_MODE check to suppress non-critical messages in non-verbose mode (show_info dim grey parts...)
#   Version 1.0.7 (2025-09-02):
#     - Added 'pixel' logo style and --help option
#   Version 1.0.6 (2025-09-02):
#     - Fixed syntax error in SUDO_USER check and removed erroneous System: line
#   Version 1.0.5 (2025-09-02):
#     - Added -logo argument to select logo style (colorbars, simple, ascii)
#
# Usage:
#   Run the script directly: `bash presto_bashwelcome.sh [-logo {colorbars|simple|ascii|pixel}] [--help]`
#   - The -logo argument selects the logo style (default: colorbars).
#   - The --help argument displays this help message.
#   - Customize display options (e.g., show_docker_info, show_drive_info) by editing
#     `$HOME/presto-tools/scripts/presto_config.local`. (just cp presto_config.defaults to presto_config.local and edit 
#        this one, the script will override with your .local version)
#   - Logs can be viewed with: `journalctl -t presto_bashwelcome`.
#   - Ensure dependencies (curl, docker, lsblk, df, free) are installed for full functionality.
# -----------------------------------------------


# Global variables and defaults (overridden by presto_config.local 
# ie. just cp presto_config.defaults in scripts folder to presto_config.local and edit that one)

script_VERSION='1.0.8'
VERBOSE_MODE=0  # Default to prevent integer expression error
LOGO_STYLE="colorbars"  # Default logo style

# Check if running in an interactive shell
if [[ ! -t 0 ]]; then
    exit 0  # Silently exit in non-interactive shells
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -logo)
            if [[ -n "$2" && "$2" =~ ^(colorbars|simple|ascii|pixel)$ ]]; then
                LOGO_STYLE="$2"
                shift 2
            else
                echo "Error: Invalid logo style. Use: colorbars, simple, ascii, or pixel"
                exit 1
            fi
            ;;
        --help)
            echo -e "${cyan}presto-tools Welcome Script${no_col}"
            echo -e "Version: $script_VERSION"
            echo -e "Author: piklz"
            echo -e "GitHub: https://github.com/piklz/presto-tools.git"
            echo -e "\nDescription:"
            echo -e "  Displays a colorful system information dashboard for Raspberry Pi, including CPU/GPU temperatures, disk usage,"
            echo -e "  Docker status, and weather. Customizable via a configuration file. Logs to systemd-journald."
            echo -e "\nUsage:"
            echo -e "  $0 [-logo {colorbars|simple|ascii|pixel}] [--help]"
            echo -e "  -logo: Select logo style (default: colorbars)"
            echo -e "  --help: Display this help message"
            echo -e "\nConfiguration:"
            echo -e "  Customize options in \$HOME/presto-tools/scripts/presto_config.local"
            echo -e "  View logs with: journalctl -t presto_bashwelcome"
            exit 0
            ;;
        *)
            echo "Error: Unknown argument: $1"
            echo "Usage: $0 [-logo {colorbars|simple|ascii|pixel}] [--help]"
            exit 1
            ;;
    esac
done

# Determine real user's home directory
USER_HOME=""
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    USER="$SUDO_USER"
else
    USER_HOME="$HOME"
    USER="$(id -un)"
fi

# Color variables
no_col="\e[0m"
white="\e[37m"
cyan="\e[36m"
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
magenta="\e[35m"
magenta_dim="\e[35;2m"
grey="\e[1;30m"
grey_dim="\e[2;30m"
lgt_red="\e[1;31m"
lgt_green="\e[1;32m"
lgt_green_inv="\e[7;32m"
TICK="[${lgt_green}✓${no_col}]"
CROSS="[${lgt_red}✗${no_col}]"
INFO="[i]"
DONE="${lgt_green} done!${no_col}"

# Additional color definitions for pixel logo
f=3 b=4
for j in f b; do
  for i in {0..7}; do
    printf -v $j$i %b "\e[${!j}${i}m"
  done
done
for i in {0..7}; do
    printf -v g$i %b "\e[9${i}m"
done
bd=$'\e[1m'
rt=$'\e[0m'
iv=$'\e[7m'

# Function to display the logo based on the selected style
display_logo() {
    case "$LOGO_STYLE" in
        colorbars)
            # TV color bar graphic
            for y in $(seq 0 10); do
                printf %s '  '
                for color in 7 3 6 2 5 1 4 ; do
                    tput setab ${color}
                    printf %s '       '
                done
                tput sgr0
                echo
            done
            for y in 0 1; do
                printf %s '  '
                for color in 4 0 5 0 6 0 7 ; do
                    tput setab ${color}
                    printf %s '       '
                done
                tput sgr0
                echo
            done

            # Presto rainbow road title
            text="PRESTO"
            colors=("\e[31m" "\e[33m" "\e[32m" "\e[36m" "\e[34m" "\e[35m")
            for ((i=0; i<${#text}; i++)); do
                color_index=$((i % ${#colors[@]}))
                echo -ne "  ${colors[$color_index]}${text:i:1}"
            done
            echo -e "\e[0m"
            ;;
        simple)
            echo -e "${cyan}PRESTO${no_col}"
            ;;
        ascii)
            echo -e "${cyan}  ╔════════╗${no_col}"
            echo -e "${cyan}  ║ ${white}PRESTO${cyan} ║${no_col}"
            echo -e "${cyan}  ╚════════╝${no_col}"
            ;;
        pixel)
            cat << EOF
  ${g3}                       ██████${f2}P
  ${f1}           ████████    ${g3}██████${f2}R
  ${f1}         ████████████████${g3}████${f2}E
  ${g0}         ████${g3}████${g0}██${g3}█  ${g0}███████${f2}S
  ${g0}      ██${g3}█${g0}██${g3}██████${g0}██${g3}████${g0}██████${f2}T
  ${g0}      ██${g3}██${g0}███${g3}██████${g0}██${g3}████${g0}████${f2}O
  ${g0}      ███${g3}████████${g0}████████
  ${g3}         █████████████${g0}██
  ${g0}   ████████${f1}██${g0}█████${f1}██${g0}██        
  ${g0} ████████████${f1}██${g0}█████${f1}██      ${g0}██
  ${g3}████${g0}█████████${f1}█████████      ${g0}██
  ${g3}█████    ${f1}██${g0}██${f1}███${g3}██${f1}██${g3}██${f1}███${g0}█████
  ${g3} ██ ${g0}██  ${f1}█████████████████${g0}█████
  ${g0}  ██████${f1}█████████████████${g0}█████
  ${g0}█████${f1}█████████████
  ${g0}██   ${f1}██████${rt}  
EOF
            # Presto rainbow road retropi title
            text="  RETROPI"
            colors=("\e[31m" "\e[33m" "\e[32m" "\e[36m" "\e[34m" "\e[35m")
            for ((i=0; i<${#text}; i++)); do
                color_index=$((i % ${#colors[@]}))
                echo -ne "  ${colors[$color_index]}${text:i:1}"
            done
            echo -e "\e[0m"
            ;;
    esac
}

# Check if a command exists
is_command() {
    local check_command="$1"
    command -v "${check_command}" >/dev/null 2>&1
}

# Logging function using systemd-cat
log_message() {
    local log_level="$1"
    local console_message="$2"
    local log_file_message="${3:-$console_message}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local journal_message="[$timestamp] [presto_bashwelcome] [$log_level] $log_file_message"
    local priority

    # Map log levels to systemd priorities
    case "$log_level" in
        "ERROR") priority="err" ;;
        "WARNING") priority="warning" ;;
        "INFO") priority="info" ;;
        "DEBUG") [ "$VERBOSE_MODE" -eq 0 ] && return; priority="debug" ;;
        *) priority="info" ;;
    esac

    # Log to journald
    if is_command systemd-cat; then
        systemd-cat -t presto_bashwelcome -p "$priority" <<< "$journal_message" 2>/dev/null || {
            [ "$log_level" = "ERROR" ] && echo -e "${yellow}[presto_bashwelcome] [ERROR] Failed to log to journald: $console_message${no_col}" >&2
        }
    else
        [ "$log_level" = "ERROR" ] && echo -e "${yellow}[presto_bashwelcome] [ERROR] systemd-cat not available: $console_message${no_col}" >&2
    fi

    # Display to console only for interactive shells and specific conditions
    if [ -t 0 ]; then
        local color
        case "$log_level" in
            "ERROR") color="$red" ;;
            "WARNING") color="$yellow" ;;
            "INFO") color="$cyan" ;;
            "DEBUG") color="$grey" ;;
            *) color="$no_col" ;;
        esac
        # Only display errors matching original behavior
        if [ "$log_level" = "ERROR" ] && [[ "$console_message" =~ "not found" || "$console_message" =~ "unavailable" ]]; then
            echo -e "${color}[presto_bashwelcome] [$log_level] $console_message${no_col}"
        elif [ "$log_level" = "DEBUG" ] && [ "$VERBOSE_MODE" -eq 1 ]; then
            echo -e "${color}[presto_bashwelcome] [$log_level] $console_message${no_col}"
        fi
    fi
}

# Check disk space before critical operations
check_disk_space() {
    local required_space_mb=100
    if [ "$CHECK_DISK_SPACE" -ne 1 ]; then
        log_message "INFO" "Disk space check disabled (CHECK_DISK_SPACE=$CHECK_DISK_SPACE)"
        return 0
    fi
    local available_space_mb
    available_space_mb=$(df -m "$USER_HOME" 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -z "$available_space_mb" ] || ! [[ "$available_space_mb" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "Failed to determine available disk space"
        return 1
    fi
    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        log_message "ERROR" "Insufficient disk space: $available_space_mb MB available, $required_space_mb MB required"
        return 1
    fi
    log_message "INFO" "Disk space check passed: $available_space_mb MB available"
    return 0
}

# Load default configuration
DEFAULT_CONFIG="$USER_HOME/presto-tools/scripts/presto_config.defaults"
if [ ! -f "$DEFAULT_CONFIG" ]; then
    log_message "INFO" "Creating default configuration file $DEFAULT_CONFIG"
    mkdir -p "$USER_HOME/presto-tools/scripts" || { log_message "ERROR" "Failed to create directory for $DEFAULT_CONFIG" "Failed to create directory for $DEFAULT_CONFIG"; echo "Error: Could not create directory for $DEFAULT_CONFIG" >&2; exit 1; }
    cat << EOF > "$DEFAULT_CONFIG"
                                                              
# PRESTO CONFIGS Default configuration settings for presto scripts
# 0 = disabled, 1 = enabled

#bash login logo [colorbars] for dockerplex media setups &  [pixel] for retropies 
LOGO_STYLE="colorbars"

# Show Docker container information
show_docker_info=0

# Show SMART drive health information
show_smartdrive_info=0

# Show general drive information
show_drive_info=0

VERBOSE_MODE=0
log_level="INFO"
CHECK_DISK_SPACE=1
WEATHER_LOCATION="London"

#presto_drive_status
SMART_DEVICE_TYPES="ata,scsi,sat,usbsg"

DEFAULT_OUTPUT_MODE="simple_full"
EOF
    chown "$USER:$USER" "$DEFAULT_CONFIG" 2>/dev/null || true
    chmod 644 "$DEFAULT_CONFIG" 2>/dev/null || true
fi
log_message "INFO" "Loading default configuration from $DEFAULT_CONFIG"
source "$DEFAULT_CONFIG"

# Load user configuration to override defaults
CONFIG_FILE="$USER_HOME/presto-tools/scripts/presto_config.local"
if [ -f "$CONFIG_FILE" ]; then
    log_message "INFO" "Overriding defaults with user configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    log_message "WARNING" "User configuration file $CONFIG_FILE not found, using defaults"
fi

# Ensure VERBOSE_MODE is an integer
if ! [[ "$VERBOSE_MODE" =~ ^[0-9]+$ ]]; then
    log_message "WARNING" "VERBOSE_MODE is invalid ($VERBOSE_MODE), defaulting to 0"
    VERBOSE_MODE=0
fi

# Display the selected logo
display_logo

# Icon graphics
laptop="💻"
gpu="🎮"
house="🏠"
globe="🌐"
calendar="📅"
os="☄️"
filesystem="💾"
clock="🕛"
ram="🐏"
weather="🌘"
timer="⏳"
fan="🔄"

icon_graphics=(
    "$laptop" "$gpu" "$house" "$globe" "$calendar" "$os" "$filesystem" "$clock" "$ram" "$weather" "$timer" "$fan"
)

# Fetch weather
log_message "INFO" "Fetching weather for ${WEATHER_LOCATION}"
weather_info=$(timeout 4 curl -s "https://wttr.in/${WEATHER_LOCATION}?format=%l:+%c+%C+%t+feels-like+%f+\n+++++++++++++++++++phase%m++humid+%h+🌞+%S+🌇+%s+\n" 2>/dev/null || echo "..might be sunny somewhere?")
if [[ "$weather_info" == "..might be sunny somewhere?" ]]; then
    log_message "WARNING" "Weather service [wttr.in] unavailable or timed out"
    echo -e "  ${grey_dim}The weather [wttr.in] is downright now .. continue${no_col}\n"
fi


# Function to print Docker status
print_docker_status() {
    if ! is_command docker; then
        log_message "INFO" "Docker not installed, skipping Docker status"
        echo -e "     "
        echo -e "\e[33;1m  no docker info - no systems running yet \e[0m"
        echo -e "\n"
        return 0
    fi
    check_disk_space || { log_message "ERROR" "Disk space check failed, skipping Docker status"; echo -e "${yellow}Docker info unavailable${no_col}"; return 1; }
    log_message "INFO" "Displaying Docker status"
    echo -e "${cyan}╭─── DOCKER STACK INFO 🐋 ─────────────────PRESTO─────╮"
    echo -e "  ${cyan}TYPE         ${cyan}TOTAL    ${magenta}ACTIVE   ${white}SIZE         ${green}RECLAIMABLE${no_col}"
    docker system df | awk '
        # Skip the header line
        NR > 1 {
            # Check for the multi-word "Local Volumes" type
            if ($1 == "Local" && $2 == "Volumes") {
                # Print "Local Volumes" as a single field
                printf "  %-12s %-8s %-8s %-12s %-12s\n", "Local Vols", $3, $4, $5, $6
            } 
            # Check for the multi-word "Build Cache" type
            else if ($1 == "Build" && $2 == "Cache") {
                # Print "Build Cache" as a single field
                printf "  %-12s %-8s %-8s %-12s %-12s\n", "Build Cache", $3, $4, $5, $6
            } 
            # For all other single-word types (Images, Containers)
            else {
                printf "  %-12s %-8s %-8s %-12s %-12s\n", $1, $2, $3, $4, $5
            }
        }'
    echo -e "${cyan}╰─────────────────────────────────────────────────────╯${no_col}"

    log_message "INFO" "Checking Docker and Compose versions"
    if ! timeout 2 curl -s https://api.github.com/repos/docker/compose/releases/latest >/dev/null 2>&1; then
        log_message "WARNING" "GitHub API unavailable, skipping version check"
        echo -e "${red}  Docker (apt) ver checker down right now .. continue${no_col}"
        echo -e "\n"
        return 0
    fi

    # Docker Compose version check
    CURRENT_COMPOSE_VERSION=$(docker compose version 2>/dev/null | grep "Docker Compose version" | awk '{print $4}' | cut -c 2- || echo "N/A")
    LATEST_COMPOSE_TAG=$(curl -s "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4 || echo "N/A")
    LATEST_COMPOSE_VERSION="${LATEST_COMPOSE_TAG#v}"

    # Docker Engine version check
    CURRENT_DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "N/A")
    LATEST_DOCKER_TAG=$(curl -s "https://api.github.com/repos/moby/moby/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4 || echo "N/A")
    LATEST_DOCKER_VERSION="${LATEST_DOCKER_TAG#v}"

    # Compare versions
    compare_versions() {
        local current="$1" latest="$2"
        if [[ "$current" == "N/A" || "$latest" == "N/A" ]]; then
            echo "unknown"
            return
        fi
        awk -v current="$current" -v latest="$latest" '
        BEGIN {
            split(current, cur_parts, ".")
            split(latest, lat_parts, ".")
            len = length(cur_parts) > length(lat_parts) ? length(cur_parts) : length(lat_parts)
            for (i = 1; i <= len; i++) {
                cur_part = (cur_parts[i] == "" ? 0 : cur_parts[i])
                lat_part = (lat_parts[i] == "" ? 0 : lat_parts[i])
                if (cur_part < lat_part) { print "newer"; exit }
                if (cur_part > lat_part) { print "older"; exit }
            }
            print "equal"
        }'
    }

    COMPOSE_UPDATE=$(compare_versions "$CURRENT_COMPOSE_VERSION" "$LATEST_COMPOSE_VERSION")
    DOCKER_UPDATE=$(compare_versions "$CURRENT_DOCKER_VERSION" "$LATEST_DOCKER_VERSION")

    UPDATE_NEEDED=0
    if [[ "$COMPOSE_UPDATE" == "newer" ]]; then
        log_message "INFO" "Newer Docker Compose version available: v$LATEST_COMPOSE_VERSION"
        echo -e "${yellow}  ✅ A newer version of Docker Compose is available (v$LATEST_COMPOSE_VERSION).${no_col}"
        UPDATE_NEEDED=1
    fi
    if [[ "$DOCKER_UPDATE" == "newer" ]]; then
        log_message "INFO" "Newer Docker Engine version available: v$LATEST_DOCKER_VERSION"
        echo -e "${yellow}  ✅ A newer version of Docker Engine is available (v$LATEST_DOCKER_VERSION).${no_col}"
        UPDATE_NEEDED=1
    fi
    if [[ "$UPDATE_NEEDED" -eq 0 ]]; then
        log_message "INFO" "Docker and Docker Compose are up to date"
        echo -e "${green}  ✅ Docker and Docker Compose are up to date 🐋.${no_col}"
        echo -e "\n"
    fi
    if [[ "$UPDATE_NEEDED" -eq 1 ]]; then
        echo -e "${magenta}  ✅ Run PRESTO_ENGINE_UPDATE to update Docker/Compose Engine.${no_col}"
        echo -e "\n"
    fi
}

ram_usage_bar() {
    if ! is_command free; then
        log_message "ERROR" "Command 'free' not found, skipping RAM usage"
        echo -e "${yellow}RAM usage unavailable${no_col}"
        return 1
    fi
    total_ram=$(free -m | awk '/Mem:/ {print $2}' 2>/dev/null)
    used_ram=$(free -m | awk '/Mem:/ {print $3}' 2>/dev/null)
    if [ -z "$total_ram" ] || [ -z "$used_ram" ]; then
        log_message "ERROR" "Failed to retrieve RAM usage"
        echo -e "${yellow}RAM usage unavailable${no_col}"
        return 1
    fi
    percentage=$((used_ram * 100 / total_ram))
    bar_length=14
    filled_length=$((percentage * bar_length / 100))
    empty_length=$((bar_length - filled_length))
    filled_bar=$(printf "%0.s▓" $(seq 1 $filled_length))
    empty_bar=$(printf "%0.s░" $(seq 1 $empty_length))
    if [ $percentage -lt 50 ]; then
        bar_color=${green}
    elif [ $percentage -lt 75 ]; then
        bar_color=${yellow}
    else
        bar_color=${red}
    fi
    echo -e "${bar_color}[$filled_bar${grey_dim}$empty_bar] $percentage%${no_col} ($used_ram MB / $total_ram MB)"
}

print_pi_drive_info() {
    if ! is_command lsblk || ! is_command df; then
        log_message "ERROR" "Command 'lsblk' or 'df' not found, skipping drive info"
        echo -e "${yellow}Drive info unavailable${no_col}"
        return 1
    fi
    check_disk_space || { log_message "ERROR" "Disk space check failed, skipping drive info"; echo -e "${yellow}Drive info unavailable${no_col}"; return 1; }
    log_message "INFO" "Displaying Raspberry Pi drive info"
    echo -e "${magenta}\n  PI 🍓Model: ${raspberry_model}${no_col}"
    max_drive_length=15
    max_label_length=5
    declare -A drive_labels
    while read -r device label; do
        drive_labels["$device"]="$label"
        label_length=${#label}
        if [ $label_length -gt $max_label_length ]; then
            max_label_length=$label_length
        fi
    done < <(lsblk -n -o NAME,LABEL -l 2>/dev/null | grep -v '^$' | while read -r name label; do
        if [[ -n "$label" ]]; then
            echo "/dev/$name $label"
        else
            echo "/dev/$name -"
        fi
    done)
    total_line_length=$((max_drive_length + 6 + 6 + 6 + 5 + max_label_length + 7))
    separator=$(printf '%*s' "$total_line_length" '' | tr ' ' '-')
    echo -e "  ${magenta}${separator}${no_col}"
    printf "  ${grey}%-${max_drive_length}s %6s %6s %6s %5s %-${max_label_length}s${no_col}\n" "DRIVE" "HDSIZE" "USED" "FREE" "USE%" "LABEL"
    df -h --output=source,size,used,avail,pcent 2>/dev/null | grep "^/dev/" | while read -r line; do
        drive=$(echo "$line" | awk '{print $1}')
        hdsize=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        free=$(echo "$line" | awk '{print $4}')
        usep=$(echo "$line" | awk '{print $5}' | tr -d '%')
        label="${drive_labels[$drive]:--}"
        local color
        if [ "$usep" -lt 40 ]; then
            color=$green
        elif [ "$usep" -le 65 ]; then
            color=$yellow
        else
            color=$red
        fi
        printf "  ${color}%-${max_drive_length}s %6s %6s %6s %5s %-${max_label_length}s${no_col}\n" "$drive" "$hdsize" "$used" "$free" "$usep%" "$label"
    done
    echo -e ""
}

# Trap errors (log but don't disrupt login)
trap 'log_message "ERROR" "Error occurred at line $LINENO: exit code $?"' ERR

# System info variables
cpu_temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
gpu_temp=$(vcgencmd measure_temp 2>/dev/null | awk '{split($0,numbers,"=")} {print numbers[2]}' || echo "N/A")
internal_ip=$(hostname -I 2>/dev/null | awk '{print $1, $2, $3}' || echo "N/A")
external_ip=$(curl -s https://ipv4.icanhazip.com 2>/dev/null || echo "N/A")
timezone=$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3$4$5}' || echo "UTC")
date_full=$(date +"%A, %d %B %Y,%H:%M:%S $timezone" 2>/dev/null || echo "N/A")
os=$(lsb_release -d -r -c 2>/dev/null | awk -F: '{split($2,a," "); printf a[1]" "  }'; uname -s -m || echo "N/A")
uptime=$(uptime -p 2>/dev/null || echo "N/A")
memory_usage=$(ram_usage_bar)
running_processes=$(ps aux 2>/dev/null | wc -l || echo "N/A")
raspberry_model=$(cat /proc/device-tree/compatible 2>/dev/null | awk -v RS='\0' 'NR==1' || echo "N/A")

# Display system info
if [ "$show_docker_info" -eq 1 ]; then
    print_docker_status
else
    log_message "INFO" "Docker status display skipped as per user preference"
    if [ "$VERBOSE_MODE" -eq 1 ]; then
        echo -e "\n  ${grey_dim}Docker status display skipped as per user preference.${no_col}"
    fi
fi

if [ "$show_smartdrive_info" -eq 1 ]; then
    if [ -f "$USER_HOME/presto-tools/scripts/presto_drive_status.sh" ]; then
        log_message "INFO" "Running presto_drive_status.sh for SMART drive info"
        # Check if sudo is configured for passwordless execution
        if sudo -n true 2>/dev/null; then
            drive_report=$(sudo "$USER_HOME/presto-tools/scripts/presto_drive_status.sh" 2>/dev/null || echo -e "${yellow}Failed to run presto_drive_status.sh${no_col}")
            echo "$drive_report"
        else
            log_message "ERROR" "sudo requires password, skipping presto_drive_status.sh"
            echo -e "\n  ${yellow}SMART drive info unavailable (sudo requires password)${no_col}"
        fi
    else
        log_message "ERROR" "presto_drive_status.sh not found"
        echo -e "\n  ${yellow}SMART drive info unavailable${no_col}"
    fi
else
    log_message "INFO" "SMART drive info display skipped as per user preference"
    if [ "$VERBOSE_MODE" -eq 1 ]; then
        echo -e "\n  ${grey_dim}Drive smart information display skipped by user preference.${no_col}"
    fi
fi

if [ "$show_drive_info" -eq 1 ]; then
    print_pi_drive_info
else
    log_message "INFO" "Drive info display skipped as per user preference"
    if [ "$VERBOSE_MODE" -eq 1 ]; then
        echo -e "\n  ${grey_dim}Drive blkid information display skipped by user preference.${no_col}"
    fi
fi

#START OF FINAL INFO BLOCK EMOJI -----------------------------
# Extract the first part of the date (up to the time)
date_part=$(echo "$date_full" | cut -d' ' -f1-4 | sed 's/,$//')

# Extract the second part (timezone)
timezone_part=$(echo "$date_full" | cut -d' ' -f5-)

#start of date + OS SYS block emoji block  
printf "  %-3s ${cyan}%-13s${no_col} ${yellow}%s\n" "Operating System:" "${os}"

# Print the first line with the date and time
printf " %-3s ${white}%-13s${no_col}  %s\n" " ${calendar}" "Date:" "${date_part}"

# Print the second line with the timezone, indented
printf "%s%s\n" "$(printf '%*s' 22)" "${timezone_part}"

fan_input_path=$(find /sys/devices/platform/ -name "fan1_input" 2>/dev/null)
if [[ -n "$fan_input_path" ]]; then
    fan_speed=$(cat "$fan_input_path" 2>/dev/null || echo "0")
    if [[ "$fan_speed" -gt 1000 ]]; then
        printf "  %-3s ${green}%-13s${no_col} ${green}%s\n" "${fan}" "Fan is on" "${fan}${fan_speed} RPM"
    else
        printf "  %-3s ${grey}%-13s${no_col} ${grey}%s\n" "${fan}" "Fan is off" "${fan}${fan_speed} RPM"
    fi
else
    printf "  %-3s ${yellow}%-13s${no_col} \n" "${fan}" "No Fan Detected"
fi

if [[ "$((cpu_temp/1000))" -lt 50 ]]; then 
    printf "  %-3s ${cyan}%-13s${no_col} ${green}%d°C\n" "${laptop}" "CPU Temp:" "$((cpu_temp/1000))"
    printf "  %-3s ${cyan}%-13s${no_col} ${green}%s\n" "${gpu}" "GPU Temp:" "$gpu_temp"
elif [[ "$((cpu_temp/1000))" -lt 62 ]]; then
    printf "  %-3s ${cyan}%-13s${no_col} ${yellow}%d°C\n" "${laptop}" "CPU Temp:" "$((cpu_temp/1000))"
    printf "  %-3s ${cyan}%-13s${no_col} ${yellow}%s\n" "${gpu}" "GPU Temp:" "$gpu_temp"
else
    printf "  %-3s ${cyan}%-13s${no_col} ${red}%d°C\n" "${laptop}" "CPU Temp:" "$((cpu_temp/1000))"
    printf "  %-3s ${cyan}%-13s${no_col} ${red}%s\n" "${gpu}" "GPU Temp:" "$gpu_temp"
fi

printf "  %-3s ${blue}%-13s${no_col} ${blue}${no_col}%s\n" "${house}" "Internal IP:" "$internal_ip"
printf "  %-3s ${magenta_dim}%-13s${no_col} %s\n" "${globe}" "External IP:" "$external_ip"
printf "  %-3s ${yellow}%-15s${no_col} ${yellow}%s\n" "${clock}" "Uptime┐" "$uptime"
printf "  %-3s ${yellow}%-13s${no_col} %s\n" "${timer}" "  Processes:" "$running_processes"
printf "  %-3s ${green}%-13s${no_col} %s\n" "${ram}" "  RAM Usage:" "$memory_usage"
printf "  %-3s ${white}%-13s${no_col} %s\n" "${weather}" "Weather:" "$weather_info"
echo -e "\n"
echo -e "   Hello $USER ◕ ‿ ◕ "

# Clear trap
trap - ERR