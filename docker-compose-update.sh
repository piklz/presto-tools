#!/usr/bin/env bash

# ANSI color codes
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
DIM_GREEN='\033[2;32m'  # Dim green
RESET='\033[0m'

# Get current installed version (robust method - corrected field number)
CURRENT_VERSION=$(docker compose version 2>/dev/null | grep "Docker Compose version" | awk '{print $4}' | cut -c 2-)

# Get available version from GitHub (most robust method)
LATEST_TAG=$(curl -s "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4)
LATEST_VERSION="${LATEST_TAG#v}"
AVAILABLE_VERSION="$LATEST_VERSION"

echo -e "\n\e[32;1m${BLUE}Docker Compose Version Check\n \e[0m"

if [[ -n "$CURRENT_VERSION" ]]; then
  echo -e "${DIM_GREEN}Current   Version: v$CURRENT_VERSION${RESET}" # Dim green
else
  echo -e "\e[33;1m Docker Compose is not currently installed.\e[0m"
fi

echo -e "${GREEN}Available Version: v$AVAILABLE_VERSION${RESET}" # Always green for available

# Version comparison (robust with awk)
SMALLER_VERSION=$(awk -v current="$CURRENT_VERSION" -v latest="$LATEST_VERSION" '
BEGIN {
  split(current, current_parts, ".")
  split(latest, latest_parts, ".")
  len = length(current_parts)
  if (length(latest_parts) > len) { len = length(latest_parts) }
  for (i = 1; i <= len; i++) {
    current_part = (current_parts[i] == "" ? 0 : current_parts[i])
    latest_part = (latest_parts[i] == "" ? 0 : latest_parts[i])
    if (current_part < latest_part) { print latest; exit }
    if (current_part > latest_part) { print current; exit }
  }
  print current # If they are equal
}'
)

if [[ "$SMALLER_VERSION" != "$CURRENT_VERSION" ]]; then  # If the smaller version is not the current version
  echo -e "\e[33;1m A newer version of Docker Compose is available.\e[0m"
  read -p "Do you want to update Docker Compose? (y/N): " update_choice
  case "$update_choice" in
    y|Y)
      echo -e "\e[33;1m Updating Docker Compose...\e[0m"
      sudo apt install -y docker-compose-plugin
      if [[ $? -eq 0 ]]; then
          echo -e "\e[32;1m Docker Compose updated successfully!\e[0m"
          NEW_VERSION=$(docker compose version 2>/dev/null | grep "Docker Compose version" | awk '{print $4}' | cut -c 2-) # Refresh NEW_VERSION
          echo -e "${GREEN}New Version: v$NEW_VERSION${RESET}" # Green for updated version
      else
          echo -e "\e[31;1m Error updating Docker Compose.\e[0m"
      fi
      ;;
    *)
      echo -e "\e[33;1m Update cancelled.\e[0m"
      ;;
  esac
elif [[ -z "$CURRENT_VERSION" ]]; then  # If NOT installed
    read -p "Do you want to install Docker Compose? (y/N): " install_choice
    case "$install_choice" in
      y|Y)
        echo -e "\e[33;1m Installing Docker Compose...\e[0m"
        sudo apt install -y docker-compose-plugin
        if [[ $? -eq 0 ]]; then
            echo -e "\e[32;1m Docker Compose installed successfully!\e[0m"
            NEW_VERSION=$(docker compose version 2>/dev/null | grep "Docker Compose version" | awk '{print $4}' | cut -c 2-) # Refresh NEW_VERSION
            echo -e "${GREEN}New Version: v$NEW_VERSION${RESET}"
        else
            echo -e "\e[31;1m Error installing Docker Compose.\e[0m"
        fi
        ;;
      *)
        echo -e "\e[33;1m Installation cancelled.\e[0m"
        ;;
    esac
elif [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    echo -e "${GREEN}You are using the latest version of Docker Compose${RESET}"
fi