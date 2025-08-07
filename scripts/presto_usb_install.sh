#!/usr/bin/env bash

# Version: 1.2
# Author: piklz
# GitHub: https://github.com/piklz
# Purpose: Automates mounting of external USB drives (ext4/NTFS) on Linux systems for Plex media servers. Creates mount points, updates /etc/fstab with safe or optimized options, ensures Docker compatibility, and logs details.
# Changes since v1.1: Improved user experience in detect_drives with a progress indicator (dots) instead of retry messages, which are now hidden unless --verbose is used. Added cleanup of old log files in /tmp. Fixed permission issue for log file creation.

# Debug log file
DEBUG_LOG="/tmp/presto_usb_install.log"

# Clean up old log files older than 1 day
find /tmp -name 'presto_usb_install*.log' -mtime +1 -delete 2>/dev/null

# Ensure log file is writable
touch "$DEBUG_LOG" 2>/dev/null || {
    echo "[presto_usbMount] ERROR Cannot create log file $DEBUG_LOG" >&2
    exit 1
}
chmod 666 "$DEBUG_LOG" 2>/dev/null
chown root:root "$DEBUG_LOG" 2>/dev/null

# Check for verbose mode
VERBOSE=false
if [ "$1" = "--verbose" ]; then
    VERBOSE=true
fi

# Colors for terminal output
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
GREEN=$(tput setaf 2)
RESET=$(tput sgr0)

# Function to log debug messages
log_debug() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [presto_usbMount_debug] $@" >> "$DEBUG_LOG"
}

# Function to print INFO messages in blue
print_info() {
    echo "[presto_usbMount] ${BLUE}INFO${RESET} $@" >&2
    log_debug "INFO $@"
}

# Function to print ERROR messages in red
print_error() {
    echo "[presto_usbMount] ${RED}ERROR${RESET} $@" >&2
    log_debug "ERROR $@"
}

# Function to print SUCCESS messages in green
print_success() {
    echo "[presto_usbMount] ${GREEN}SUCCESS${RESET} $@" >&2
    log_debug "SUCCESS $@"
}

# Function to strip ANSI color codes for whiptail
strip_ansi_codes() {
    local input=$1
    echo "$input" | sed 's/\x1B\[[0-9;]*[mK]//g' | sed 's/\x1B[(]B//g'
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please use sudo."
    whiptail --msgbox "This script must be run as root. Please use sudo." 8 60
    exit 1
fi

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    print_info "Installing whiptail..."
    log_debug "Attempting to install whiptail"
    if command -v apt &> /dev/null; then
        if ! apt update || ! apt install -y whiptail; then
            print_error "Failed to install whiptail using apt."
            log_debug "Failed to install whiptail using apt"
            whiptail --msgbox "Failed to install whiptail using apt." 8 60
            exit 1
        fi
    elif command -v apt-get &> /dev/null; then
        print_info "apt not found, falling back to apt-get for whiptail installation."
        log_debug "Falling back to apt-get for whiptail"
        if ! apt-get update || ! apt-get install -y whiptail; then
            print_error "Failed to install whiptail using apt-get."
            log_debug "Failed to install whiptail using apt-get"
            whiptail --msgbox "Failed to install whiptail using apt-get." 8 60
            exit 1
        fi
    else
        print_error "Neither apt nor apt-get found. Cannot install whiptail. Please install manually."
        log_debug "Neither apt nor apt-get found for whiptail"
        whiptail --msgbox "Neither apt nor apt-get found. Cannot install whiptail. Please install manually." 8 60
        exit 1
    fi
    print_success "Successfully installed whiptail."
    log_debug "Successfully installed whiptail"
fi

# Function to prompt for ntfs-3g installation
prompt_install_ntfs3g() {
    if ! command -v ntfs-3g &> /dev/null; then
        print_info "NTFS-3g is not installed. Prompting user to install."
        log_debug "NTFS-3g not found, prompting for installation"
        if whiptail --yesno "NTFS-3g is required to mount NTFS drives. Install it now?" 8 60; then
            print_info "Installing ntfs-3g..."
            log_debug "Attempting to install ntfs-3g"
            if command -v apt &> /dev/null; then
                if ! apt update || ! apt install -y ntfs-3g; then
                    print_error "Failed to install ntfs-3g using apt. NTFS drives cannot be mounted."
                    log_debug "Failed to install ntfs-3g using apt"
                    whiptail --msgbox "Failed to install ntfs-3g using apt. NTFS drives cannot be mounted." 8 60
                    return 1
                fi
            elif command -v apt-get &> /dev/null; then
                print_info "apt not found, falling back to apt-get for ntfs-3g installation."
                log_debug "Falling back to apt-get for ntfs-3g"
                if ! apt-get update || ! apt-get install -y ntfs-3g; then
                    print_error "Failed to install ntfs-3g using apt-get. NTFS drives cannot be mounted."
                    log_debug "Failed to install ntfs-3g using apt-get"
                    whiptail --msgbox "Failed to install ntfs-3g using apt-get. NTFS drives cannot be mounted." 8 60
                    return 1
                fi
            else
                print_error "Neither apt nor apt-get found. Cannot install ntfs-3g. Please install manually."
                log_debug "Neither apt nor apt-get found for ntfs-3g"
                whiptail --msgbox "Neither apt nor apt-get found. Cannot install ntfs-3g. Please install manually." 8 60
                return 1
            fi
            print_success "Successfully installed ntfs-3g."
            log_debug "Successfully installed ntfs-3g"
        else
            print_error "NTFS-3g is not installed. NTFS drives cannot be mounted."
            log_debug "User declined to install ntfs-3g"
            whiptail --msgbox "NTFS-3g is not installed. NTFS drives cannot be mounted." 8 60
            return 1
        fi
    else
        print_info "NTFS-3g is already installed."
        log_debug "NTFS-3g already installed"
    fi
    return 0
}

# Function to detect external drives (partitions like sdb1)
detect_drives() {
    print_info "Detecting drives..."
    printf "[presto_usbMount] ${BLUE}INFO${RESET} Detecting drives..." >&2
    log_debug "Starting device rescan"
    # Rescan devices to clear stale partitions
    if command -v partprobe &> /dev/null; then
        partprobe /dev/sd* 2>> "$DEBUG_LOG"
        log_debug "Ran partprobe on /dev/sd*"
    else
        print_info "partprobe not found, falling back to manual rescan."
        log_debug "partprobe not found, using manual rescan"
        for block in /sys/block/sd*; do
            if [ -e "$block/device/rescan" ]; then
                echo 1 > "$block/device/rescan" 2>> "$DEBUG_LOG"
                log_debug "Rescanned device: $block"
            fi
        done
    fi
    drives=""
    for attempt in {1..3}; do
        printf "." >&2
        lsblk_output=$(lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MODEL -p 2>/dev/null)
        blkid_output=$(blkid 2>/dev/null)
        log_debug "Attempt $attempt: lsblk output: $lsblk_output"
        log_debug "Attempt $attempt: blkid output: $blkid_output"
        drives=""
        # Check if sda/sdb disks exist
        if lsblk -n -o NAME -p -d | grep -q '/dev/sd[a-z]'; then
            if command -v jq &> /dev/null; then
                drives=$(lsblk -J -o NAME,SIZE,FSTYPE,LABEL,MODEL -p 2>/dev/null | jq -r '.blockdevices[] | select(.name | test("/dev/sd[a-z]")) | .children[]? | .name as $name | .size as $size | .fstype as $fstype | .label as $label | .model as $model | [$name, ($size // "Unknown"), ($fstype // "No Filesystem"), ($label // "No Label"), ($model // "Unknown Model")] | @tsv' | while IFS=$'\t' read -r name size fstype label model; do
                    if [ -b "$name" ]; then
                        blkid_fstype=$(blkid -s TYPE -o value "$name" 2>/dev/null || echo "No Filesystem")
                        blkid_label=$(blkid -s LABEL -o value "$name" 2>/dev/null || echo "No Label")
                        blkid_model=$(lsblk -n -o MODEL -p "$name" | head -n 1 | tr -d ' \t' || echo "Unknown Model")
                        if [[ "$blkid_fstype" =~ ^(ntfs|ntfs3)$ ]]; then
                            blkid_fstype="ntfs"
                        fi
                        display_fstype=${blkid_fstype:-${fstype:-No Filesystem}}
                        display_label=${blkid_label:-${label:-No Label}}
                        display_model=${blkid_model:-${model:-Unknown Model}}
                        display_size=${size:-Unknown}
                        clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9\/]//g')
                        clean_desc="$clean_name $display_size $display_fstype \"$display_label\" \"$display_model\""
                        term_desc="└─$clean_name ($display_model, $display_size, $display_fstype, $display_label)"
                        log_debug "Detected drive: $term_desc"
                        echo "$clean_name \"$clean_desc\" \"$term_desc\""
                    fi
                done)
            else
                drives=$(lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MODEL -p | grep -E '/dev/sd[a-z][0-9]+' | while read -r name size fstype label model; do
                    if [ -b "$name" ]; then
                        blkid_fstype=$(blkid -s TYPE -o value "$name" 2>/dev/null || echo "No Filesystem")
                        blkid_label=$(blkid -s LABEL -o value "$name" 2>/dev/null || echo "No Label")
                        blkid_model=$(lsblk -n -o MODEL -p "$name" | head -n 1 | tr -d ' \t' || echo "Unknown Model")
                        if [[ "$blkid_fstype" =~ ^(ntfs|ntfs3)$ ]]; then
                            blkid_fstype="ntfs"
                        fi
                        display_fstype=${blkid_fstype:-${fstype:-No Filesystem}}
                        display_label=${blkid_label:-${label:-No Label}}
                        display_model=${blkid_model:-${model:-Unknown Model}}
                        display_size=${size:-Unknown}
                        clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9\/]//g')
                        clean_desc="$clean_name $display_size $display_fstype \"$display_label\" \"$display_model\""
                        term_desc="└─$clean_name ($display_model, $display_size, $display_fstype, $display_label)"
                        log_debug "Detected drive: $term_desc"
                        echo "$clean_name \"$clean_desc\" \"$term_desc\""
                    fi
                done)
            fi
            # Break if drives are found
            [ -n "$drives" ] && break
            if [ "$VERBOSE" = true ]; then
                print_info "No drives detected on attempt $attempt. Retrying..."
            fi
            log_debug "No drives detected on attempt $attempt"
            sleep 2
        else
            if [ "$VERBOSE" = true ]; then
                print_info "No external disks detected on attempt $attempt."
            fi
            log_debug "No external disks detected by lsblk -d on attempt $attempt"
            sleep 2
        fi
    done
    # Clear progress dots
    printf "\r\033[K" >&2
    # Fallback to blkid if lsblk finds no partitions
    if [ -z "$drives" ]; then
        log_debug "No partitions found by lsblk after retries, attempting blkid fallback"
        drives=$(blkid -o device | grep -E '/dev/sd[a-z][0-9]+' | while read -r name; do
            if [ -b "$name" ]; then
                blkid_fstype=$(blkid -s TYPE -o value "$name" 2>/dev/null || echo "No Filesystem")
                blkid_label=$(blkid -s LABEL -o value "$name" 2>/dev/null || echo "No Label")
                blkid_model=$(lsblk -n -o MODEL -p "$name" | head -n 1 | tr -d ' \t' || echo "Unknown Model")
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
                display_model=${blkid_model:-${model:-Unknown Model}}
                display_size=${size:-Unknown}
                clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9\/]//g')
                clean_desc="$clean_name $display_size $display_fstype \"$display_label\" \"$display_model\""
                term_desc="└─$clean_name ($display_model, $display_size, $display_fstype, $display_label)"
                log_debug "Detected drive (blkid fallback): $term_desc"
                echo "$clean_name \"$clean_desc\" \"$term_desc\""
            fi
        done)
    fi
    if [ -n "$drives" ]; then
        print_info "Drives detected:"
    else
        print_error "No external drive partitions detected after retries and blkid fallback. Please connect a drive."
        whiptail --msgbox "No external drive partitions detected after retries and blkid fallback. Please connect a drive and try again." 8 60
        log_debug "No external drive partitions detected after retries and blkid."
        exit 1
    fi
    log_debug "Final drives output: $drives"
    echo "$drives"
}

# Function to get filesystem type and PARTUUID (fallback to UUID if PARTUUID unavailable)
get_drive_info() {
    local drive=$1
    partuuid=$(blkid -s PARTUUID -o value "$drive" 2>/dev/null)
    fstype=$(blkid -s TYPE -o value "$drive" 2>/dev/null)
    log_debug "Drive $drive: PARTUUID=$partuuid, FSTYPE=$fstype"
    if [ -z "$partuuid" ]; then
        log_debug "PARTUUID not found for $drive, attempting to use UUID"
        partuuid=$(blkid -s UUID -o value "$drive" 2>/dev/null)
        if [ -z "$partuuid" ] || [ -z "$fstype" ]; then
            print_error "Failed to retrieve PARTUUID or filesystem type for $drive"
            whiptail --msgbox "Failed to retrieve PARTUUID or filesystem type for $drive." 8 60
            log_debug "Failed to retrieve PARTUUID or fstype for $drive"
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
        print_error "Drive with $id_type $id_value is already in /etc/fstab."
        whiptail --msgbox "Drive with $id_type $id_value is always in /etc/fstab. Please select a different drive or remove the existing entry manually." 8 60
        log_debug "Duplicate $id_type found in fstab: $id_value"
        exit 1
    fi
}

# Function to validate filesystem
validate_filesystem() {
    local fstype=$1
    local drive=$2
    if [[ "$fstype" != "ext4" && "$fstype" != "ntfs" && "$fstype" != "ntfs3" ]]; then
        print_error "Unsupported filesystem: $fstype on $drive. Only ext4 and NTFS are supported."
        whiptail --msgbox "Unsupported filesystem: $fstype on $drive. Only ext4 and NTFS are supported." 8 60
        log_debug "Unsupported filesystem: $fstype on $drive"
        exit 1
    fi
    if [[ "$fstype" == "ntfs" || "$fstype" == "ntfs3" ]]; then
        prompt_install_ntfs3g || {
            print_error "Cannot proceed with NTFS drive without ntfs-3g."
            log_debug "Cannot proceed with NTFS drive without ntfs-3g"
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
            print_info "Checking filesystem on $drive..."
            log_debug "Running fsck on $drive"
            timeout 300 fsck -f -y "$drive" >> "$DEBUG_LOG" 2>&1 || {
                print_error "Filesystem check failed or timed out on $drive. Please manually repair with 'fsck $drive'."
                whiptail --msgbox "Filesystem check failed or timed out on $drive. Please manually repair with 'fsck $drive'." 8 60
                log_debug "Filesystem check failed or timed out on $drive"
                exit 1
            }
            print_success "Filesystem check completed on $drive."
            log_debug "Filesystem check completed on $drive"
        else
            print_info "Skipping filesystem check on $drive."
            log_debug "Skipping filesystem check on $drive"
        fi
    elif [[ "$fstype" == "ntfs" || "$fstype" == "ntfs3" ]] && command -v ntfsfix >/dev/null 2>&1; then
        if whiptail --yesno "Run filesystem check (ntfsfix) on $drive before mounting? Recommended for new or potentially faulty drives." 8 60; then
            print_info "Checking NTFS filesystem on $drive..."
            log_debug "Running ntfsfix on $drive"
            timeout 300 ntfsfix -n "$drive" >> "$DEBUG_LOG" 2>&1 || {
                print_error "NTFS filesystem check failed or timed out on $drive. Please manually repair with 'ntfsfix $drive'."
                whiptail --msgbox "NTFS filesystem check failed or timed out on $drive. Please manually repair with 'ntfsfix $drive'." 8 60
                log_debug "NTFS filesystem check failed or timed out on $drive"
                exit 1
            }
            print_success "NTFS filesystem check completed on $drive."
            log_debug "NTFS filesystem check completed on $drive"
        else
            print_info "Skipping NTFS filesystem check on $drive."
            log_debug "Skipping NTFS filesystem check on $drive"
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
        print_error "Mount point $mount_point does not exist."
        log_debug "Mount point $mount_point does not exist"
        return 1
    fi
    if [ "$fstype" = "ext4" ]; then
        mount_fstype="ext4"
    else
        mount_fstype="ntfs-3g"
    fi
    print_info "Testing mount of $drive on $mount_point..."
    log_debug "Testing mount: mount -t $mount_fstype $drive $mount_point -o $options"
    if timeout 60 mount -t "$mount_fstype" "$drive" "$mount_point" -o "$options" >> "$DEBUG_LOG" 2>&1; then
        print_success "Test mount successful."
        log_debug "Test mount successful for $drive"
        for attempt in {1..3}; do
            timeout 10 umount "$mount_point" >> "$DEBUG_LOG" 2>&1 && {
                print_info "Unmounted $mount_point after test."
                log_debug "Unmounted $mount_point after test"
                break
            }
            print_error "Failed to unmount $mount_point (attempt $attempt/3). Retrying..."
            log_debug "Failed to unmount $mount_point (attempt $attempt/3)"
            sleep 1
        done
        if mount | grep -q "$mount_point"; then
            print_error "Failed to unmount $mount_point after 3 attempts."
            log_debug "Failed to unmount $mount_point after 3 attempts"
            return 1
        fi
    else
        print_error "Test mount failed for $drive. Check $DEBUG_LOG for details."
        whiptail --msgbox "Test mount failed for $drive. Check $DEBUG_LOG for details." 8 60
        log_debug "Test mount failed for $drive"
        return 1
    fi
    return 0
}

# Function to validate mount point name and handle existing mount points
validate_mount_name() {
    local name=$1
    local mount_point="/media/$name"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Mount name '$name' contains invalid characters. Use only letters, numbers, underscores, or hyphens."
        whiptail --msgbox "Mount name '$name' contains invalid characters.\nUse only letters, numbers, underscores, or hyphens." 10 60
        log_debug "Invalid mount name: $name"
        return 1
    fi
    if [ -d "$mount_point" ]; then
        print_info "Mount point '$mount_point' already exists."
        log_debug "Mount point '$mount_point' already exists"
        if mount | grep -q "$mount_point"; then
            if whiptail --yesno "Mount point '$mount_point' is currently mounted. Unmount and remove it?" 8 60; then
                timeout 10 umount "$mount_point" >> "$DEBUG_LOG" 2>&1 || {
                    print_error "Failed to unmount $mount_point."
                    whiptail --msgbox "Failed to unmount $mount_point." 8 60
                    log_debug "Failed to unmount $mount_point"
                    return 1
                }
                rmdir "$mount_point" >> "$DEBUG_LOG" 2>&1 || {
                    print_error "Failed to remove $mount_point."
                    whiptail --msgbox "Failed to remove $mount_point." 8 60
                    log_debug "Failed to remove $mount_point"
                    return 1
                }
                print_success "Removed existing mount point $mount_point."
                log_debug "Removed existing mount point $mount_point"
            else
                print_error "Cannot proceed with existing mount point. Please choose a different name or manually remove $mount_point."
                whiptail --msgbox "Cannot proceed with existing mount point. Please choose a different name or manually remove $mount_point." 10 60
                log_debug "User declined to remove mounted $mount_point"
                return 1
            fi
        else
            if whiptail --yesno "Mount point '$mount_point' exists but is not mounted. Remove it?" 8 60; then
                rmdir "$mount_point" >> "$DEBUG_LOG" 2>&1 || {
                    print_error "Failed to remove $mount_point."
                    whiptail --msgbox "Failed to remove $mount_point." 8 60
                    log_debug "Failed to remove $mount_point"
                    return 1
                }
                print_success "Removed existing mount point $mount_point."
                log_debug "Removed existing mount point $mount_point"
            else
                print_error "Cannot proceed with existing mount point. Please choose a different name or manually remove $mount_point."
                whiptail --msgbox "Cannot proceed with existing mount point. Please choose a different name or manually remove $mount_point." 10 60
                log_debug "User declined to remove unmounted $mount_point"
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
        print_error "Failed to create mount point $mount_point"
        whiptail --msgbox "Failed to create mount point $mount_point." 8 60
        log_debug "Failed to create mount point: $mount_point"
        exit 1
    }
    chmod 755 "$mount_point"
    chown root:root "$mount_point" || {
        print_error "Failed to set ownership on $mount_point to root:root"
        log_debug "Failed to set ownership on $mount_point to root:root"
        exit 1
    }
    print_success "Created mount point: $mount_point"
    log_debug "Created mount point: $mount_point"
    printf "%s" "$mount_point"
}

# Function to prompt for UID and GID (only for NTFS)
prompt_uid_gid() {
    local uid gid
    uid=$(whiptail --inputbox "Enter UID for the mount (default: 1000, typical for Docker and Raspberry Pi user 'pi'):" 8 60 1000 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ -z "$uid" ]; then
        print_info "No UID provided, using default 1000."
        log_debug "No UID provided, using default 1000"
        uid=1000
    fi
    gid=$(whiptail --inputbox "Enter GID for the mount (default: 1000, typical for Docker and Raspberry Pi user 'pi'):" 8 60 1000 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ -z "$gid" ]; then
        print_info "No GID provided, using default 1000."
        log_debug "No GID provided, using default 1000"
        gid=1000
    fi
    if ! [[ "$uid" =~ ^[0-9]+$ ]] || ! [[ "$gid" =~ ^[0-9]+$ ]]; then
        print_error "Invalid UID or GID. Must be numeric."
        whiptail --msgbox "Invalid UID or GID. Must be numeric." 8 60
        log_debug "Invalid UID or GID: uid=$uid, gid=$gid"
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
            print_info "No fstab option selected. Using Safe for ext4."
            log_debug "No fstab option selected, defaulting to Safe for ext4"
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
            print_info "No fstab option selected. Using Safe for NTFS."
            log_debug "No fstab option selected, defaulting to Safe for NTFS"
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
        log_debug "Filesystem check: $mount_point has $file_count top-level entries, size $size KB"
        if [ "$file_count" -gt 1000 ] || [ "$size" -gt 1000000 ]; then
            print_info "Warning: Large filesystem detected ($file_count files, $size KB). Recursive permission changes may take significant time."
            log_debug "Large filesystem warning: $file_count files, $size KB"
            return 1
        fi
    else
        log_debug "Cannot check filesystem size: $mount_point not mounted"
    fi
    return 0
}

# Function to set permissions for ext4 mounts
set_permissions() {
    local mount_point=$1
    local uid=$2
    local gid=$3
    local recursive=false
    print_info "Setting permissions on $mount_point..."
    log_debug "Checking filesystem size before setting permissions"
    if check_filesystem_size "$mount_point"; then
        recursive=false
    else
        if whiptail --yesno "Large filesystem detected at $mount_point.\nApply permissions recursively to all files (may take a long time)?\nChoose 'No' to set permissions only on the mount point directory." 10 60; then
            recursive=true
            print_info "User chose to apply permissions recursively."
            log_debug "User chose recursive permissions"
        else
            recursive=false
            print_info "Applying permissions only to mount point directory."
            log_debug "Applying non-recursive permissions"
        fi
    fi
    if [ "$recursive" = true ]; then
        log_debug "Starting chmod -R 777 $mount_point"
        print_info "Applying recursive permissions (this may take a while)..."
        timeout --signal=KILL 600 nice -n 10 ionice -c3 chmod -R 777 "$mount_point" >> "$DEBUG_LOG" 2>&1 || {
            print_error "Failed or timed out setting recursive permissions on $mount_point"
            whiptail --msgbox "Failed or timed out setting recursive permissions on $mount_point." 8 60
            log_debug "Failed or timed out setting recursive permissions on $mount_point"
            exit 1
        }
        log_debug "Completed chmod -R 777 $mount_point"
        log_debug "Starting chown -R $uid:$gid $mount_point"
        timeout --signal=KILL 600 nice -n 10 ionice -c3 chown -R "$uid:$gid" "$mount_point" >> "$DEBUG_LOG" 2>&1 || {
            print_error "Failed or timed out setting recursive ownership on $mount_point"
            whiptail --msgbox "Failed or timed out setting recursive ownership on $mount_point." 8 60
            log_debug "Failed or timed out setting recursive ownership on $mount_point"
            exit 1
        }
        log_debug "Completed chown -R $uid:$gid $mount_point"
    else
        log_debug "Starting chmod 777 $mount_point"
        timeout --signal=KILL 60 nice -n 10 ionice -c3 chmod 777 "$mount_point" >> "$DEBUG_LOG" 2>&1 || {
            print_error "Failed or timed out setting permissions on $mount_point"
            whiptail --msgbox "Failed or timed out setting permissions on $mount_point." 8 60
            log_debug "Failed or timed out setting permissions on $mount_point"
            exit 1
        }
        log_debug "Completed chmod 777 $mount_point"
        log_debug "Starting chown $uid:$gid $mount_point"
        timeout --signal=KILL 60 nice -n 10 ionice -c3 chown "$uid:$gid" "$mount_point" >> "$DEBUG_LOG" 2>&1 || {
            print_error "Failed or timed out setting ownership on $mount_point"
            whiptail --msgbox "Failed or timed out setting ownership on $mount_point." 8 60
            log_debug "Failed or timed out setting ownership on $mount_point"
            exit 1
        }
        log_debug "Completed chown $uid:$gid $mount_point"
    fi
    print_success "Set permissions and ownership on $mount_point (uid=$uid, gid=$gid)"
    log_debug "Set permissions and ownership on $mount_point (uid=$uid, gid=$gid)"
    final_perms=$(ls -ld "$mount_point" | awk '{print $1, $3, $4}')
    log_debug "Final permissions on $mount_point: $final_perms"
}

# Function to test Docker compatibility
test_docker_compatibility() {
    local mount_point=$1
    if command -v docker &> /dev/null; then
        print_info "Testing Docker compatibility for $mount_point..."
        log_debug "Testing Docker compatibility for $mount_point"
        if mountpoint -q "$mount_point"; then
            if docker run --rm -v "$mount_point:/mnt" alpine sh -c "touch /mnt/testfile && rm /mnt/testfile" >> "$DEBUG_LOG" 2>&1; then
                print_success "Docker can access $mount_point."
                log_debug "Docker compatibility test passed for $mount_point"
            else
                print_error "Docker cannot access $mount_point. Check SELinux/AppArmor or permissions."
                whiptail --msgbox "Docker cannot access $mount_point. Check SELinux/AppArmor or permissions." 8 60
                log_debug "Docker compatibility test failed for $mount_point"
                return 1
            fi
        else
            print_error "Cannot test Docker compatibility: $mount_point is not mounted."
            log_debug "Cannot test Docker compatibility: $mount_point not mounted"
            return 1
        fi
    else
        print_info "Docker not installed, skipping compatibility test."
        log_debug "Docker not installed, skipping compatibility test"
    fi
    return 0
}

# Function to clean up failed fstab entries
cleanup_fstab() {
    local mount_point=$1
    local id_entry=$2
    if grep -q "$id_entry" /etc/fstab; then
        print_info "Removing failed fstab entry for $id_entry..."
        log_debug "Removing fstab entry: $id_entry"
        sed -i.bak "/$id_entry/d" /etc/fstab || {
            print_error "Failed to remove fstab entry for $id_entry."
            log_debug "Failed to remove fstab entry for $id_entry"
        }
        print_success "Removed failed fstab entry."
        log_debug "Removed failed fstab entry"
    fi
    if [ -d "$mount_point" ] && ! mountpoint -q "$mount_point"; then
        rmdir "$mount_point" >> "$DEBUG_LOG" 2>&1 || {
            print_error "Failed to remove mount point $mount_point."
            log_debug "Failed to remove mount point $mount_point"
        }
    fi
}

# Fallback text-based prompt if whiptail fails
text_prompt() {
    local drives=$1
    print_info "Whiptail failed. Using text-based prompt."
    log_debug "Whiptail failed, switching to text-based prompt"
    echo "[presto_usbMount] Available drives:"
    echo "$drives" | while read -r name _ term_desc; do echo "[presto_usbMount] $term_desc"; done
    echo -n "[presto_usbMount] Enter the drive path (e.g., /dev/sdb1): "
    read -t 30 -r drive_choice
    if [ $? -ne 0 ] || [ -z "$drive_choice" ] || ! echo "$drives" | grep -q "^$drive_choice "; then
        print_error "Invalid or no drive selected in text prompt."
        log_debug "Invalid drive selected in text prompt: $drive_choice"
        exit 1
    fi
    echo "$drive_choice"
}

# Main logic
print_info "Detecting external drive partitions..."
log_debug "Starting drive detection"
drives=$(detect_drives)
if [ -z "$drives" ]; then
    print_error "No drives detected after processing."
    log_debug "No drives detected after processing"
    exit 1
fi
print_info "Available drives:"
echo "$drives" | while read -r name _ term_desc; do echo "[presto_usbMount] $term_desc"; done
log_debug "Processed drives for whiptail: $(echo "$drives" | awk '{print $1 " " $2}')"

whiptail_args=$(echo "$drives" | awk '{print $1 " " $2}')
if [ -z "$whiptail_args" ]; then
    print_error "Failed to generate valid whiptail arguments. Check drive detection."
    log_debug "Whiptail arguments empty: $whiptail_args"
    exit 1
fi
log_debug "Running whiptail for drive selection: whiptail --title 'Select External Drive Partition' --menu 'Choose the drive partition to mount (ext4 or NTFS only):' 15 80 4 $whiptail_args"

drive_choice=$(whiptail --title "Select External Drive Partition" --menu "Choose the drive partition to mount (ext4 or NTFS only):" 15 80 4 $whiptail_args 3>&1 1>&2 2>&3)
whiptail_exit=$?
log_debug "Whiptail exit code: $whiptail_exit, Selected: $drive_choice"

if [ $whiptail_exit -eq 1 ] && [ -z "$drive_choice" ]; then
    print_error "Operation cancelled by user during drive selection."
    log_debug "User cancelled whiptail drive selection (exit code 1, no drive chosen)"
    exit 1
elif [ $whiptail_exit -ne 0 ] || [ -z "$drive_choice" ]; then
    print_info "Whiptail failed with exit code $whiptail_exit. Falling back to text-based prompt."
    drive_choice=$(text_prompt "$drives")
fi

drive_name="$drive_choice"
print_info "Selected drive: $drive_name"
log_debug "Selected drive: $drive_name"

# Check if drive is already mounted elsewhere
if mount | grep -q "$drive_name"; then
    current_mount=$(mount | grep "$drive_name" | awk '{print $3}')
    print_error "Drive $drive_name is already mounted at $current_mount."
    if whiptail --yesno "Drive $drive_name is already mounted at $current_mount. Unmount it to proceed?" 8 60; then
        timeout 10 umount "$drive_name" >> "$DEBUG_LOG" 2>&1 || {
            print_error "Failed to unmount $drive_name from $current_mount."
            whiptail --msgbox "Failed to unmount $drive_name from $current_mount." 8 60
            log_debug "Failed to unmount $drive_name from $current_mount"
            exit 1
        }
        print_success "Unmounted $drive_name from $current_mount."
        log_debug "Unmounted $drive_name from $current_mount"
    else
        print_error "Cannot proceed with drive already mounted."
        whiptail --msgbox "Cannot proceed with drive already mounted at $current_mount." 8 60
        log_debug "User declined to unmount $drive_name from $current_mount"
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
print_info "Drive details: $drive_info"
log_debug "Drive details: $drive_info"
if ! whiptail --yesno "Selected drive:\n$(strip_ansi_codes "$drive_info")\n\nIs this the correct drive to add to /etc/fstab?" 12 60; then
    if [ $? -ne 0 ]; then
        print_info "Whiptail failed for confirmation. Using text-based prompt."
        echo "[presto_usbMount] Selected drive: $drive_info"
        echo -n "[presto_usbMount] Is this the correct drive to add to /etc/fstab? (y/n): "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_error "Operation cancelled by user."
            log_debug "Operation cancelled by user"
            exit 1
        fi
    else
        print_error "Operation cancelled by user."
        log_debug "Operation cancelled by user"
        exit 1
    fi
fi

if [[ "$fstype" == "ntfs" || "$fstype" == "ntfs3" ]]; then
    read uid gid < <(prompt_uid_gid)
    print_info "Using UID: $uid, GID: $gid"
    log_debug "Selected UID: $uid, GID: $gid"
else
    uid=0
    gid=0
    print_info "Using default UID: 0, GID: 0 for ext4"
    log_debug "Using default UID: 0, GID: 0 for ext4"
fi

while true; do
    mount_name=$(whiptail --inputbox "Enter a name for the mount point (letters, numbers, underscores, or hyphens only, e.g., PRESTO_MEDIA_2TB):" 8 60 PRESTO_MEDIA_2TB 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ -z "$mount_name" ]; then
        print_info "Whiptail failed or no mount name provided. Using text-based prompt."
        echo -n "[presto_usbMount] Enter a name for the mount point (letters, numbers, underscores, or hyphens only, e.g., PRESTO_MEDIA_2TB): "
        read -r mount_name
        if [ -z "$mount_name" ]; then
            print_error "No mount name provided."
            log_debug "No mount name provided"
            exit 1
        fi
    fi
    if validate_mount_name "$mount_name"; then
        break
    fi
done

mount_point=$(create_mount_point "$mount_name")
if [ ! -d "$mount_point" ]; then
    print_error "Failed to create or verify mount point $mount_point"
    whiptail --msgbox "Failed to create or verify mount point $mount_point." 8 60
    log_debug "Failed to verify mount point: $mount_point"
    exit 1
fi

fstab_entry=$(prompt_fstab_options "$fstype" "$id_entry" "$mount_point" "$uid" "$gid")
print_info "Selected fstab entry: $fstab_entry"
log_debug "Selected fstab entry: $fstab_entry"

fstype=$(echo "$fstab_entry" | awk '{print $3}')
options=$(echo "$fstab_entry" | awk '{print $4}')

test_mount "$drive_name" "$mount_point" "$fstype" "$uid" "$gid" "$options" || {
    cleanup_fstab "$mount_point" "$id_entry"
    exit 1
}

if ! whiptail --yesno "Proposed /etc/fstab entry:\n$(strip_ansi_codes "$fstab_entry")\n\nAdd this to /etc/fstab?" 10 80; then
    if [ $? -ne 0 ]; then
        print_info "Whiptail failed for fstab confirmation. Using text-based prompt."
        echo "[presto_usbMount] Proposed fstab entry: $fstab_entry"
        echo -n "[presto_usbMount] Add this to /etc/fstab? (y/n): "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_error "Operation cancelled by user."
            cleanup_fstab "$mount_point" "$id_entry"
            log_debug "Operation cancelled by user"
            exit 1
        fi
    else
        print_error "Operation cancelled by user."
        cleanup_fstab "$mount_point" "$id_entry"
        log_debug "Operation cancelled by user"
        exit 1
    fi
fi

cp /etc/fstab /etc/fstab.bak || {
    print_error "Failed to backup /etc/fstab"
    whiptail --msgbox "Failed to backup /etc/fstab." 8 60
    cleanup_fstab "$mount_point" "$id_entry"
    log_debug "Failed to backup /etc/fstab"
    exit 1
}

echo "$fstab_entry" >> /etc/fstab

if mount | grep -q "$mount_point"; then
    print_info "Drive is already mounted at $mount_point. Skipping mount -a."
    log_debug "Drive already mounted at $mount_point"
else
    log_debug "Running mount -a -v"
    if mount -a -v >> "$DEBUG_LOG" 2>&1; then
        print_success "Mount successful via mount -a."
        log_debug "Mount successful via mount -a"
    else
        log_debug "mount -a returned non-zero exit code. Checking mount status."
        if mount | grep -q "$mount_point"; then
            print_success "Mount appears successful despite mount -a error. Proceeding."
            log_debug "Mount succeeded despite mount -a error"
        else
            print_error "Failed to mount drive. Restoring original fstab. Check $DEBUG_LOG for details."
            whiptail --msgbox "Failed to mount drive. Restoring original fstab. Check $DEBUG_LOG for details." 8 60
            mv /etc/fstab.bak /etc/fstab
            cleanup_fstab "$mount_point" "$id_entry"
            log_debug "Failed to mount drive. Restored fstab."
            exit 1
        fi
    fi
fi

if [ "$fstype" = "ext4" ]; then
    set_permissions "$mount_point" "$uid" "$gid"
fi

test_docker_compatibility "$mount_point" || {
    print_error "Docker compatibility test failed. Mount may not work with Docker containers."
    whiptail --msgbox "Docker compatibility test failed. Mount may not work with Docker containers." 8 60
    log_debug "Docker compatibility test failed for $mount_point"
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
    log_debug "Displaying final summary with whiptail"
    whiptail --msgbox "$(strip_ansi_codes "$summary")" 16 80
    log_debug "Success: $summary"
else
    print_error "Drive is not mounted at $mount_point. Check $DEBUG_LOG for details."
    whiptail --msgbox "Drive is not mounted at $mount_point. Check $DEBUG_LOG for details." 8 60
    mv /etc/fstab.bak /etc/fstab
    cleanup_fstab "$mount_point" "$id_entry"
    log_debug "Drive not mounted. Restored fstab."
    exit 1
fi

rm -f /etc/fstab.bak
print_success "Cleaned up fstab backup"
log_debug "Cleaned up fstab backup"
