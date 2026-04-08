#!/usr/bin/env bash

#  __/\\\\\\\\\\\\\______/\\\\\\\\\______/\\\\\\\\\\\\\\\_____/\\\\\\\\\\\____/\\\\\\\\\\\\\\\_______/\\\\\______        
#   _\/\\\/////////\\\__/\\\///////\\\___\/\\\///////////____/\\\/////////\\\_\///////\\\/////______/\\\///\\\____       
#    _\/\\\_______\/\\\_\/\\\_____\/\\\___\/\\\______________\//\\\______\///________\/\\\_________/\\\/__\///\\\__      
#     _\/\\\\\\\\\\\\\/__\/\\\\\\\\\\\/____\/\\\\\\\\\\\_______\////\\\_______________\/\\\________/\\\______\//\\\_     
#      _\/\\\/////////____\/\\\//////\\\____\/\\\///////___________\////\\\____________\/\\\_______\/\\\_______\/\\\_    
#       _\/\\\_____________\/\\\____\//\\\___\/\\\_____________________\////\\\_________\/\\\_______\//\\\______/\\\__   
#        _\/\\\_____________\/\\\_____\//\\\__\/\\\______________/\\\______\//\\\________\/\\\________\///\\\__/\\\____  
#         _\/\\\_____________\/\\\______\//\\\_\/\\\\\\\\\\\\\\\_\///\\\\\\\\\\\/_________\/\\\__________\///\\\\\/_____ 
#          _\///______________\///________\///__\///////////////____\///////////___________\///_____________\/////_______

#######################################################  TOOLS  #########################################################
#-------------------------------------------------------------------------------------------------
# docker engine /compose version checker and updater via apt manager

# Version: 1.0.3
# Last Updated: 08/06/2026
# Description: Docker Engine and Compose version checker and updater with docker-v prefix fix


# Colors for output
green="\e[32m"
red="\e[31m"
yellow="\e[33m"
no_col="\e[0m"

# Function to compare versions.
compare_versions() {
  awk -v current="$1" -v latest="$2" '
  function strip_non_numeric(ver, arr, i, out) {
    split(ver, arr, ".")
    out = ""
    for (i = 1; i <= length(arr); i++) {
      gsub(/[^0-9].*$/, "", arr[i])
      out = out (i == 1 ? "" : ".") arr[i]
    }
    return out
  }
  BEGIN {
    current = strip_non_numeric(current)
    latest = strip_non_numeric(latest)
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

# ---- Docker Compose Version Check ----
if docker compose version --short &>/dev/null; then
  CURRENT_COMPOSE_VERSION=$(docker compose version --short 2>/dev/null)
else
  CURRENT_COMPOSE_VERSION=$(docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
fi

LATEST_COMPOSE_TAG=$(curl -s "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4)

if [[ -z "$LATEST_COMPOSE_TAG" || "$LATEST_COMPOSE_TAG" =~ "API rate limit exceeded" ]]; then
  echo -e "${red}❌ Failed to fetch Docker Compose version from GitHub.${no_col}"
  exit 1
fi

LATEST_COMPOSE_VERSION="${LATEST_COMPOSE_TAG##*v}"
COMPOSE_UPDATE=$(compare_versions "${CURRENT_COMPOSE_VERSION##*v}" "$LATEST_COMPOSE_VERSION")

# ---- Docker Engine Version Check ----
CURRENT_DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
LATEST_DOCKER_TAG=$(curl -s "https://api.github.com/repos/moby/moby/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4)

if [[ -z "$LATEST_DOCKER_TAG" ]]; then
  echo -e "${red}❌ Failed to fetch Docker Engine version from GitHub.${no_col}"
  exit 1
fi

LATEST_DOCKER_VERSION="${LATEST_DOCKER_TAG##*v}"
DOCKER_UPDATE=$(compare_versions "${CURRENT_DOCKER_VERSION##*v}" "$LATEST_DOCKER_VERSION")

# ---- Show update notifications ----
UPDATE_NEEDED=0

if [[ "$COMPOSE_UPDATE" == "newer" ]]; then
  echo -e "${yellow}✅ A newer version of Docker Compose (${red}v$CURRENT_COMPOSE_VERSION${no_col}) is available (${green}v$LATEST_COMPOSE_VERSION).${no_col}"
  UPDATE_NEEDED=1
fi

if [[ "$DOCKER_UPDATE" == "newer" ]]; then
  echo -e "${yellow}✅ A newer version of Docker Engine  (${red}v$CURRENT_DOCKER_VERSION${no_col}) is available (${green}v$LATEST_DOCKER_VERSION).${no_col}"
  UPDATE_NEEDED=1
fi

if [[ "$UPDATE_NEEDED" -eq 0 ]]; then
  echo -e "${green}✅ Docker and Docker Compose are already up to date.${no_col}"
  exit 0
fi

# ---- Ask user for update confirmation ----
echo -e "${yellow}Do you want to update Docker and/or Docker Compose now? (y/N)${no_col}"
read -r REPLY
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo -e "${red}🚫 Update canceled.${no_col}"
  exit 1
fi

# ---- Updating ----
if [[ "$COMPOSE_UPDATE" == "newer" ]]; then
  echo -e "${yellow}🔄 Updating Docker Compose to v$LATEST_COMPOSE_VERSION...${no_col}"
  sudo apt-get update && sudo apt-get install -y docker-compose-plugin
  echo -e "${green}✅ Docker Compose updated successfully.${no_col}"
fi

if [[ "$DOCKER_UPDATE" == "newer" ]]; then
  echo -e "${yellow}🔄 Updating Docker Engine to v$LATEST_DOCKER_VERSION...${no_col}"
  sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  echo -e "${green}✅ Docker Engine updated successfully.${no_col}"

  echo -e "${yellow}🔄 Restarting Docker service...${no_col}"
  sudo systemctl restart docker
  echo -e "${green}✅ Docker service restarted successfully.${no_col}"
fi

echo -e "${green}🎉 Update process completed!${no_col}"
