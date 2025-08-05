#!/bin/bash
# ────────────────────────────────────────────────────────────────────────────
# Docker Container Status Script
# Version: 2.0
# Author: piklz
# GitHub: https://github.com/piklz
#
# Usage:
#   ./presto_docker_monitor.sh           # Show full stats, running, and non-running containers
#   ./presto_docker_monitor.sh --running-apps  # List only running container names
#   ./presto_docker_monitor.sh --running-info  # List running containers with memory usage
#   ./presto_docker_monitor.sh --help          # Show this help message
# ────────────────────────────────────────────────────────────────────────────

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

# Function to create a stylish header
function print_header() {
    echo -e "${cyan}"
    printf "╭───────── ${white}Docker Container Monitor${no_col}${cyan} ───${white}${no_col}${cyan}────╮\n"
    echo -e "${no_col}"
}

# Function to print running container names
function print_running_containers() {
    echo -e "\n${white}Running Containers:${no_col}"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"

    # Get running container names
    local containers
    containers=$(docker ps --format '{{.Names}}')

    if [[ -z "$containers" ]]; then
        echo -e "${yellow}No running containers found.${no_col}"
    else
        # Print each container name
        while IFS= read -r name; do
            printf "${green}%s${no_col}\n" "$name"
        done <<< "$containers"
    fi
}

# Function to print non-running container names
function print_non_running_containers() {
    echo -e "\n${white}Non-Running Containers:${no_col}"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"

    # Get non-running container names (Created or Exited)
    local containers
    containers=$(docker container ls -a --filter "status=created" --filter "status=exited" --format '{{.Names}}')

    if [[ -z "$containers" ]]; then
        echo -e "${yellow}No non-running containers found.${no_col}"
    else
        # Print each container name in grey
        while IFS= read -r name; do
            printf "${grey}%s${no_col}\n" "$name"
        done <<< "$containers"
    fi
}

# Function to print running containers with memory usage
function print_running_info() {
    echo -e "\n${white}Running Containers Info:${no_col}"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"
    printf "${white}%-30s %-10s${no_col}\n" "Container Name" "Memory Used"

    # Get running container names and IDs
    local containers
    containers=$(docker ps --format '{{.ID}}\t{{.Names}}')

    if [[ -z "$containers" ]]; then
        echo -e "${yellow}No running containers found.${no_col}"
    else
        # Process each container
        while IFS=$'\t' read -r id name; do
            # Get memory usage from docker inspect
            local memory_usage
            memory_usage=$(docker inspect --format '{{.HostConfig.Memory}}' "$id")
            if [[ "$memory_usage" == "0" || -z "$memory_usage" ]]; then
                memory_usage="Unlimited"
            else
                # Convert bytes to human-readable format (MB/GB)
                if (( memory_usage >= 1073741824 )); then
                    memory_usage=$(awk "BEGIN {printf \"%.2f GB\", $memory_usage/1073741824}")
                else
                    memory_usage=$(awk "BEGIN {printf \"%.2f MB\", $memory_usage/1048576}")
                fi
            fi
            printf "${green}%-30s${no_col} ${cyan}%s${no_col}\n" "$name" "$memory_usage"
        done <<< "$containers"
    fi
}

# Function to print help message
function print_help() {
    echo -e "${white}Docker Container Monitor Usage:${no_col}"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"
    echo "Show Docker container statistics and status."
    echo ""
    echo -e "${white}Options:${no_col}"
    echo -e "  ${cyan}--running-apps${no_col}    List only running container names"
    echo -e "  ${cyan}--running-info${no_col}    List running containers with memory usage"
    echo -e "  ${cyan}--help${no_col}           Show this help message"
    echo ""
    echo -e "${white}Examples:${no_col}"
    echo "  ./presto_docker_monitor.sh              # Full stats and container lists"
    echo "  ./presto_docker_monitor.sh --running-apps  # Only running container names"
    echo "  ./presto_docker_monitor.sh --running-info  # Running containers with memory usage"
    echo "  ./presto_docker_monitor.sh --help         # Show this help"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"
}

# Function to print full stats
function print_full_stats() {
    # Calculate stats
    healthy=$(docker ps | grep -o 'healthy' | wc -l)
    unhealthy=$(docker ps | grep -o 'unhealthy' | wc -l)
    running=$(docker container ls -a | grep -o 'Up' | wc -l)
    created=$(docker container ls -a | grep -o 'Created' | wc -l)
    stopped=$(docker container ls -a | grep -o 'Exited' | wc -l)
    total=$(($running + $created + $stopped))

    # Print header
    print_header

    # Stylish stats table
    echo -e "${white}Docker Container Statistics:${no_col}"
    printf "%-20s: ${green}%s${no_col}\n" "Healthy" "$healthy"
    printf "%-20s: ${red}%s${no_col}\n" "Unhealthy" "$unhealthy"
    printf "%-20s: ${green}%s${no_col}\n" "Running" "$running"
    printf "%-20s: ${yellow}%s${no_col}\n" "Created" "$created"
    printf "%-20s: ${red}%s${no_col}\n" "Stopped" "$stopped"
    printf "%-20s: ${cyan}%s${no_col}\n" "Total Containers" "$total"

    # Print running container names
    print_running_containers

    # Print non-running container names
    print_non_running_containers

    # Suggest action based on stats
    if [[ $running -eq 0 ]]; then
        echo -e "\n${yellow}⚠️ No containers are currently running. Start your containers to monitor them.${no_col}"
    elif [[ $unhealthy -gt 0 ]]; then
        echo -e "\n${red}⚠️ Warning:${no_col} $unhealthy container(s) are unhealthy. Consider investigating."
    else
        echo -e "\n${green}✅ All containers are healthy.${no_col}"
    fi

    # Horizontal separator
    echo -e "${cyan}───────────────────────────────────────────${no_col}"

    # Add an optional banner or footer
    echo -e "Visit ${cyan}https://github.com/piklz${no_col} for updates!"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"
}

# Parse command-line arguments
case "$1" in
    --running-apps)
        print_running_containers
        exit 0
        ;;
    --running-info)
        print_running_info
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
        exit 1
        ;;
esac