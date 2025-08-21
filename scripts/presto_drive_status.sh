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

#-------------------------------------------------------------------------------------------------
# presto_drive_status.sh - Monitor disk health and usage on Linux systems
# Version: 1.0.5
# Author: piklz
# GitHub: https://github.com/piklz/presto-tools.git
# Web: https://github.com/piklz/presto-tools.git
# Description:
#   Monitors disk health using smartctl and usage with lsblk/df, with multiple output formats (simple, full, single device).
#   Customizable via a configuration file. Logs to systemd-journald, with rotation managed by journald.
#
# Changelog:
#   Version 1.0.5 (2025-08-21):
#     - Removed unused file-based logging variables (LOG_DIR, LOG_FILE), directory/file creation code, and LOG_RETENTION_DAYS from configuration.
#   Version 1.0.4 (2025-08-21):
#     - Added script version to --help output and journal tip for viewing logs.
#   Version 1.0.3 (2025-08-07):
#     - Fixed permissions for log directory/file, improved sudo handling.
#   Version 1.0.2 (2025-07-15):
#     - Replaced file-based logging with systemd-cat journal logging.
#
# Usage:
#   Run the script with sudo: `sudo ./presto_drive_status.sh [OPTIONS]`
#   - Options include --help, --moreinfo, --simple, --device, --all-partitions, and -d for debug logging.
#   - Customize display options (e.g., CHECK_DISK_SPACE, DEFAULT_OUTPUT_MODE) by editing
#     `$HOME/presto-tools/scripts/presto_config.local`. (Copy presto_config.defaults to presto_config.local and edit.)
#   - Logs can be viewed with: `journalctl -t presto_drive_status -n 10`.
#   - Ensure dependencies (smartctl, lsblk, df, blkid) are installed for full functionality.
#-------------------------------------------------------------------------------------------------

# Set default variables
presto_VERSION='1.0.5'
VERBOSE_MODE=0
DEFAULT_OUTPUT_MODE="simple_full"

# Color variables (aligned with presto_bashwelcome.sh)
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

# Debug flag (default: disabled)
DEBUG_ENABLED=0

# Log message function
log_message() {
    local log_level="$1"
    local console_message="$2"
    local log_file_message="${3:-$console_message}"
    local exit_on_error="${4:-true}" # Default to true if not specified

    # Skip debug messages if debug is not enabled
    if [ "$log_level" = "DEBUG" ] && [ "$DEBUG_ENABLED" -eq 0 ]; then
        return
    fi

    # Format timestamp
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local journal_message="[$timestamp] [presto_drive_status] [$log_level] $log_file_message"

    # Map log level to systemd priority
    case "${log_level,,}" in
        debug) priority="debug" ;;
        info) priority="info" ;;
        warning) priority="warning" ;;
        error) priority="err" ;;
        *) priority="info" ;;
    esac

    # Log to journald using systemd-cat
    if ! systemd-cat -t presto_drive_status -p "$priority" <<< "$journal_message"; then
        echo "[presto_drive_status] [ERROR] Failed to log to journald" >&2
    fi

    # Print to console only for specific ERROR messages
    if [ "$log_level" = "ERROR" ] && [[ "$console_message" =~ "not found" || "$console_message" =~ "unavailable" || "$console_message" =~ "requires root privileges" ]]; then
        echo -e "${yellow}${console_message}${no_col}"
    fi

    # Exit on error if specified
    if [ "$log_level" = "ERROR" ] && [ "$exit_on_error" = "true" ]; then
        exit 1
    fi
}

# Determine real user's home directory
USER_HOME=""
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    USER="$SUDO_USER"
else
    USER_HOME="$HOME"
    USER="$(id -un)"
fi

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
    mkdir -p "$USER_HOME/presto-tools/scripts" || { log_message "ERROR" "Failed to create directory for $DEFAULT_CONFIG"; echo "Error: Could not create directory for $DEFAULT_CONFIG" >&2; exit 1; }
    cat << EOF > "$DEFAULT_CONFIG"
# Presto default configuration
show_docker_info=1
show_smartdrive_info=0
show_drive_info=1
VERBOSE_MODE=0
log_level="INFO"
CHECK_DISK_SPACE=1
WEATHER_LOCATION="London"
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

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    log_message "ERROR" "This script requires root privileges to access hardware devices"
    echo "This script requires root privileges to access hardware devices."
    echo "Please run with sudo: sudo ./presto_drive_status.sh"
    exit 1
fi

# Check for required commands
for cmd in smartctl lsblk df blkid; do
    if ! command -v "$cmd" &> /dev/null; then
        log_message "ERROR" "Command '$cmd' is not installed, required for drive health checks"
        echo "Error: $cmd is not installed. Please install it to check drive health."
        echo "To install, run: sudo apt install smartmontools util-linux"
        exit 1
    fi
done

# Help function (defined before argument parsing)
display_help() {
    echo "presto_drive_status.sh (v${presto_VERSION})"
    echo ""
    echo "Usage: sudo ./presto_drive_status.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help                  Display this help message and exit."
    echo "  --moreinfo              Display detailed output with drive and partition information."
    echo "  --simple                Output a simple, single-line SMART status for each physical drive (e.g., label=✅)."
    echo "  --device <DEVICE>       Check a single device specified by its path (e.g., /dev/sda1) or label (e.g., Seagate2TB)."
    echo "  --all-partitions        Check all partitions, including unmounted ones. Usage will show as N/A for unmounted."
    echo ""
    echo "Examples:"
    echo "  sudo ./presto_drive_status.sh"
    echo "  sudo ./presto_drive_status.sh --moreinfo"
    echo "  sudo ./presto_drive_status.sh --simple"
    echo "  sudo ./presto_drive_status.sh --device /dev/sdb1"
    echo "  sudo ./presto_drive_status.sh --all-partitions"
    echo ""
    echo "To see info or warning logs type:"
    echo "     journalctl -t presto_drive_status -n 10"
    exit 0
}

# Set output mode and manual device check
OUTPUT_MODE="$DEFAULT_OUTPUT_MODE"
CHECK_ALL_PARTITIONS="false"
MANUAL_DEVICE=""

while (( "$#" )); do
    case "$1" in
        -d)
            DEBUG_ENABLED=1
            shift
            ;;
        --help)
            display_help
            ;;
        --simple)
            OUTPUT_MODE="simple"
            shift
            ;;
        --moreinfo)
            OUTPUT_MODE="full"
            shift
            ;;
        --device)
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                MANUAL_DEVICE="$2"
                shift 2
            else
                log_message "ERROR" "Option --device requires an argument (e.g., /dev/sda1 or a label)"
                echo "Error: --device requires an argument (e.g., /dev/sda1 or a label)."
                exit 1
            fi
            ;;
        --all-partitions)
            CHECK_ALL_PARTITIONS="true"
            shift
            ;;
        *)
            log_message "ERROR" "Invalid argument '$1'"
            echo "Error: Invalid argument '$1'."
            echo "Use --help for a list of available options."
            exit 1
            ;;
    esac
done

# Function to get SMART status for a physical drive
get_smart_status() {
    local device_path=$1
    local status_emoji="❓"
    local device_types=("ata" "scsi" "sat" "usbsg")
    
    for type in "${device_types[@]}"; do
        log_message "INFO" "Checking SMART status for $device_path with device type $type"
        local smart_output
        smart_output=$(smartctl -d "$type" --health "$device_path" 2>&1)
        if echo "$smart_output" | grep -q "SMART Health Status: OK"; then
            log_message "INFO" "SMART status OK for $device_path (type: $type)"
            status_emoji="✅"
            break
        elif echo "$smart_output" | grep -q "SMART Health Status: FAILED"; then
            log_message "WARNING" "SMART status FAILED for $device_path (type: $type)" "" "false"
            status_emoji="⚠️"
            break
        fi
    done
    if [ "$status_emoji" = "❓" ]; then
        log_message "WARNING" "Unable to determine SMART status for $device_path" "" "false"
    fi
    echo "$status_emoji"
}

# Function to truncate a long label with an ellipsis
truncate_label() {
    local label="$1"
    local max_len=12
    if [ ${#label} -gt $max_len ]; then
        local start_chars=${label:0:5}
        local end_chars=${label: -4}
        echo "${start_chars}...${end_chars}"
    else
        echo "$label"
    fi
}

# Output functions
display_full_report() {
    check_disk_space || { log_message "ERROR" "Disk space check failed, skipping report"; echo -e "${yellow}Drive info unavailable${no_col}"; return 1; }
    log_message "INFO" "Generating full report"
    declare -A smart_statuses
    local drives=$(lsblk -d -n -o KNAME 2>/dev/null | grep -E 'sd[a-z]|nvme' || echo "")
    if [ -z "$drives" ]; then
        log_message "ERROR" "No drives found"
        echo -e "${yellow}No drives found${no_col}"
        return 1
    fi

    for drive in $drives; do
        smart_statuses["$drive"]=$(get_smart_status "/dev/$drive")
    done

    echo "╭─── Drive Health & Usage Monitor ─────────PRESTO─────╮"
    local current_parent_disk=""

    while read -r kname pkname mountpoint label; do
        if [ "$pkname" != "$current_parent_disk" ]; then
            if [ -n "$current_parent_disk" ]; then
                echo "│"
            fi
            current_parent_disk="$pkname"
            local status_emoji="${smart_statuses[$pkname]}"
            echo -e "│ [$(printf "%-3s" "$pkname")]-Status: $status_emoji"
        fi

        if [ -z "$mountpoint" ] && [ "$CHECK_ALL_PARTITIONS" != "true" ]; then
            continue
        fi

        local total_size="N/A"
        local usage_percent="N/A"
        if [ -n "$mountpoint" ]; then
            local df_output=$(df -hP "$mountpoint" 2>/dev/null | awk 'NR==2 {print $2, $5}')
            total_size=$(echo "$df_output" | awk '{print $1}')
            usage_percent=$(echo "$df_output" | awk '{print $2}' | sed 's/%//')
        fi
        
        local bar_color="$no_col"
        if [ -n "$usage_percent" ] && [ "$usage_percent" != "N/A" ]; then
            bar_color="$green"
            if [ "$usage_percent" -gt 80 ]; then bar_color="$red";
            elif [ "$usage_percent" -gt 20 ]; then bar_color="$yellow"; fi
        fi
        local bar_text="          "
        if [ -n "$usage_percent" ] && [ "$usage_percent" != "N/A" ]; then
            local num_blocks=$((usage_percent / 10))
            local num_spaces=$((10 - num_blocks))
            bar_text=""
            for ((i=0; i<num_blocks; i++)); do bar_text="${bar_text}▇"; done
            for ((i=0; i<num_spaces; i++)); do bar_text="${bar_text} "; done
        fi

        local output_label=""
        if [ -n "$label" ]; then
            output_label="$(truncate_label "$label")"
        else
            output_label="$kname"
        fi

        echo -e "│   $(printf "%-18s" "(${kname: -1}) $output_label") Used: ${bar_color}[${bar_text}]${usage_percent}%${no_col} ($(printf "%s" "$total_size"))"
    done < <(lsblk -n -o KNAME,PKNAME,MOUNTPOINT,LABEL 2>/dev/null | grep -E 'sd[a-z][0-9]|nvme' || echo "")
    echo "╰─────────────────────────────────────────────────────╯"
}

display_simple_full_report() {
    check_disk_space || { log_message "ERROR" "Disk space check failed, skipping report"; echo -e "${yellow}Drive info unavailable${no_col}"; return 1; }
    log_message "INFO" "Generating simple full report"
    declare -A smart_statuses
    local drives=$(lsblk -d -n -o KNAME 2>/dev/null | grep -E 'sd[a-z]|nvme' || echo "")
    if [ -z "$drives" ]; then
        log_message "ERROR" "No drives found"
        echo -e "${yellow}No drives found${no_col}"
        return 1
    fi

    for drive in $drives; do
        smart_statuses["$drive"]=$(get_smart_status "/dev/$drive")
    done

    echo "╭─── Drive Health & Usage Monitor ─────────PRESTO─────╮"

    while read -r kname pkname mountpoint label; do
        if [ -z "$mountpoint" ] && [ "$CHECK_ALL_PARTITIONS" != "true" ]; then
            continue
        fi

        local total_size="N/A"
        local usage_percent="N/A"
        if [ -n "$mountpoint" ]; then
            local df_output=$(df -hP "$mountpoint" 2>/dev/null | awk 'NR==2 {print $2, $5}')
            total_size=$(echo "$df_output" | awk '{print $1}')
            usage_percent=$(echo "$df_output" | awk '{print $2}' | sed 's/%//')
        fi

        local bar_color="$no_col"
        if [ -n "$usage_percent" ] && [ "$usage_percent" != "N/A" ]; then
            bar_color="$green"
            if [ "$usage_percent" -gt 80 ]; then bar_color="$red";
            elif [ "$usage_percent" -gt 20 ]; then bar_color="$yellow"; fi
        fi
        local bar_text="          "
        if [ -n "$usage_percent" ] && [ "$usage_percent" != "N/A" ]; then
            local num_blocks=$((usage_percent / 10))
            local num_spaces=$((10 - num_blocks))
            bar_text=""
            for ((i=0; i<num_blocks; i++)); do bar_text="${bar_text}▇"; done
            for ((i=0; i<num_spaces; i++)); do bar_text="${bar_text} "; done
        fi

        local output_label=""
        if [ -n "$label" ]; then
            output_label="$(truncate_label "$label")"
        else
            output_label="$kname"
        fi

        local parent_disk="$pkname"
        local status_emoji="${smart_statuses[$parent_disk]}"

        echo -e "│ $(printf "%-15s" "$output_label") Status: $status_emoji %: ${bar_color}[${bar_text}]${usage_percent}%${no_col} ($(printf "%s" "$total_size"))"
    done < <(lsblk -n -o KNAME,PKNAME,MOUNTPOINT,LABEL 2>/dev/null | grep -E 'sd[a-z][0-9]|nvme' || echo "")
    echo "╰─────────────────────────────────────────────────────╯"
}

display_simple_report() {
    check_disk_space || { log_message "ERROR" "Disk space check failed, skipping report"; echo -e "${yellow}Drive info unavailable${no_col}"; return 1; }
    log_message "INFO" "Generating simple report"
    declare -A smart_statuses
    local physical_drives=$(lsblk -d -n -o KNAME 2>/dev/null | grep -E 'sd[a-z]|nvme' || echo "")
    if [ -z "$physical_drives" ]; then
        log_message "ERROR" "No drives found"
        echo -e "${yellow}No drives found${no_col}"
        return 1
    fi

    for drive in $physical_drives; do
        smart_statuses["$drive"]=$(get_smart_status "/dev/$drive")
    done

    while read -r kname pkname label; do
        if [[ "$kname" =~ [0-9]$ ]] && [ -n "$pkname" ]; then
            local status="${smart_statuses[$pkname]}"
            local output_label=""
            if [ -n "$label" ]; then
                output_label="$label"
            else
                output_label="$kname"
            fi
            echo "$output_label=$status"
        fi
    done < <(lsblk -n -o KNAME,PKNAME,LABEL 2>/dev/null | grep -E 'sd[a-z][0-9]|nvme' || echo "")
}

display_single_device_full() {
    local PARTITION_PATH=$1
    local MOUNTPOINT=$2
    check_disk_space || { log_message "ERROR" "Disk space check failed, skipping report"; echo -e "${yellow}Drive info unavailable${no_col}"; return 1; }
    log_message "INFO" "Generating full report for single device $PARTITION_PATH"
    local parent_disk=$(lsblk -n -o PKNAME "$PARTITION_PATH" 2>/dev/null | xargs)
    if [ -z "$parent_disk" ]; then
        log_message "ERROR" "No parent disk found for $PARTITION_PATH"
        echo -e "${yellow}No parent disk found for $PARTITION_PATH${no_col}"
        return 1
    fi
    local smart_status=$(get_smart_status "/dev/$parent_disk")
    
    echo "╭─── Drive Health & Usage Monitor ─────────PRESTO────╮"
    echo -e "│ [$(printf "%-3s" "$parent_disk")]-Status: $smart_status"

    local total_size="N/A"
    local usage_percent="N/A"
    if [ -n "$MOUNTPOINT" ]; then
        local df_output=$(df -hP "$MOUNTPOINT" 2>/dev/null | awk 'NR==2 {print $2, $5}')
        total_size=$(echo "$df_output" | awk '{print $1}')
        usage_percent=$(echo "$df_output" | awk '{print $2}' | sed 's/%//')
    fi

    local bar_color="$no_col"
    if [ -n "$usage_percent" ] && [ "$usage_percent" != "N/A" ]; then
        bar_color="$green"
        if [ "$usage_percent" -gt 80 ]; then bar_color="$red";
        elif [ "$usage_percent" -gt 20 ]; then bar_color="$yellow"; fi
    fi
    local bar_text="          "
    if [ -n "$usage_percent" ] && [ "$usage_percent" != "N/A" ]; then
        local num_blocks=$((usage_percent / 10))
        local num_spaces=$((10 - num_blocks))
        bar_text=""
        for ((i=0; i<num_blocks; i++)); do bar_text="${bar_text}▇"; done
        for ((i=0; i<num_spaces; i++)); do bar_text="${bar_text} "; done
    fi

    local label=$(blkid -s LABEL -o value "$PARTITION_PATH" 2>/dev/null || echo "$PARTITION_PATH")
    local output_label=$(truncate_label "$label")
    echo -e "│   $(printf "%-18s" "(${PARTITION_PATH: -1}) $output_label") Used: ${bar_color}[${bar_text}]${usage_percent}%${no_col} ($(printf "%s" "$total_size"))"
    echo "╰────────────────────────────────────────────────────╯"
}

display_single_device_simple() {
    local PARTITION_PATH=$1
    check_disk_space || { log_message "ERROR" "Disk space check failed, skipping report"; echo -e "${yellow}Drive info unavailable${no_col}"; return 1; }
    log_message "INFO" "Generating simple report for single device $PARTITION_PATH"
    local parent_disk=$(lsblk -n -o PKNAME "$PARTITION_PATH" 2>/dev/null | xargs)
    if [ -z "$parent_disk" ]; then
        log_message "ERROR" "No parent disk found for $PARTITION_PATH"
        echo -e "${yellow}No parent disk found for $PARTITION_PATH${no_col}"
        return 1
    fi
    local status=$(get_smart_status "/dev/$parent_disk")
    local label=$(blkid -s LABEL -o value "$PARTITION_PATH" 2>/dev/null || echo "$PARTITION_PATH")
    echo "$label=$status"
}

# Main execution block
if [ -n "$MANUAL_DEVICE" ]; then
    log_message "INFO" "Checking single device $MANUAL_DEVICE"
    PARTITION_PATH=$(blkid -L "$MANUAL_DEVICE" 2>/dev/null || echo "$MANUAL_DEVICE")
    if [ -b "$PARTITION_PATH" ]; then
        MOUNTPOINT=$(lsblk -n -o MOUNTPOINT "$PARTITION_PATH" 2>/dev/null | xargs)
        if [ "$OUTPUT_MODE" == "full" ]; then
            display_single_device_full "$PARTITION_PATH" "$MOUNTPOINT"
        else
            display_single_device_simple "$PARTITION_PATH"
        fi
    else
        log_message "ERROR" "Device '$MANUAL_DEVICE' not found"
        echo -e "${yellow}Error: Device '$MANUAL_DEVICE' not found. Please provide a valid device path or label.${no_col}"
        exit 1
    fi
else
    case "$OUTPUT_MODE" in
        "simple_full")
            display_simple_full_report
            ;;
        "full")
            display_full_report
            ;;
        "simple")
            display_simple_report
            ;;
    esac
fi