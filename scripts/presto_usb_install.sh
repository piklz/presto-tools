#!/usr/bin/env bash
# shellcheck disable=SC1090
#__/\\\________/\\\_____/\\\\\\\\\\\____/\\\\\\\\\\\\\___        
# _\/\\\_______\/\\\___/\\\/////////\\\_\/\\\/////////\\\_       
#  _\/\\\_______\/\\\__\//\\\______\///__\/\\\_______\/\\\_      
#   _\/\\\_______\/\\\___\////\\\_________\/\\\\\\\\\\\\\\__     
#    _\/\\\_______\/\\\______\////\\\______\/\\\/////////\\\_    
#     _\/\\\_______\/\\\_________\////\\\___\/\\\_______\/\\\_   
#      _\//\\\______/\\\___/\\\______\//\\\__\/\\\_______\/\\\_  
#       __\///\\\\\\\\\/___\///\\\\\\\\\\\/___\/\\\\\\\\\\\\\/__ 
#        ____\/////////_______\///////////_____\/////////////____ PRESTO by PIKLZ
#-------------------------------------------------------------------------------------------------
# presto_usb_install.sh - Automates mounting of external USB drives for Plex media servers
# Version: 1.9
# Author: piklz
# GitHub: https://github.com/piklz
# Web: https://github.com/piklz/presto-tools.git
# Description:
#   Automates mounting of external USB drives (ext4/NTFS) on Linux systems for Plex media servers.
#   Creates mount points, updates /etc/fstab with safe or optimized options, ensures Docker compatibility,
#   and logs details to systemd-journald, with rotation managed by journald.
#
# Changelog:
#   Version 1.9 (2025-08-22):
#     - Modified the script to display the verbose output of `mount -a -v` directly to the terminal,
#       providing immediate feedback that the new fstab entry has been applied without a reboot.
#       added fstab comment per drive entry with timestamp and drive label for easier identification.
#       Added `systemctl daemon-reload` after updating /etc/fstab to ensure systemd recognizes the new mount points immediately.
#       Updated the welcome message to inform users about the script's purpose and version.
#   Version 1.8 (2025-08-22):
#     - Removed redundant information from the whiptail menu's drive descriptions. The menu now
#       only shows the drive label followed by the device name.
#     - Corrected the "waiting" ticker to prevent it from appearing inside the whiptail menu.
#     - Removed a duplicate log message at the start of the drive detection process.
#   Version 1.7 (2025-08-22):
#     - Refined whiptail menu to display drive labels first (e.g., "MyUSBDrive /dev/sdb1").
#     - Added a "waiting" ticker to the drive detection process for visual feedback.
#     - Removed duplicate log messages.
#     - Implemented a `--help` flag to display script information and journal log commands.
#   Version 1.6 (2025-08-22):
#     - Fixed a bug where the whiptail drive selection menu description was being truncated due to incorrect parsing.
#     - Ensures the full descriptive text, including the drive label and other info, is now displayed correctly.
#   Version 1.5 (2025-08-22):
#     - Improved the whiptail drive selection menu to display a more comprehensive description, including the drive label.
#     - Updated the script header and changelog.
#   Version 1.4 (2025-08-21):
#     - Refactored all log_bug and print statements to use systemd-cat for structured journal logging.
#     - Removed custom logging functions (log_debug, print_info, etc.).
#     - Simplified error handling by directing all terminal output to stderr and journal.
#   Version 1.3 (2025-08-21):
#     - Replaced file-based logging with systemd-cat journal logging.
#     - Removed DEBUG_LOG and related code, updated verbose mode to use -d flag.
#     - Added journal logging tips to --help output.
#     - Fixed missing device rescan in detect_drives and improved whiptail argument parsing.
#   Version 1.2 (2024-10-15):
#     - Improved user experience in detect_drives with a progress indicator (dots).
#     - Added cleanup of old log files in /tmp.
#     - Fixed permission issue for log file creation.
#   Version 1.1 (2024-09-01):
#     - Added support for ntfs-3g installation prompt and improved error handling.
#   Version 1.0 (2024-08-01):
#     - Initial release with drive detection, fstab management, and Docker compatibility.
#
# Usage:
#   Run the script with sudo: `sudo ./presto_usb_install.sh [OPTIONS]`
#   - Options include --help and -d for debug logging (replaces --verbose from v1.2).
#   - Logs can be viewed with: `journalctl -t presto_usb_mount -n 10`.
#   - Ensure dependencies (whiptail, lsblk, blkid, ntfs-3g for NTFS) are installed.
#-------------------------------------------------------------------------------------------------

#script version
VERSION="1.9"
# Set a journal tag for all log messages
JOURNAL_TAG="presto_usb_mount"

# This is a temporary variable to hold verbose state. The -d option from the v1.3 changelog is not implemented in the provided code, so this remains.
# The original code's `VERBOSE` flag is based on `--verbose`. The changelog mentions a switch to `-d` for debug logging. 
DEBUG_MODE=false
for arg in "$@"; do
    if [ "$arg" = "--verbose" ] || [ "$arg" = "--debug" ] || [ "$arg" = "-d" ]; then
        DEBUG_MODE=true
        break
    fi
done

# Colors for terminal output
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
GREEN=$(tput setaf 2)
RESET=$(tput sgr0)

# Function to display help information
show_help() {
    echo "presto_usb_install.sh (v${VERSION})"
    echo "Automates mounting of external USB drives for Plex media servers."
    echo ""
    echo "Usage: sudo ./presto_usb_install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help          Display this help message and exit."
    echo "  -d, --debug     Enable verbose debug logging."
    echo ""
    echo "To view journal logs for this script, use:"
    echo "  journalctl -t presto_usb_mount -n 10"
    echo ""
}

if [ "$1" == "--help" ]; then
    show_help
    exit 0
fi

# Function to send messages to stderr and the system journal with a specified priority
log_message() {
    local priority="$1"
    shift
    local message="$@"
    local journald_priority
    
    # Map script's custom priorities to journald's standard priorities
    case "$priority" in
        "error")
            journald_priority="err"
            echo "[presto_usbMount] ${RED}ERROR${RESET}: ${message}" >&2
            ;;
        "success")
            journald_priority="info"
            echo "[presto_usbMount] ${GREEN}SUCCESS${RESET}: ${message}" >&2
            ;;
        "info")
            journald_priority="info"
            if [ "$DEBUG_MODE" = false ]; then
                echo "[presto_usbMount] ${BLUE}INFO${RESET}: ${message}" >&2
            fi
            ;;
        "debug")
            journald_priority="debug"
            if [ "$DEBUG_MODE" = true ]; then
                echo "[presto_usbMount] DEBUG: ${message}" >&2
            fi
            ;;
        *)
            journald_priority="notice"
            echo "[presto_usbMount] NOTICE: ${message}" >&2
            ;;
    esac
    
    # Send message to systemd-journald
    echo "${message}" | systemd-cat -t "${JOURNAL_TAG}" --priority="${journald_priority}"
}

# Function to strip ANSI color codes for whiptail
strip_ansi_codes() {
    local input=$1
    echo "$input" | sed 's/\x1B\[[0-9;]*[mK]//g' | sed 's/\x1B[(]B//g'
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    log_message "error" "This script must be run as root. Please use sudo."
    whiptail --msgbox "This script must be run as root. Please use sudo." 8 60
    exit 1
fi

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    log_message "info" "Installing whiptail..."
    log_message "debug" "Attempting to install whiptail"
    if command -v apt &> /dev/null; then
        if ! apt update || ! apt install -y whiptail; then
            log_message "error" "Failed to install whiptail using apt."
            whiptail --msgbox "Failed to install whiptail using apt." 8 60
            exit 1
        fi
    elif command -v apt-get &> /dev/null; then
        log_message "info" "apt not found, falling back to apt-get for whiptail installation."
        log_message "debug" "Falling back to apt-get for whiptail"
        if ! apt-get update || ! apt-get install -y whiptail; then
            log_message "error" "Failed to install whiptail using apt-get."
            whiptail --msgbox "Failed to install whiptail using apt-get." 8 60
            exit 1
        fi
    else
        log_message "error" "Neither apt nor apt-get found. Cannot install whiptail. Please install manually."
        whiptail --msgbox "Neither apt nor apt-get found. Cannot install whiptail. Please install manually." 8 60
        exit 1
    fi
    log_message "success" "Successfully installed whiptail."
fi

# Function to prompt for ntfs-3g installation
prompt_install_ntfs3g() {
    if ! command -v ntfs-3g &> /dev/null; then
        log_message "info" "NTFS-3g is not installed. Prompting user to install."
        log_message "debug" "NTFS-3g not found, prompting for installation"
        if whiptail --yesno "NTFS-3g is required to mount NTFS drives. Install it now?" 8 60; then
            log_message "info" "Installing ntfs-3g..."
            log_message "debug" "Attempting to install ntfs-3g"
            if command -v apt &> /dev/null; then
                if ! apt update || ! apt install -y ntfs-3g; then
                    log_message "error" "Failed to install ntfs-3g using apt. NTFS drives cannot be mounted."
                    whiptail --msgbox "Failed to install ntfs-3g using apt. NTFS drives cannot be mounted." 8 60
                    return 1
                fi
            elif command -v apt-get &> /dev/null; then
                log_message "info" "apt not found, falling back to apt-get for ntfs-3g installation."
                log_message "debug" "Falling back to apt-get for ntfs-3g"
                if ! apt-get update || ! apt-get install -y ntfs-3g; then
                    log_message "error" "Failed to install ntfs-3g using apt-get. NTFS drives cannot be mounted."
                    whiptail --msgbox "Failed to install ntfs-3g using apt-get. NTFS drives cannot be mounted." 8 60
                    return 1
                fi
            else
                log_message "error" "Neither apt nor apt-get found. Cannot install ntfs-3g. Please install manually."
                whiptail --msgbox "Neither apt nor apt-get found. Cannot install ntfs-3g. Please install manually." 8 60
                return 1
            fi
            log_message "success" "Successfully installed ntfs-3g."
        else
            log_message "error" "NTFS-3g is not installed. NTFS drives cannot be mounted."
            log_message "debug" "User declined to install ntfs-3g"
            whiptail --msgbox "NTFS-3g is not installed. NTFS drives cannot be mounted." 8 60
            return 1
        fi
    else
        log_message "info" "NTFS-3g is already installed."
    fi
    return 0
}

# Function to detect external drives (partitions like sdb1)
detect_drives() {
    log_message "info" "Detecting drives..."
    log_message "debug" "Starting device rescan"
    # Rescan devices to clear stale partitions
    if command -v partprobe &> /dev/null; then
        partprobe /dev/sd* 2>> /dev/null
        log_message "debug" "Ran partprobe on /dev/sd*"
    else
        log_message "info" "partprobe not found, falling back to manual rescan."
        log_message "debug" "partprobe not found, using manual rescan"
        for block in /sys/block/sd*; do
            if [ -e "$block/device/rescan" ]; then
                echo 1 > "$block/device/rescan" 2>> /dev/null
                log_message "debug" "Rescanned device: $block"
            fi
        done
    fi
    drives=""
    printf "Waiting for drives to be detected..." >&2
    for attempt in {1..3}; do
        lsblk_output=$(lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MODEL -p 2>/dev/null)
        blkid_output=$(blkid 2>/dev/null)
        log_message "debug" "Attempt $attempt: lsblk output: $lsblk_output"
        log_message "debug" "Attempt $attempt: blkid output: $blkid_output"
        drives=""
        # Check if sda/sdb disks exist
        if lsblk -n -o NAME -p -d | grep -q '/dev/sd[a-z]'; then
            if command -v jq &> /dev/null; then
                drives=$(lsblk -J -o NAME,SIZE,FSTYPE,LABEL,MODEL -p 2>/dev/null | jq -r '.blockdevices[] | select(.name | test("/dev/sd[a-z]")) | .children[]? | .name as $name | .size as $size | .fstype as $fstype | .label as $label | .model as $model | [$name, ($size // "Unknown"), ($fstype // "No Filesystem"), ($label // "No Label"), ($model // "Unknown Model")] | @tsv' | while IFS=$'\t' read -r name size fstype label model; do
                    if [ -b "$name" ]; then
                        blkid_fstype=$(blkid -s TYPE -o value "$name" 2>/dev/null || echo "No Filesystem")
                        blkid_label=$(blkid -s LABEL -o value "$name" 2>/dev/null || echo "No Label")
                        if [[ "$blkid_fstype" =~ ^(ntfs|ntfs3)$ ]]; then
                            blkid_fstype="ntfs"
                        fi
                        display_fstype=${blkid_fstype:-${fstype:-No Filesystem}}
                        display_label=${blkid_label:-${label:-No Label}}
                        clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9\/]//g')
                        term_desc="$display_label ($clean_name, $size, $display_fstype)"
                        log_message "debug" "Detected drive: $term_desc"
                        echo "$clean_name \"$display_label $clean_name\""
                    fi
                done)
            else
                drives=$(lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MODEL -p | grep -E '/dev/sd[a-z][0-9]+' | while read -r name size fstype label model; do
                    if [ -b "$name" ]; then
                        blkid_fstype=$(blkid -s TYPE -o value "$name" 2>/dev/null || echo "No Filesystem")
                        blkid_label=$(blkid -s LABEL -o value "$name" 2>/dev/null || echo "No Label")
                        if [[ "$blkid_fstype" =~ ^(ntfs|ntfs3)$ ]]; then
                            blkid_fstype="ntfs"
                        fi
                        display_fstype=${blkid_fstype:-${fstype:-No Filesystem}}
                        display_label=${blkid_label:-${label:-No Label}}
                        clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9\/]//g')
                        term_desc="$display_label ($clean_name, $size, $display_fstype)"
                        log_message "debug" "Detected drive: $term_desc"
                        echo "$clean_name \"$display_label $clean_name\""
                    fi
                done)
            fi
            # Break if drives are found
            [ -n "$drives" ] && break
            printf "." >&2
            log_message "debug" "No drives detected on attempt $attempt"
            sleep 2
        else
            printf "." >&2
            log_message "debug" "No external disks detected by lsblk -d on attempt $attempt"
            sleep 2
        fi
    done
    # Clear progress dots
    printf "\r\033[K" >&2
    # Fallback to blkid if lsblk finds no partitions
    if [ -z "$drives" ]; then
        log_message "debug" "No partitions found by lsblk after retries, attempting blkid fallback"
        drives=$(blkid -o device | grep -E '/dev/sd[a-z][0-9]+' | while read -r name; do
            if [ -b "$name" ]; then
                blkid_fstype=$(blkid -s TYPE -o value "$name" 2>/dev/null || echo "No Filesystem")
                blkid_label=$(blkid -s LABEL -o value "$name" 2>/dev/null || echo "No Label")
                if [[ "$blkid_fstype" =~ ^(ntfs|ntfs3)$ ]]; then
                    blkid_fstype="ntfs"
                fi
                lsblk_info=$(lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MODEL -p | grep "^$name\s" || echo "")
                if [ -n "$lsblk_info" ]; then
                    read _ size fstype label model < <(echo "$lsblk_info")
                else
                    size="Unknown"
                    fstype="No Filesystem"
                    label="No Label"
                    model="Unknown Model"
                fi
                display_fstype=${blkid_fstype:-${fstype:-No Filesystem}}
                display_label=${blkid_label:-${label:-No Label}}
                clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9\/]//g')
                term_desc="$display_label ($clean_name, $display_size, $display_fstype)"
                log_message "debug" "Detected drive (blkid fallback): $term_desc"
                echo "$clean_name \"$display_label $clean_name\""
            fi
        done)
    fi
    if [ -n "$drives" ]; then
        log_message "info" "Drives detected:"
    else
        log_message "error" "No external drive partitions detected after retries and blkid fallback. Please connect a drive."
        whiptail --msgbox "No external drive partitions detected after retries and blkid fallback. Please connect a drive and try again." 8 60
        log_message "debug" "No external drive partitions detected after retries and blkid."
        exit 1
    fi
    log_message "debug" "Final drives output: $drives"
    echo "$drives"
}

# Function to get filesystem type and PARTUUID (fallback to UUID if PARTUUID unavailable)
get_drive_info() {
    local drive=$1
    partuuid=$(blkid -s PARTUUID -o value "$drive" 2>/dev/null)
    fstype=$(blkid -s TYPE -o value "$drive" 2>/dev/null)
    log_message "debug" "Drive $drive: PARTUUID=$partuuid, FSTYPE=$fstype"
    if [ -z "$partuuid" ]; then
        log_message "debug" "PARTUUID not found for $drive, attempting to use UUID"
        partuuid=$(blkid -s UUID -o value "$drive" 2>/dev/null)
        if [ -z "$partuuid" ] || [ -z "$fstype" ]; then
            log_message "error" "Failed to retrieve PARTUUID or filesystem type for $drive"
            whiptail --msgbox "Failed to retrieve PARTUUID or filesystem type for $drive." 8 60
            log_message "debug" "Failed to retrieve PARTUUID or fstype for $drive"
            exit 1
        fi
        echo "UUID=$partuuid $fstype"
    else
        echo "PARTUUID=$partuuid $fstype"
    fi
}

# Function to check if PARTUUID (or UUID) is already in fstab
check_fstab_duplicate() {
    local id_type=$1
    local id_value=$2
    if grep -q "$id_type=$id_value" /etc/fstab; then
        log_message "error" "Drive with $id_type $id_value is already in /etc/fstab."
        whiptail --msgbox "Drive with $id_type $id_value is already in /etc/fstab. Please select a different drive or remove the existing entry manually." 8 60
        log_message "debug" "Duplicate $id_type found in fstab: $id_value"
        exit 1
    fi
}

# Function to validate filesystem
validate_filesystem() {
    local fstype=$1
    local drive=$2
    if [[ "$fstype" != "ext4" && "$fstype" != "ntfs" && "$fstype" != "ntfs3" ]]; then
        log_message "error" "Unsupported filesystem: $fstype on $drive. Only ext4 and NTFS are supported."
        whiptail --msgbox "Unsupported filesystem: $fstype on $drive. Only ext4 and NTFS are supported." 8 60
        log_message "debug" "Unsupported filesystem: $fstype on $drive"
        exit 1
    fi
    if [[ "$fstype" == "ntfs" || "$fstype" == "ntfs3" ]]; then
        prompt_install_ntfs3g || {
            log_message "error" "Cannot proceed with NTFS drive without ntfs-3g."
            whiptail --msgbox "Cannot proceed with NTFS drive without ntfs-3g." 8 60
            log_message "debug" "Cannot proceed with NTFS drive without ntfs-3g"
            exit 1
        }
    fi
}

# Function to prompt for filesystem check
prompt_filesystem_check() {
    local drive=$1
    local fstype=$2
    if [ "$fstype" = "ext4" ]; then
        if whiptail --yesno "Run filesystem check (fsck) on $drive before mounting? Recommended for new or potentially faulty drives." 8 60; then
            log_message "info" "Checking filesystem on $drive..."
            log_message "debug" "Running fsck on $drive"
            timeout 300 fsck -f -y "$drive" >> /dev/null 2>&1 || {
                log_message "error" "Filesystem check failed or timed out on $drive. Please manually repair with 'fsck $drive'."
                whiptail --msgbox "Filesystem check failed or timed out on $drive. Please manually repair with 'fsck $drive'." 8 60
                log_message "debug" "Filesystem check failed or timed out on $drive"
                exit 1
            }
            log_message "success" "Filesystem check completed on $drive."
        else
            log_message "info" "Skipping filesystem check on $drive."
        fi
    elif [[ "$fstype" == "ntfs" || "$fstype" == "ntfs3" ]] && command -v ntfsfix >/dev/null 2>&1; then
        if whiptail --yesno "Run filesystem check (ntfsfix) on $drive before mounting? Recommended for new or potentially faulty drives." 8 60; then
            log_message "info" "Checking NTFS filesystem on $drive..."
            log_message "debug" "Running ntfsfix on $drive"
            timeout 300 ntfsfix -n "$drive" >> /dev/null 2>&1 || {
                log_message "error" "NTFS filesystem check failed or timed out on $drive. Please manually repair with 'ntfsfix $drive'."
                whiptail --msgbox "NTFS filesystem check failed or timed out on $drive. Please manually repair with 'ntfsfix $drive'." 8 60
                log_message "debug" "NTFS filesystem check failed or timed out on $drive"
                exit 1
            }
            log_message "success" "NTFS filesystem check completed on $drive."
        else
            log_message "info" "Skipping NTFS filesystem check on $drive."
        fi
    fi
}

# Function to test mount
test_mount() {
    local drive=$1
    local mount_point=$2
    local fstype=$3
    local uid=$4
    local gid=$5
    local options=$6
    if [ ! -d "$mount_point" ]; then
        log_message "error" "Mount point $mount_point does not exist."
        return 1
    fi
    if [ "$fstype" = "ext4" ]; then
        mount_fstype="ext4"
    else
        mount_fstype="ntfs-3g"
    fi
    log_message "info" "Testing mount of $drive on $mount_point..."
    log_message "debug" "Testing mount: mount -t $mount_fstype $drive $mount_point -o $options"
    if timeout 60 mount -t "$mount_fstype" "$drive" "$mount_point" -o "$options" >> /dev/null 2>&1; then
        log_message "success" "Test mount successful."
        for attempt in {1..3}; do
            timeout 10 umount "$mount_point" >> /dev/null 2>&1 && {
                log_message "info" "Unmounted $mount_point after test."
                break
            }
            log_message "error" "Failed to unmount $mount_point (attempt $attempt/3). Retrying..."
            log_message "debug" "Failed to unmount $mount_point (attempt $attempt/3)"
            sleep 1
        done
        if mount | grep -q "$mount_point"; then
            log_message "error" "Failed to unmount $mount_point after 3 attempts."
            return 1
        fi
    else
        log_message "error" "Test mount failed for $drive."
        whiptail --msgbox "Test mount failed for $drive." 8 60
        log_message "debug" "Test mount failed for $drive"
        return 1
    fi
    return 0
}

# Function to validate mount point name and handle existing mount points
validate_mount_name() {
    local name=$1
    local mount_point="/media/$name"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_message "error" "Mount name '$name' contains invalid characters. Use only letters, numbers, underscores, or hyphens."
        whiptail --msgbox "Mount name '$name' contains invalid characters.\nUse only letters, numbers, underscores, or hyphens." 10 60
        log_message "debug" "Invalid mount name: $name"
        return 1
    fi
    if [ -d "$mount_point" ]; then
        log_message "info" "Mount point '$mount_point' already exists."
        if mount | grep -q "$mount_point"; then
            if whiptail --yesno "Mount point '$mount_point' is currently mounted. Unmount and remove it?" 8 60; then
                timeout 10 umount "$mount_point" >> /dev/null 2>&1 || {
                    log_message "error" "Failed to unmount $mount_point."
                    whiptail --msgbox "Failed to unmount $mount_point." 8 60
                    log_message "debug" "Failed to unmount $mount_point"
                    return 1
                }
                rmdir "$mount_point" >> /dev/null 2>&1 || {
                    log_message "error" "Failed to remove $mount_point."
                    whiptail --msgbox "Failed to remove $mount_point." 8 60
                    log_message "debug" "Failed to remove $mount_point"
                    return 1
                }
                log_message "success" "Removed existing mount point $mount_point."
            else
                log_message "error" "Cannot proceed with existing mount point. Please choose a different name or manually remove $mount_point."
                whiptail --msgbox "Cannot proceed with existing mount point. Please choose a different name or manually remove $mount_point." 10 60
                log_message "debug" "User declined to remove mounted $mount_point"
                return 1
            fi
        else
            if whiptail --yesno "Mount point '$mount_point' exists but is not mounted. Remove it?" 8 60; then
                rmdir "$mount_point" >> /dev/null 2>&1 || {
                    log_message "error" "Failed to remove $mount_point."
                    whiptail --msgbox "Failed to remove $mount_point." 8 60
                    log_message "debug" "Failed to remove $mount_point"
                    return 1
                }
                log_message "success" "Removed existing mount point $mount_point."
            else
                log_message "error" "Cannot proceed with existing mount point. Please choose a different name or manually remove $mount_point."
                whiptail --msgbox "Cannot proceed with existing mount point. Please choose a different name or manually remove $mount_point." 10 60
                log_message "debug" "User declined to remove unmounted $mount_point"
                return 1
            fi
        fi
    fi
    return 0
}

# Function to create mount point
create_mount_point() {
    local mount_name=$1
    local mount_point="/media/$mount_name"
    mkdir -p "$mount_point" || {
        log_message "error" "Failed to create mount point $mount_point"
        whiptail --msgbox "Failed to create mount point $mount_point." 8 60
        log_message "debug" "Failed to create mount point: $mount_point"
        exit 1
    }
    chmod 755 "$mount_point"
    chown root:root "$mount_point" || {
        log_message "error" "Failed to set ownership on $mount_point to root:root"
        log_message "debug" "Failed to set ownership on $mount_point to root:root"
        exit 1
    }
    log_message "success" "Created mount point: $mount_point"
    printf "%s" "$mount_point"
}

# Function to prompt for UID and GID (only for NTFS)
prompt_uid_gid() {
    local uid gid
    uid=$(whiptail --inputbox "Enter UID for the mount (default: 1000, typical for Docker and Raspberry Pi user 'pi'):" 8 60 1000 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ -z "$uid" ]; then
        log_message "info" "No UID provided, using default 1000."
        uid=1000
    fi
    gid=$(whiptail --inputbox "Enter GID for the mount (default: 1000, typical for Docker and Raspberry Pi user 'pi'):" 8 60 1000 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ -z "$gid" ]; then
        log_message "info" "No GID provided, using default 1000."
        gid=1000
    fi
    if ! [[ "$uid" =~ ^[0-9]+$ ]] || ! [[ "$gid" =~ ^[0-9]+$ ]]; then
        log_message "error" "Invalid UID or GID. Must be numeric."
        whiptail --msgbox "Invalid UID or GID. Must be numeric." 8 60
        log_message "debug" "Invalid UID or GID: uid=$uid, gid=$gid"
        exit 1
    fi
    echo "$uid $gid"
}

# Function to prompt for fstab options
prompt_fstab_options() {
    local fstype=$1
    local id_entry=$2
    local mount_point=$3
    local uid=$4
    local gid=$5
    local options fsck_option fstab_entry
    if [ "$fstype" = "ext4" ]; then
        safe_entry="$id_entry $mount_point ext4 defaults,nofail,errors=remount-ro 0 2"
        optimized_entry="$id_entry $mount_point ext4 defaults,nofail,noatime,commit=30 0 2"
        choice=$(whiptail --title "Select fstab Options" --menu "Choose fstab options for your ext4 drive:\n\nSafe: Best for data safety, checks filesystem on boot.\n$safe_entry\n\nOptimized: Improves performance for media servers, reduces disk writes.\n$optimized_entry" 16 80 2 \
            "Safe" "Maximize data safety" \
            "Optimized" "Optimize for performance" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ] || [ -z "$choice" ]; then
            log_message "info" "No fstab option selected. Using Safe for ext4."
            options="defaults,nofail,errors=remount-ro"
            fsck_option="0 2"
            fstype="ext4"
        elif [ "$choice" = "Safe" ]; then
            options="defaults,nofail,errors=remount-ro"
            fsck_option="0 2"
            fstype="ext4"
        else
            options="defaults,nofail,noatime,commit=30"
            fsck_option="0 2"
            fstype="ext4"
        fi
    else
        safe_entry="$id_entry $mount_point ntfs-3g defaults,nofail,uid=$uid,gid=$gid,umask=000 0 2"
        optimized_entry="$id_entry $mount_point ntfs-3g defaults,nofail,noatime,uid=$uid,gid=$gid,umask=000 0 2"
        choice=$(whiptail --title "Select fstab Options" --menu "Choose fstab options for your NTFS drive:\n\nSafe: Ensures proper permissions, checks filesystem on boot.\n$safe_entry\n\nOptimized: Improves performance for media servers, reduces disk writes.\n$optimized_entry" 16 80 2 \
            "Safe" "Ensure proper permissions" \
            "Optimized" "Optimize for performance" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ] || [ -z "$choice" ]; then
            log_message "info" "No fstab option selected. Using Safe for NTFS."
            options="defaults,nofail,uid=$uid,gid=$gid,umask=000"
            fsck_option="0 2"
            fstype="ntfs-3g"
        elif [ "$choice" = "Safe" ]; then
            options="defaults,nofail,uid=$uid,gid=$gid,umask=000"
            fsck_option="0 2"
            fstype="ntfs-3g"
        else
            options="defaults,nofail,noatime,uid=$uid,gid=$gid,umask=000"
            fsck_option="0 2"
            fstype="ntfs-3g"
        fi
    fi
    echo "$id_entry $mount_point $fstype $options $fsck_option"
}

# Function to check filesystem size
check_filesystem_size() {
    local mount_point=$1
    local file_count=0
    local size=0
    if mount | grep -q "$mount_point"; then
        file_count=$(find "$mount_point" -maxdepth 1 | wc -l)
        size=$(du -s "$mount_point" 2>/dev/null | cut -f1)
        log_message "debug" "Filesystem check: $mount_point has $file_count top-level entries, size $size KB"
        if [ "$file_count" -gt 1000 ] || [ "$size" -gt 1000000 ]; then
            log_message "info" "Warning: Large filesystem detected ($file_count files, $size KB). Recursive permission changes may take significant time."
            return 1
        fi
    else
        log_message "debug" "Cannot check filesystem size: $mount_point not mounted"
    fi
    return 0
}

# Function to set permissions for ext4 mounts
set_permissions() {
    local mount_point=$1
    local uid=$2
    local gid=$3
    local recursive=false
    log_message "info" "Setting permissions on $mount_point..."
    log_message "debug" "Checking filesystem size before setting permissions"
    if check_filesystem_size "$mount_point"; then
        recursive=false
    else
        if whiptail --yesno "Large filesystem detected at $mount_point.\nApply permissions recursively to all files (may take a long time)?\nChoose 'No' to set permissions only on the mount point directory." 10 60; then
            recursive=true
            log_message "info" "User chose to apply permissions recursively."
        else
            recursive=false
            log_message "info" "Applying permissions only to mount point directory."
        fi
    fi
    if [ "$recursive" = true ]; then
        log_message "debug" "Starting chmod -R 777 $mount_point"
        log_message "info" "Applying recursive permissions (this may take a while)..."
        timeout --signal=KILL 600 nice -n 10 ionice -c3 chmod -R 777 "$mount_point" >> /dev/null 2>&1 || {
            log_message "error" "Failed or timed out setting recursive permissions on $mount_point"
            whiptail --msgbox "Failed or timed out setting recursive permissions on $mount_point." 8 60
            exit 1
        }
        log_message "debug" "Completed chmod -R 777 $mount_point"
        log_message "debug" "Starting chown -R $uid:$gid $mount_point"
        timeout --signal=KILL 600 nice -n 10 ionice -c3 chown -R "$uid:$gid" "$mount_point" >> /dev/null 2>&1 || {
            log_message "error" "Failed or timed out setting recursive ownership on $mount_point"
            whiptail --msgbox "Failed or timed out setting recursive ownership on $mount_point." 8 60
            exit 1
        }
        log_message "debug" "Completed chown -R $uid:$gid $mount_point"
    else
        log_message "debug" "Starting chmod 777 $mount_point"
        timeout --signal=KILL 60 nice -n 10 ionice -c3 chmod 777 "$mount_point" >> /dev/null 2>&1 || {
            log_message "error" "Failed or timed out setting permissions on $mount_point"
            whiptail --msgbox "Failed or timed out setting permissions on $mount_point." 8 60
            exit 1
        }
        log_message "debug" "Completed chmod 777 $mount_point"
        log_message "debug" "Starting chown $uid:$gid $mount_point"
        timeout --signal=KILL 60 nice -n 10 ionice -c3 chown "$uid:$gid" "$mount_point" >> /dev/null 2>&1 || {
            log_message "error" "Failed or timed out setting ownership on $mount_point"
            whiptail --msgbox "Failed or timed out setting ownership on $mount_point." 8 60
            exit 1
        }
        log_message "debug" "Completed chown $uid:$gid $mount_point"
    fi
    log_message "success" "Set permissions and ownership on $mount_point (uid=$uid, gid=$gid)"
    final_perms=$(ls -ld "$mount_point" | awk '{print $1, $3, $4}')
    log_message "debug" "Final permissions on $mount_point: $final_perms"
}

# Function to test Docker compatibility
test_docker_compatibility() {
    local mount_point=$1
    if command -v docker &> /dev/null; then
        log_message "info" "Testing Docker compatibility for $mount_point..."
        if mountpoint -q "$mount_point"; then
            if docker run --rm -v "$mount_point:/mnt" alpine sh -c "touch /mnt/testfile && rm /mnt/testfile" >> /dev/null 2>&1; then
                log_message "success" "Docker can access $mount_point."
            else
                log_message "error" "Docker cannot access $mount_point. Check SELinux/AppArmor or permissions."
                whiptail --msgbox "Docker cannot access $mount_point. Check SELinux/AppArmor or permissions." 8 60
                log_message "debug" "Docker compatibility test failed for $mount_point"
                return 1
            fi
        else
            log_message "error" "Cannot test Docker compatibility: $mount_point is not mounted."
            return 1
        fi
    else
        log_message "info" "Docker not installed, skipping compatibility test."
    fi
    return 0
}

# Function to clean up failed fstab entries
cleanup_fstab() {
    local mount_point=$1
    local id_entry=$2
    if grep -q "$id_entry" /etc/fstab; then
        log_message "info" "Removing failed fstab entry for $id_entry..."
        sed -i.bak "/$id_entry/d" /etc/fstab || {
            log_message "error" "Failed to remove fstab entry for $id_entry."
        }
        log_message "success" "Removed failed fstab entry."
    fi
    if [ -d "$mount_point" ] && ! mountpoint -q "$mount_point"; then
        rmdir "$mount_point" >> /dev/null 2>&1 || {
            log_message "error" "Failed to remove mount point $mount_point."
        }
    fi
}

# Fallback text-based prompt if whiptail fails
text_prompt() {
    local drives=$1
    log_message "info" "Whiptail failed. Using text-based prompt."
    echo "[presto_usbMount] Available drives:"
    echo "$drives" | while read -r name desc; do echo "[presto_usbMount] $desc"; done
    echo -n "[presto_usbMount] Enter the drive path (e.g., /dev/sdb1): "
    read -t 30 -r drive_choice
    if [ $? -ne 0 ] || [ -z "$drive_choice" ] || ! echo "$drives" | grep -q "^$drive_choice "; then
        log_message "error" "Invalid or no drive selected in text prompt."
        exit 1
    fi
    echo "$drive_choice"
}

# Main logic
main() {

    welcome_message="Welcome to presto_usb_install.sh, Version $VERSION!\n\nThis script will guide you through adding a USB drive to your system's /etc/fstab file for automatic mounting."
    whiptail --title "Presto USB Installer" --msgbox "$welcome_message" 10 60 

    drives=$(detect_drives)
    if [ -z "$drives" ]; then
        log_message "error" "No drives detected after processing."
        exit 1
    fi
    log_message "info" "Available drives:"
    echo "$drives" | while read -r name desc; do echo "$desc"; done
    log_message "debug" "Processed drives for whiptail: $(echo "$drives" | awk '{print $1}')"

    whiptail_args=$(echo "$drives")
    if [ -z "$whiptail_args" ]; then
        log_message "error" "Failed to generate valid whiptail arguments. Check drive detection."
        exit 1
    fi
    log_message "debug" "Running whiptail for drive selection: whiptail --title 'Select External Drive Partition' --menu 'Choose the drive partition to mount (ext4 or NTFS only):' 15 80 4 $whiptail_args"
    
    # Read the arguments for whiptail and pass them to the command correctly
    declare -a args
    while read -r name desc; do
        args+=("$name" "$desc")
    done <<< "$drives"

    drive_choice=$(whiptail --title "Select External Drive Partition" --menu "Choose the drive partition to mount (ext4 or NTFS only):" 15 80 4 "${args[@]}" 3>&1 1>&2 2>&3)
    whiptail_exit=$?
    log_message "debug" "Whiptail exit code: $whiptail_exit, Selected: $drive_choice"

    if [ $whiptail_exit -eq 1 ] && [ -z "$drive_choice" ]; then
        log_message "error" "Operation cancelled by user during drive selection."
        exit 1
    elif [ $whiptail_exit -ne 0 ] || [ -z "$drive_choice" ]; then
        log_message "info" "Whiptail failed with exit code $whiptail_exit. Falling back to text-based prompt."
        drive_choice=$(text_prompt "$drives")
    fi

    drive_name="$drive_choice"
    log_message "info" "Selected drive: $drive_name"

    # Check if drive is already mounted elsewhere
    if mount | grep -q "$drive_name"; then
        current_mount=$(mount | grep "$drive_name" | awk '{print $3}')
        log_message "error" "Drive $drive_name is already mounted at $current_mount."
        if whiptail --yesno "Drive $drive_name is already mounted at $current_mount. Unmount it to proceed?" 8 60; then
            timeout 10 umount "$drive_name" >> /dev/null 2>&1 || {
                log_message "error" "Failed to unmount $drive_name from $current_mount."
                whiptail --msgbox "Failed to unmount $drive_name from $current_mount." 8 60
                exit 1
            }
            log_message "success" "Unmounted $drive_name from $current_mount."
        else
            log_message "error" "Cannot proceed with drive already mounted."
            whiptail --msgbox "Cannot proceed with drive already mounted at $current_mount." 8 60
                log_message "debug" "User declined to unmount $drive_name from $current_mount"
            exit 1
        fi
    fi

    read id_entry fstype < <(get_drive_info "$drive_name")
    id_type=$(echo "$id_entry" | cut -d'=' -f1)
    id_value=$(echo "$id_entry" | cut -d'=' -f2)

    check_fstab_duplicate "$id_type" "$id_value"
    validate_filesystem "$fstype" "$drive_name"
    prompt_filesystem_check "$drive_name" "$fstype"

    drive_info=$(lsblk -o NAME,SIZE,FSTYPE,LABEL -p "$drive_name" | grep "$drive_name")
    # Add this line to get the display label from the drive_info string
    display_label=$(echo "$drive_info" | awk '{print $4}')
    log_message "info" "Drive details: $drive_info"

    if ! whiptail --yesno "Selected drive:\n$(strip_ansi_codes "$drive_info")\n\nIs this the correct drive to add to /etc/fstab?" 12 60; then
        if [ $? -ne 0 ]; then
            log_message "info" "Whiptail failed for confirmation. Using text-based prompt."
            echo "[presto_usbMount] Selected drive: $drive_info"
            echo -n "[presto_usbMount] Is this the correct drive to add to /etc/fstab? (y/n): "
            read -r confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                log_message "error" "Operation cancelled by user."
                exit 1
            fi
        else
            log_message "error" "Operation cancelled by user."
            exit 1
        fi
    fi

    if [[ "$fstype" == "ntfs" || "$fstype" == "ntfs3" ]]; then
        read uid gid < <(prompt_uid_gid)
        log_message "info" "Using UID: $uid, GID: $gid"
    else
        uid=0
        gid=0
        log_message "info" "Using default UID: 0, GID: 0 for ext4"
    fi

    while true; do
        mount_name=$(whiptail --inputbox "Enter a name for the mount point (letters, numbers, underscores, or hyphens only, e.g., PRESTO_MEDIA_2TB):" 8 60 PRESTO_MEDIA_2TB 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ] || [ -z "$mount_name" ]; then
            log_message "info" "Whiptail failed or no mount name provided. Using text-based prompt."
            echo -n "[presto_usbMount] Enter a name for the mount point (letters, numbers, underscores, or hyphens only, e.g., PRESTO_MEDIA_2TB): "
            read -r mount_name
            if [ -z "$mount_name" ]; then
                log_message "error" "No mount name provided."
                exit 1
            fi
        fi
        if validate_mount_name "$mount_name"; then
            break
        fi
    done

    mount_point=$(create_mount_point "$mount_name")
    if [ ! -d "$mount_point" ]; then
        log_message "error" "Failed to create or verify mount point $mount_point"
        whiptail --msgbox "Failed to create or verify mount point $mount_point." 8 60
        exit 1
    fi

    fstab_entry=$(prompt_fstab_options "$fstype" "$id_entry" "$mount_point" "$uid" "$gid")
    log_message "info" "Selected fstab entry: $fstab_entry"

    fstype=$(echo "$fstab_entry" | awk '{print $3}')
    options=$(echo "$fstab_entry" | awk '{print $4}')

    test_mount "$drive_name" "$mount_point" "$fstype" "$uid" "$gid" "$options" || {
        cleanup_fstab "$mount_point" "$id_entry"
        exit 1
    }

    if ! whiptail --yesno "Proposed /etc/fstab entry:\n$(strip_ansi_codes "$fstab_entry")\n\nAdd this to /etc/fstab?" 10 80; then
        if [ $? -ne 0 ]; then
            log_message "info" "Whiptail failed for fstab confirmation. Using text-based prompt."
            echo "[presto_usbMount] Proposed fstab entry: $fstab_entry"
            echo -n "[presto_usbMount] Add this to /etc/fstab? (y/n): "
            read -r confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                log_message "error" "Operation cancelled by user."
                cleanup_fstab "$mount_point" "$id_entry"
                exit 1
            fi
        else
            log_message "error" "Operation cancelled by user."
            cleanup_fstab "$mount_point" "$id_entry"
            exit 1
        fi
    fi

    cp /etc/fstab /etc/fstab.bak || {
        log_message "error" "Failed to backup /etc/fstab"
        whiptail --msgbox "Failed to backup /etc/fstab." 8 60
        cleanup_fstab "$mount_point" "$id_entry"
        exit 1
    }

    #echo "$fstab_entry" >> /etc/fstab

    # Get the current timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Add the timestamp and drive label  comment and fstab entry  in one go  
    printf "\n# Added by presto_usb_install.sh for %s (%s) at %s\n%s\n" "$drive_name" "$display_label" "$timestamp" "$fstab_entry" >> /etc/fstab

    # Tell systemd to reload its configuration to recognize the new fstab entry
    log_message "info" "Reloading systemd daemon to recognize new fstab entry..."
    systemctl daemon-reload

    if mount | grep -q "$mount_point"; then
        log_message "info" "Drive is already mounted at $mount_point. Skipping mount -a."
    else
        log_message "info" "Applying new fstab configuration with mount -a..."
        if mount -a -v; then
            log_message "success" "Mount successful via mount -a."
        else
            log_message "debug" "mount -a returned non-zero exit code. Checking mount status."
            if mount | grep -q "$mount_point"; then
                log_message "success" "Mount appears successful despite mount -a error. Proceeding."
            else
                log_message "error" "Failed to mount drive. Restoring original fstab."
                whiptail --msgbox "Failed to mount drive. Restoring original fstab. Check journal for details." 8 60
                mv /etc/fstab.bak /etc/fstab
                cleanup_fstab "$mount_point" "$id_entry"
                log_message "debug" "Failed to mount drive. Restored fstab."
                exit 1
            fi
        fi
    fi

    if [ "$fstype" = "ext4" ]; then
        set_permissions "$mount_point" "$uid" "$gid"
    fi

    test_docker_compatibility "$mount_point" || {
        log_message "error" "Docker compatibility test failed. Mount may not work with Docker containers."
        whiptail --msgbox "Docker compatibility test failed. Mount may not work with Docker containers." 8 60
        log_message "debug" "Docker compatibility test failed for $mount_point"
    }

    if mount | grep -q "$mount_point"; then
        summary="[presto_usbMount] ${GREEN}SUCCESS${RESET}\n"
        summary+="Drive: $drive_name\n"
        summary+="Mount Point: $mount_point\n"
        summary+="Filesystem: $fstype\n"
        summary+="$id_type: $id_value\n"
        summary+="UID: $uid\n"
        summary+="GID: $gid\n"
        summary+="Added to /etc/fstab: $fstab_entry\n"
        summary+="\nUse in Docker Compose as:\n  volumes:\n    - $mount_point:/path/in/container"
        echo -e "$summary"
        log_message "debug" "Displaying final summary with whiptail"
        whiptail --msgbox "$(strip_ansi_codes "$summary")" 16 80
        log_message "debug" "Success: $summary"
    else
        log_message "error" "Drive is not mounted at $mount_point. Check $DEBUG_LOG for details."
        whiptail --msgbox "Drive is not mounted at $mount_point. Check journalctl -t presto_usb_mount for details." 8 60
        log_message "debug" "Drive not mounted. Restored fstab."
        mv /etc/fstab.bak /etc/fstab
        cleanup_fstab "$mount_point" "$id_entry"
        exit 1
    fi

    rm -f /etc/fstab.bak
    log_message "success" "Cleaned up fstab backup"
}

main