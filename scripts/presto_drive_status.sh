#!/bin/bash

#  __/\\\\\\\\\\\\\______/\\\\\\\\\______/\\\\\\\\\\\\\\\_____/\\\\\\\\\\\____/\\\\\\\\\\\\\\\_______/\\\\\______        
#   _\/\\\/////////\\\__/\\\///////\\\___\/\\\///////////____/\\\/////////\\\_\///////\\\/////______/\\\///\\\____       
#    _\/\\\_______\/\\\_\/\\\_____\/\\\___\/\\\______________\//\\\______\///________\/\\\_________/\\\/__\///\\\__      
#     _\/\\\\\\\\\\\\\/__\/\\\\\\\\\\\/____\/\\\\\\\\\\\_______\////\\\_______________\/\\\________/\\\______\//\\\_     
#      _\/\\\/////////____\/\\\//////\\\____\/\\\///////___________\////\\\____________\/\\\_______\/\\\_______\/\\\_    
#       _\/\\\_____________\/\\\____\//\\\___\/\\\_____________________\////\\\_________\/\\\_______\//\\\______/\\\__   
#        _\/\\\_____________\/\\\_____\//\\\__\/\\\______________/\\\______\//\\\________\/\\\________\///\\\__/\\\____  
#         _\/\\\_____________\/\\\______\//\\\_\/\\\\\\\\\\\\\\\_\///\\\\\\\\\\\/_________\/\\\__________\///\\\\\/_____ 
#          _\///______________\///________\///__\///////////////____\///////////___________\///_____________\/////_______  


# Version         : v1.0.0
# Author          : pixelpiklz
# GitHub          : github/piklz
#
# Summary         : A comprehensive tool to monitor disk health and usage on Linux systems. 
#                   It leverages smartctl for SMART status and lsblk for disk and partition details, 
#                   offering multiple output formats for different use cases.
#
# Changes (v1.0.0): Refactored the --simple output to correctly display the SMART status for all partitions on 
#                   a physical drive, instead of just the first partition. All partitions now inherit the 
#                   health status of their parent disk.

# --- Help Function ---
display_help() {
    echo "Usage: sudo ./drive_smart_status.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help                  Display this help message and exit."
    echo "  --moreinfo              Display detailed output with drive and partition information."
    echo "  --simple                Output a simple, single-line SMART status for each physical drive (e.g., label=✅)."
    echo "  --device <DEVICE>       Check a single device specified by its path (e.g., /dev/sda1) or label (e.g., Seagate2TB)."
    echo "  --all-partitions        Check all partitions, including unmounted ones. Usage will show as N/A for unmounted."
    echo ""
    echo "Examples:"
    echo "  sudo ./drive_smart_status.sh"
    echo "  sudo ./drive_smart_status.sh --moreinfo"
    echo "  sudo ./drive_smart_status.sh --simple"
    echo "  sudo ./drive_smart_status.sh --device /dev/sdb1"
    echo "  sudo ./drive_smart_status.sh --all-partitions"
    exit 0
}

# --- Main Script ---

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "This script requires root privileges to access hardware devices."
  echo "Please run with sudo: sudo ./drive_smart_status.sh"
  exit 1
fi

# Check if smartctl is installed, and if not, instruct the user.
if ! command -v smartctl &> /dev/null; then
    echo "Error: smartctl is not installed. Please install it to check drive health."
    echo "To install, run: sudo apt install smartmontools"
    exit 1
fi

# Set output mode and manual device check
OUTPUT_MODE="simple_full"
CHECK_ALL_PARTITIONS="false"
MANUAL_DEVICE=""

while (( "$#" )); do
  case "$1" in
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
        echo "Error: --device requires an argument (e.g., /dev/sda1 or a label)."
        exit 1
      fi
      ;;
    --all-partitions)
      CHECK_ALL_PARTITIONS="true"
      shift
      ;;
    *)
      echo "Error: Invalid argument '$1'."
      echo "Use --help for a list of available options."
      exit 1
      ;;
  esac
done

# --- Core Logic Functions ---

# Function to get SMART status for a physical drive
get_smart_status() {
    local device_path=$1
    local status_emoji="❓"
    
    # List of common device types to try
    local device_types=("ata" "scsi" "sat" "usbsg")
    
    # Iterate through device types to find a working one
    for type in "${device_types[@]}"; do
        local smart_output
        smart_output=$(smartctl -d "$type" --health "$device_path" 2>&1)

        if echo "$smart_output" | grep -q "SMART Health Status: OK"; then
            status_emoji="✅"
            break
        elif echo "$smart_output" | grep -q "SMART Health Status: FAILED"; then
            status_emoji="⚠️"
            break
        fi
    done
    
    echo "$status_emoji"
}

# Function to truncate a long label with an ellipsis
truncate_label() {
    local label="$1"
    local max_len=12
    if [ ${#label} -gt $max_len ]; then
        # Take 5 chars from the start, 4 from the end, and add "..."
        local start_chars=${label:0:5}
        local end_chars=${label: -4}
        echo "${start_chars}...${end_chars}"
    else
        echo "$label"
    fi
}

# --- Output Functions ---

display_full_report() {
    declare -A smart_statuses
    local drives=$(lsblk -d -n -o KNAME | grep -E 'sd[a-z]|nvme')

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
            local df_output=$(df -hP "$mountpoint" | awk 'NR==2 {print $2, $5}')
            total_size=$(echo "$df_output" | awk '{print $1}')
            usage_percent=$(echo "$df_output" | awk '{print $2}' | sed 's/%//')
        fi
        
        local bar_color='\033[0m'
        if [ -n "$usage_percent" ] && [ "$usage_percent" != "N/A" ]; then
            bar_color='\033[0;32m'
            if [ "$usage_percent" -gt 80 ]; then bar_color='\033[0;31m';
            elif [ "$usage_percent" -gt 20 ]; then bar_color='\033[0;33m'; fi
        fi
        local reset_color='\033[0m'
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

        echo -e "│   $(printf "%-18s" "(${kname: -1}) $output_label") Used: ${bar_color}[${bar_text}]${usage_percent}%${reset_color} ($(printf "%s" "$total_size"))"
    done < <(lsblk -n -o KNAME,PKNAME,MOUNTPOINT,LABEL | grep -E 'sd[a-z][0-9]|nvme')

    echo "╰─────────────────────────────────────────────────────╯"
}

display_simple_full_report() {
    declare -A smart_statuses
    local drives=$(lsblk -d -n -o KNAME | grep -E 'sd[a-z]|nvme')

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
            local df_output=$(df -hP "$mountpoint" | awk 'NR==2 {print $2, $5}')
            total_size=$(echo "$df_output" | awk '{print $1}')
            usage_percent=$(echo "$df_output" | awk '{print $2}' | sed 's/%//')
        fi

        local bar_color='\033[0m'
        if [ -n "$usage_percent" ] && [ "$usage_percent" != "N/A" ]; then
            bar_color='\033[0;32m'
            if [ "$usage_percent" -gt 80 ]; then bar_color='\033[0;31m';
            elif [ "$usage_percent" -gt 20 ]; then bar_color='\033[0;33m'; fi
        fi
        local reset_color='\033[0m'
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

        echo -e "│ $(printf "%-15s" "$output_label") Status: $status_emoji %: ${bar_color}[${bar_text}]${usage_percent}%${reset_color} ($(printf "%s" "$total_size"))"
    done < <(lsblk -n -o KNAME,PKNAME,MOUNTPOINT,LABEL | grep -E 'sd[a-z][0-9]|nvme')

    echo "╰─────────────────────────────────────────────────────╯"
}

display_simple_report() {
    # Cache SMART statuses for physical drives to avoid redundant smartctl calls
    declare -A smart_statuses
    local physical_drives=$(lsblk -d -n -o KNAME | grep -E 'sd[a-z]|nvme')
    for drive in $physical_drives; do
        smart_statuses["$drive"]=$(get_smart_status "/dev/$drive")
    done

    # Iterate over all partitions, not just the first one
    while read -r kname pkname label; do
        # We only want to process partitions, not full disks, and ensure they have a parent disk
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
    done < <(lsblk -n -o KNAME,PKNAME,LABEL | grep -E 'sd[a-z][0-9]|nvme')
}

display_single_device_full() {
    local PARTITION_PATH=$1
    local MOUNTPOINT=$2
    local parent_disk=$(lsblk -n -o PKNAME "$PARTITION_PATH" | xargs)
    local smart_status=$(get_smart_status "/dev/$parent_disk")
    
    echo "╭─── Drive Health & Usage Monitor ─────────PRESTO────╮"
    echo -e "│ [$(printf "%-3s" "$parent_disk")]-Status: $smart_status"

    local total_size="N/A"
    local usage_percent="N/A"
    if [ -n "$MOUNTPOINT" ]; then
        local df_output=$(df -hP "$MOUNTPOINT" | awk 'NR==2 {print $2, $5}')
        total_size=$(echo "$df_output" | awk '{print $1}')
        usage_percent=$(echo "$df_output" | awk '{print $2}' | sed 's/%//')
    fi

    local bar_color='\033[0m'
    if [ -n "$usage_percent" ] && [ "$usage_percent" != "N/A" ]; then
        bar_color='\033[0;32m'
        if [ "$usage_percent" -gt 80 ]; then bar_color='\033[0;31m';
        elif [ "$usage_percent" -gt 20 ]; then bar_color='\033[0;33m'; fi
    fi
    local reset_color='\033[0m'
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
    echo -e "│   $(printf "%-18s" "(${PARTITION_PATH: -1}) $output_label") Used: ${bar_color}[${bar_text}]${usage_percent}%${reset_color} ($(printf "%s" "$total_size"))"
    echo "╰────────────────────────────────────────────────────╯"
}

display_single_device_simple() {
    local PARTITION_PATH=$1
    local parent_disk=$(lsblk -n -o PKNAME "$PARTITION_PATH" | xargs)
    local status=$(get_smart_status "/dev/$parent_disk")
    local label=$(blkid -s LABEL -o value "$PARTITION_PATH" 2>/dev/null || echo "$parent_disk")
    echo "$label=$status"
}


# --- Main Execution Block ---

if [ -n "$MANUAL_DEVICE" ]; then
    PARTITION_PATH=$(blkid -L "$MANUAL_DEVICE" 2>/dev/null || echo "$MANUAL_DEVICE")
    
    if [ -b "$PARTITION_PATH" ]; then
        MOUNTPOINT=$(lsblk -n -o MOUNTPOINT "$PARTITION_PATH" | xargs)

        if [ "$OUTPUT_MODE" == "full" ]; then
            display_single_device_full "$PARTITION_PATH" "$MOUNTPOINT"
        else
            display_single_device_simple "$PARTITION_PATH"
        fi
    else
        echo "Error: Device '$MANUAL_DEVICE' not found. Please provide a valid device path or label."
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