#!/bin/bash

# Version: 1.1
# Author: piklz
# GitHub: https://github.com/piklz
# Description:
# A script to check SMART health status and disk usage, with two output modes and manual device checking.

# --- Help Function ---
display_help() {
    echo "Usage: sudo ./drive_smart_status.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help                  Display this help message and exit."
    echo "  --simple                Output a simple, single-line status for each drive (e.g., label=✅)."
    echo "  --device <DEVICE>       Check a single device specified by its path (e.g., /dev/sda1) or label (e.g., Seagate2TB)."
    echo ""
    echo "Examples:"
    echo "  sudo ./drive_smart_status.sh"
    echo "  sudo ./drive_smart_status.sh --simple"
    echo "  sudo ./drive_smart_status.sh --device /dev/sdb1"
    echo "  sudo ./drive_smart_status.sh --simple --device /dev/sdb1"
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
OUTPUT_MODE="full"
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
    --device)
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        MANUAL_DEVICE="$2"
        shift 2
      else
        echo "Error: --device requires an argument (e.g., /dev/sda1 or a label)."
        exit 1
      fi
      ;;
    *)
      echo "Error: Invalid argument '$1'."
      echo "Use --help for a list of available options."
      exit 1
      ;;
  esac
done

# A list to store disks that have been checked to avoid duplicates
declare -A checked_disks

# --- Output Functions ---
display_dashboard_output() {
    local label=$1
    local status_emoji=$2
    local usage_percent=$3
    local total_size=$4

    local bar_color='\033[0;32m'
    if [ "$usage_percent" -gt 80 ]; then
        bar_color='\033[0;31m'
    elif [ "$usage_percent" -gt 20 ]; then
        bar_color='\033[0;33m'
    fi

    local reset_color='\033[0m'
    local num_blocks=$((usage_percent / 10))
    local num_spaces=$((10 - num_blocks))
    local bar_text=""
    
    for ((i=0; i<num_blocks; i++)); do
        bar_text="${bar_text}▇"
    done
    for ((i=0; i<num_spaces; i++)); do
        bar_text="${bar_text} "
    done

    echo -e "  │ \033[1m$(printf "%-15s" "$label")\033[0m \033[0;36mStatus:\033[0m $status_emoji \033[0;36mUsed:\033[0m ${bar_color}[${bar_text}]${usage_percent}%${reset_color} $(printf "%-6s" "(${total_size})")"
}

display_simple_output() {
    local label=$1
    local status_emoji=$2
    echo "$label $status_emoji"
}
# --- End of Output Functions ---

# Function to get and display the status for a given partition
check_and_display() {
    local partition_path=$1
    local mountpoint=$2
    local parent_disk_kname=$(lsblk -n -o PKNAME "$partition_path" | xargs)
    
    if [ -v "checked_disks[$parent_disk_kname]" ]; then
        return
    fi
    checked_disks["$parent_disk_kname"]=1

    local drive_label=$(blkid -s LABEL -o value "$partition_path" 2>/dev/null)
    local smart_output
    local status_emoji="❓"

    smart_output=$(smartctl --health "$partition_path" 2>&1)
    if echo "$smart_output" | grep -q "SMART Health Status: OK"; then
        status_emoji="✅"
    elif echo "$smart_output" | grep -q "SMART Health Status:"; then
        status_emoji="⚠️"
    else
        smart_output=$(smartctl -d sat --health "$partition_path" 2>&1)
        if echo "$smart_output" | grep -q "SMART Health Status: OK"; then
            status_emoji="✅"
        elif echo "$smart_output" | grep -q "SMART Health Status:"; then
            status_emoji="⚠️"
        fi
    fi

    local df_output=$(df -hP "$mountpoint" | awk 'NR==2 {print $2, $5}')
    local total_size=$(echo "$df_output" | awk '{print $1}')
    local usage_percent=$(echo "$df_output" | awk '{print $2}' | sed 's/%//')
    
    local output_label
    if [ -n "$drive_label" ]; then
        output_label="$drive_label"
    else
        output_label="$partition_path"
    fi

    if [ "$OUTPUT_MODE" == "full" ]; then
        display_dashboard_output "$output_label" "$status_emoji" "$usage_percent" "$total_size"
    else
        display_simple_output "$output_label" "$status_emoji"
    fi
}

# --- Main Execution Block ---
if [ -n "$MANUAL_DEVICE" ]; then
    PARTITION_PATH=$(blkid -L "$MANUAL_DEVICE" 2>/dev/null || echo "$MANUAL_DEVICE")
    
    if [ -b "$PARTITION_PATH" ]; then
        MOUNTPOINT=$(lsblk -n -o MOUNTPOINT "$PARTITION_PATH" | xargs)
        if [ -z "$MOUNTPOINT" ]; then
            echo "Error: The device '$PARTITION_PATH' is not a mounted partition."
            exit 1
        fi
        
        if [ "$OUTPUT_MODE" == "full" ]; then
            echo "  ╭─── Drive Health & Usage Monitor ────────────────────────╮"
        fi

        check_and_display "$PARTITION_PATH" "$MOUNTPOINT"

        if [ "$OUTPUT_MODE" == "full" ]; then
            echo "  ╰─────────────────────────────────────────────────────────╯"
        fi
    else
        echo "Error: Device '$MANUAL_DEVICE' not found. Please provide a valid device path or label."
        exit 1
    fi
else
    if [ "$OUTPUT_MODE" == "full" ]; then
        echo "  ╭─── Drive Health & Usage Monitor ────────────────────────╮"
    fi

    while read -r kname mountpoint; do
        if [ -n "$mountpoint" ]; then
            check_and_display "/dev/$kname" "$mountpoint"
        fi
    done < <(lsblk -n -o KNAME,MOUNTPOINT | grep -E 'sd[a-z][0-9]|nvme' | grep -v ' /$')

    if [ "$OUTPUT_MODE" == "full" ]; then
        echo "  ╰─────────────────────────────────────────────────────────╯"
    fi
fi