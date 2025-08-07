#!/bin/bash
# -----------------------------------------------
# Docker Container Status Script
# Version: 2.9
# Author: piklz
# GitHub: https://github.com/piklz
# Description:
#   This script provides a clean overview of Docker container health statistics,
# 
# Usage:
#   ./docker_stats.sh           # Show full stats, running containers with health/ports, and non-running containers
#   ./docker_stats.sh --running-apps  # List running containers with health and ports
#   ./docker_stats.sh --simple        # List only running container names (minimal)
#   ./docker_stats.sh --warnings      # List unhealthy and starting containers with health and ports
#   ./docker_stats.sh --help          # Show this help message
# -----------------------------------------------

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

# Function to print running container names with health and ports
function print_running_containers() {
    echo -e "\n${white}Running Containers:${no_col}         ${white}Health  Ports${no_col}"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"

    # Get running container names, ports, status, and IDs
    local containers
    containers=$(docker ps --format '{{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}')

    if [[ -z "$containers" ]]; then
        echo -e "${yellow}No running containers found.${no_col}"
    else
        # Process each container
        while IFS=$'\t' read -r id name ports status; do
            # Truncate name if longer than 27 characters
            if [[ ${#name} -gt 27 ]]; then
                name="${name:0:27}..."
            fi

            # Parse ports: extract external port or set to 'na'
            local port_display
            if [[ -z "$ports" ]]; then
                port_display="na"
            else
                # Extract first external port (e.g., 1000 from 0.0.0.0:1000->1000/tcp)
                port_display=$(echo "$ports" | grep -oE '[0-9]+->' | head -n1 | sed 's/->//')
                if [[ -z "$port_display" ]]; then
                    port_display=$(echo "$ports" | grep -oE '[0-9]+/tcp' | head -n1 | sed 's/\/tcp//')
                fi
                port_display=${port_display:-"na"}
                port_display=":$port_display"
            fi

            # Determine health status emoji
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

            # Print with fixed column widths
            printf "${green}%-30s${no_col} ${health_color}%1s${no_col} %6s\n" "$name" "$health_emoji" "$port_display"
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

# Function to print only running container names (minimal)
function print_simple() {
    # Get running container names
    local containers
    containers=$(docker ps --format '{{.Names}}')

    if [[ -z "$containers" ]]; then
        echo -e "${yellow}No running containers found.${no_col}"
    else
        # Print each container name in green
        while IFS= read -r name; do
            printf "${green}%s${no_col}\n" "$name"
        done <<< "$containers"
    fi
}

# Function to print unhealthy and starting containers with health and ports
function print_warnings() {
    echo -e "\n${white}Unhealthy/Starting Containers:${no_col}      ${white}Health  Ports${no_col}"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"

    # Get running container names, ports, status, and IDs
    local containers
    containers=$(docker ps --format '{{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}' | grep -E '\((unhealthy|health: starting)\)')

    if [[ -z "$containers" ]]; then
        echo -e "${yellow}No unhealthy or starting containers found.${no_col}"
    else
        # Process each unhealthy or starting container
        while IFS=$'\t' read -r id name ports status; do
            # Truncate name if longer than 27 characters
            if [[ ${#name} -gt 27 ]]; then
                name="${name:0:27}..."
            fi

            # Parse ports: extract external port or set to 'na'
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

            # Health emoji for unhealthy or starting
            local health_emoji
            local health_color
            if [[ "$status" =~ \(health:\ starting\) ]]; then
                health_emoji="⏳"
                health_color="${yellow}"
            else
                health_emoji="⚠️"
                health_color="${yellow}"
            fi

            # Print with fixed column widths
            printf "${green}%-30s${no_col} ${health_color}%1s${no_col} %6s\n" "$name" "$health_emoji" "$port_display"
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
    echo -e "  ${cyan}--running-apps${no_col}    List running containers with health and ports"
    echo -e "  ${cyan}--simple${no_col}          List only running container names (minimal)"
    echo -e "  ${cyan}--warnings${no_col}        List unhealthy and starting containers with health and ports"
    echo -e "  ${cyan}--help${no_col}           Show this help message"
    echo ""
    echo -e "${white}Examples:${no_col}"
    echo "  ./docker_stats.sh              # Full stats and container lists"
    echo "  ./docker_stats.sh --running-apps  # Running containers with health and ports"
    echo "  ./docker_stats.sh --simple       # Only running container names"
    echo "  ./docker_stats.sh --warnings     # Unhealthy and starting containers with health and ports"
    echo "  ./docker_stats.sh --help         # Show this help"
    echo -e "${cyan}───────────────────────────────────────────${no_col}"
}

# Function to print full stats
function print_full_stats() {
    # Calculate stats
    healthy=$(docker ps | grep -o 'healthy' | wc -l)
    unhealthy=$(docker ps | grep -o 'unhealthy' | wc -l)
    starting=$(docker ps | grep -o 'health: starting' | wc -l)
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
    printf "%-20s: ${yellow}%s${no_col}\n" "Starting" "$starting"
    printf "%-20s: ${green}%s${no_col}\n" "Running" "$running"
    printf "%-20s: ${yellow}%s${no_col}\n" "Created" "$created"
    printf "%-20s: ${red}%s${no_col}\n" "Stopped" "$stopped"
    printf "%-20s: ${cyan}%s${no_col}\n" "Total Containers" "$total"

    # Print running container names with health and ports
    print_running_containers

    # Print non-running container names
    print_non_running_containers

    # Suggest action based on stats
    if [[ $running -eq 0 ]]; then
        echo -e "\n${yellow}⚠️ No containers are currently running. Start your containers to monitor them.${no_col}"
    elif [[ $unhealthy -gt 0 || $starting -gt 0 ]]; then
        echo -e "\n${red}⚠️ Warning:${no_col} $unhealthy unhealthy and $starting starting container(s). Consider investigating."
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
        exit 1
        ;;
esac