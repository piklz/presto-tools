#!/bin/bash
# -----------------------------------------------
# Docker Container Status Script
# Version: 3.0.0
# Author: piklz
# GitHub: https://github.com/piklz
# Description:
#     This script provides a clean overview of Docker container health statistics,
#
# Changelog:
#   v3.0.0 (2025-08-26) - Added --help with systemd and debugging tips, and an updated header.
#   v2.9.0 - Initial release with various display options.
#
# Usage:
#     ./presto_docker_monitor.sh             # Show full stats, running containers with health/ports, and non-running containers
#     ./presto_docker_monitor.sh --running-apps # List running containers with health and ports
#     ./presto_docker_monitor.sh --simple        # List only running container names (minimal)
#     ./presto_docker_monitor.sh --warnings      # List unhealthy and starting containers with health and ports
#     ./presto_docker_monitor.sh --help          # Show this help message
# -----------------------------------------------

# Script Variables
SCRIPT_NAME="presto_docker_monitor.sh"
SCRIPT_VERSION="3.0.0"
JOURNAL_TAG="presto_docker_monitor"
DEBUG_MODE=false

# Colors for styling
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

# Function to send messages to the system journal with a specified priority
log_message() {
    local priority="$1"
    shift
    local message="$@"
    local journald_priority

    # Map script's custom priorities to journald's standard priorities
    case "$priority" in
        "error")
            journald_priority="err"
            ;;
        "warning")
            journald_priority="warning"
            ;;
        "info")
            journald_priority="info"
            ;;
        "debug")
            journald_priority="debug"
            if [ "$DEBUG_MODE" = false ]; then
                return
            fi
            ;;
        *)
            journald_priority="notice"
            ;;
    esac

    # Send message to systemd-journald
    echo "${message}" | systemd-cat -t "${JOURNAL_TAG}" --priority="${journald_priority}"
}

# Function to create a stylish header
function print_header() {
    echo -e "${cyan}"
    printf "╭───────── ${white}Docker Container Monitor${no_col}${cyan} ───${white}${no_col}${cyan}────╮\n"
    echo -e "${no_col}"
}

# Function to print running container names with health and ports
function print_running_containers() {
    log_message "info" "Action: Listing running containers."

    echo -e "\n${white}Running Containers:${no_col}         ${white}Health  Ports${no_col}"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"

    local containers
    containers=$(docker ps --format '{{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}')

    if [[ -z "$containers" ]]; then
        echo -e "${yellow}No running containers found.${no_col}"
        log_message "info" "Result: No running containers found."
    else
        while IFS=$'\t' read -r id name ports status; do
            if [[ ${#name} -gt 27 ]]; then
                name="${name:0:27}..."
            fi

            local port_display
            if [[ -z "$ports" ]]; then
                port_display="na"
            else
                port_display=$(echo "$ports" | grep -oE '[0-9]+->' | head -n1 | sed 's/->//')
                if [[ -z "$port_display" ]]; then
                    port_display=$(echo "$ports" | grep -oE '[0-9]+/tcp' | head -n1 | sed 's/\/tcp//')
                fi
                port_display=${port_display:-"na"}
                port_display=":$port_display"
            fi

            local health_emoji
            local health_color
            if [[ "$status" =~ \(healthy\) ]]; then
                health_emoji="✅"
                health_color="${green}"
            elif [[ "$status" =~ \(health:\ starting\) ]]; then
                health_emoji="⏳"
                health_color="${yellow}"
            else
                health_emoji="⚠️"
                health_color="${yellow}"
            fi

            printf "${green}%-30s${no_col} ${health_color}%1s${no_col} %6s\n" "$name" "$health_emoji" "$port_display"
        done <<< "$containers"
    fi
}

# Function to print non-running container names
function print_non_running_containers() {
    log_message "info" "Action: Listing non-running containers."

    echo -e "\n${white}Non-Running Containers:${no_col}"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"

    local containers
    containers=$(docker container ls -a --filter "status=created" --filter "status=exited" --format '{{.Names}}')

    if [[ -z "$containers" ]]; then
        echo -e "${yellow}No non-running containers found.${no_col}"
        log_message "info" "Result: No non-running containers found."
    else
        while IFS= read -r name; do
            printf "${grey}%s${no_col}\n" "$name"
        done <<< "$containers"
    fi
}

# Function to print only running container names (minimal)
function print_simple() {
    log_message "info" "Action: Printing simple list of running containers."

    local containers
    containers=$(docker ps --format '{{.Names}}')

    if [[ -z "$containers" ]]; then
        echo -e "${yellow}No running containers found.${no_col}"
        log_message "info" "Result: No running containers found."
    else
        while IFS= read -r name; do
            printf "${green}%s${no_col}\n" "$name"
        done <<< "$containers"
    fi
}

# Function to print unhealthy and starting containers with health and ports
function print_warnings() {
    log_message "warning" "Action: Listing unhealthy or starting containers."

    echo -e "\n${white}Unhealthy/Starting Containers:${no_col}     ${white}Health  Ports${no_col}"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"

    local containers
    containers=$(docker ps --format '{{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}' | grep -E '\((unhealthy|health: starting)\)')

    if [[ -z "$containers" ]]; then
        echo -e "${yellow}No unhealthy or starting containers found.${no_col}"
        log_message "info" "Result: No unhealthy or starting containers found."
    else
        while IFS=$'\t' read -r id name ports status; do
            if [[ ${#name} -gt 27 ]]; then
                name="${name:0:27}..."
            fi

            local port_display
            if [[ -z "$ports" ]]; then
                port_display="na"
            else
                port_display=$(echo "$ports" | grep -oE '[0-9]+->' | head -n1 | sed 's/->//')
                if [[ -z "$port_display" ]]; then
                    port_display=$(echo "$ports" | grep -oE '[0-9]+/tcp' | head -n1 | sed 's/\/tcp//')
                fi
                port_display=${port_display:-"na"}
                port_display=":$port_display"
            fi

            local health_emoji
            local health_color
            if [[ "$status" =~ \(health:\ starting\) ]]; then
                health_emoji="⏳"
                health_color="${yellow}"
            else
                health_emoji="⚠️"
                health_color="${yellow}"
            fi

            printf "${green}%-30s${no_col} ${health_color}%1s${no_col} %6s\n" "$name" "$health_emoji" "$port_display"
        done <<< "$containers"
    fi
}

# Function to print help message
function print_help() {
    log_message "info" "Action: Displaying help message."

    echo -e "${white}Docker Container Monitor${no_col} (${SCRIPT_NAME} v${SCRIPT_VERSION})"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"
    echo "Show Docker container statistics and status."
    echo ""
    echo -e "${white}Options:${no_col}"
    echo -e "  ${cyan}--running-apps${no_col}    List running containers with health and ports"
    echo -e "  ${cyan}--simple${no_col}          List only running container names (minimal)"
    echo -e "  ${cyan}--warnings${no_col}        List unhealthy and starting containers with health and ports"
    echo -e "  ${cyan}--help${no_col}            Show this help message"
    echo ""
    echo -e "${white}Examples:${no_col}"
    echo "  ./$SCRIPT_NAME                    # Full stats and container lists"
    echo "  ./$SCRIPT_NAME --running-apps    # Running containers with health and ports"
    echo "  ./$SCRIPT_NAME --simple          # Only running container names"
    echo "  ./$SCRIPT_NAME --warnings        # Unhealthy and starting containers with health and ports"
    echo "  ./$SCRIPT_NAME --help            # Show this help"
    echo ""
    echo -e "${white}Troubleshooting & Logging:${no_col}"
    echo "  To see all logs for this script and its output:"
    echo "    journalctl -t $JOURNAL_TAG"
    echo "  To follow the logs in real-time:"
    echo "    journalctl -t $JOURNAL_TAG -f"
    echo "  To view logs from the last 10 minutes:"
    echo "    journalctl -t $JOURNAL_TAG --since \"10 minutes ago\""
    echo -e "${cyan}───────────────────────────────────────────${no_col}"
    exit 0
}

# Function to print full stats
function print_full_stats() {
    log_message "info" "Action: Running full stats check."

    healthy=$(docker ps | grep -o 'healthy' | wc -l)
    unhealthy=$(docker ps | grep -o 'unhealthy' | wc -l)
    starting=$(docker ps | grep -o 'health: starting' | wc -l)
    running=$(docker container ls -a | grep -o 'Up' | wc -l)
    created=$(docker container ls -a | grep -o 'Created' | wc -l)
    stopped=$(docker container ls -a | grep -o 'Exited' | wc -l)
    total=$(($running + $created + $stopped))

    print_header

    echo -e "${white}Docker Container Statistics:${no_col}"
    printf "%-20s: ${green}%s${no_col}\n" "Healthy" "$healthy"
    printf "%-20s: ${red}%s${no_col}\n" "Unhealthy" "$unhealthy"
    printf "%-20s: ${yellow}%s${no_col}\n" "Starting" "$starting"
    printf "%-20s: ${green}%s${no_col}\n" "Running" "$running"
    printf "%-20s: ${yellow}%s${no_col}\n" "Created" "$created"
    printf "%-20s: ${red}%s${no_col}\n" "Stopped" "$stopped"
    printf "%-20s: ${cyan}%s${no_col}\n" "Total Containers" "$total"

    print_running_containers

    print_non_running_containers

    if [[ $running -eq 0 ]]; then
        echo -e "\n${yellow}⚠️ No containers are currently running. Start your containers to monitor them.${no_col}"
        log_message "warning" "Warning: No running containers."
    elif [[ $unhealthy -gt 0 || $starting -gt 0 ]]; then
        echo -e "\n${red}⚠️ Warning:${no_col} $unhealthy unhealthy and $starting starting container(s). Consider investigating."
        log_message "warning" "Warning: $unhealthy unhealthy and $starting starting containers."
    else
        echo -e "\n${green}✅ All containers are healthy.${no_col}"
        log_message "info" "Result: All containers are healthy."
    fi

    echo -e "${cyan}───────────────────────────────────────────${no_col}"

    echo -e "Visit ${cyan}https://github.com/piklz${no_col} for updates!"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"
}

# Parse command-line arguments
case "$1" in
    --running-apps)
        print_running_containers
        exit 0
        ;;
    --simple)
        print_simple
        exit 0
        ;;
    --warnings)
        print_warnings
        exit 0
        ;;
    --help)
        print_help
        exit 0
        ;;
    "")
        print_full_stats
        exit 0
        ;;
    *)
        echo -e "${red}Error: Unknown argument '$1'. Use --help for usage information.${no_col}"
        log_message "error" "Error: Unknown argument '$1'."
        exit 1
        ;;
esac