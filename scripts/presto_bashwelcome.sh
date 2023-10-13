#!/bin/env bash

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
# Welcome to the presto TOOLS INSTALL SCRIPT
#
# -presto-tools_install .sh  (The actual install script for this kit )
# -presto_bashwelcome.sh    (Gives you nice info on your pi' running state)
# -presto_update_full.py >
# 		      automatical one shot updates your whole docker-stacked system with 
# 		  	  image cleanup at the end for a clean, space saving, smooth docker experience , ie. can be used 
# 		  	  with a cron job ,for example to execute it every week and update the containers and prune the left
# 		  	  over images? (see below for instructions )
#  		  	  to use run:  sudo ./presto-tools_install.sh
#
#--------------------------------------------------------------------------------------------------
# author        : piklz
# github        : https://github.com/piklz/presto-tools.git
# web           : https://github.com/piklz/presto-tools.git
#
#########################################################################################################################

#lets add a check for git hub here also?

sleep 0

#----->

echo

for y in $(seq 0 10); do
  printf %s '  '
  for color in 7 3 6 2 5 1 4 ; do
    tput setab ${color}
    printf %s '       '
  done
  tput sgr0
  echo
done

for y in 0 1; do
  printf %s '  '
  for color in 4 0 5 0 6 0 7 ; do
    tput setab ${color}
    printf %s '       '
  done
  tput sgr0
  echo
done




# Set these values so the installer can still run in color; use: ${COL_...}
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_GREEN='\e[0;32m'
COL_LIGHT_RED='\e[1;31m'
TICK="[${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="[${COL_LIGHT_RED}✗${COL_NC}]"
INFO="[i]"
# shellcheck disable=SC2034
DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
OVER="\\r\\033[K"
COL_PINK="\e[1;35m"
COL_LIGHT_CYAN="\e[1;36m"
COL_LIGHT_PURPLE="\e[1;34m"
COL_LIGHT_YELLOW="\e[1;33m"
COL_LIGHT_GREY="\e[1;2m"
COL_ITALIC="\e[1;3m"




echo -e "${COL_GREEN}
${COL_GREEN}  ██████╗ ██████╗ ███████╗███████╗████████╗ ██████╗
${COL_GREEN}  ██╔══██╗██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔═══██╗
${COL_GREEN}  ██████╔╝██████╔╝█████╗  ███████╗   ██║   ██║   ██║
${COL_GREEN}  ██╔═══╝ ██╔══██╗██╔══╝  ╚════██║   ██║   ██║   ██║
${COL_GREEN}  ██║     ██║  ██║███████╗███████║   ██║   ╚██████╔╝
${COL_GREEN}  ╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝    ╚═════╝ "

#echo -e "\n"
#echo -e "${COL_ITALIC}${COL_LIGHT_GREEN}HI ${COL_NC}\n"
sleep 1
echo -e "${COL_LIGHT_CYAN}\nI'm presto \n   (Perfectly Rationalized  Engine for \n      Superior Tidiness and Organization )${COL_NC}\n "

#======================================================================================================================


#Lets fetch weather + check timeout too for later use and to fail /gracefully and move on

#get weather :    wttr.in/London?format="%l:+%c+%t+%m+%w"  
# long version  curl wttr.in/London?format="%l:+%c+%C+%t+feels-like+%f+phase%m++humid+%h+🌞+%S+🌇+%s+\n"

# if wttr not avail/down  continue script 
if [[ $(timeout 4 curl -s https://wttr.in/London?format=4 ) ]] 2>/dev/null
  then #echo "This page exists."
      #short curl wttr.in/London?format="%l:+%c+%t+%m+%w"
      #curl -s wttr.in/London?format="%l:+%c+%C+%t+feels-like+%f+phase%m++humid+%h+🌞+%S+🌇+%s+\n" # this code in term runs as is
      weather_info=$(curl -s https://wttr.in/London?format="%l:+%c+%C+%t+feels-like+%f+phase%m++humid+%h+🌞+%S+🌇+%s+\n")
  else echo -e "The weather [wttr.in] is downright now .. continue\n"
 fi


#my Functions: app check
# 'is [app] installed?' returns 1 or 0   for if-then loops 
is_installed() {
  if [ "$(dpkg -l "$1" 2> /dev/null | tail -n 1 | cut -d ' ' -f 1)" != "ii" ]; then
    return 1
  else
    return 0
  fi
}


#'is it a command?' helper for if-then returns 1 or 0
is_command() {
    # Checks to see if the given command (passed as a string argument) exists on the system.
    # The function returns 0 (success) if the command exists, and 1 if it doesn't.
    local check_command="$1"

    command -v "${check_command}" >/dev/null 2>&1
}



<<'###BLOCK-COMMENT'

# Get the output from df grep
df_output=$(df -h | awk '{if ($1 == "/dev/mmcblk0p1") print $0}' | awk '{print $1, $2, $3, $4, $5, $6}')

# Split the output into columns
columns=($df_output)

# Print the header row
printf "%-15s %-10s %-10s %-10s %-10s %-10s \n" "Filesystem" "Size" "Used" "Avail" "Use%" "Mounted on"

# Print the first row of data
printf "%-10s %-10s %-10s %-10s %-10s %-10s\n" "${columns[0]}" "${columns[1]}" "${columns[2]}" "${columns[3]}" "${columns[4]}" "${columns[5]}"

###BLOCK-COMMENT


# Set group colors
no_col="\e[0m"
white="\e[37m"
cyan="\e[36m"
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
magenta="\e[35m"
grey="\e[0;37m"
lgt_green="\e[1;32m"
lgt_green_inv="\e[7;32m"

group_colors=(
  "$no_col"
  "$white"
  "$cyan"
  "$red"
  "$green"
  "$yellow"
  "$blue"
  "$magenta"
  "$grey"
  "$lgt_green"
  "$lgt_green_inv"
)

# Set icon graphics
laptop="💻"
gpu="GPU"
house="🏠"
globe="🌐"
calendar="📅"
os="OS"
filesystem="💾"
clock="🕰️"
ram="RAM"
weather="☁️"
timer="⏳"

icon_graphics=(
  "$laptop"
  "$gpu"
  "$house"
  "$globe"
  "$calendar"
  "$os"
  "$filesystem"
  "$clock"
  "$ram"
  "$weather"
  "$timer"
)

# check docker exists and if so show the file system here
docker_filesystem_status=$(docker system df | awk '{print $1, $2, $3, $4, $5, $6}' | while read type total active size reclaimable; do printf "%-12s ${cyan}%-12s ${magenta}%-12s ${white}%-12s ${green}%-12s\n" "$type" "$total" "$active" "$size" "$reclaimable";done)



#is docker is installed? show user their containers active status
if is_command docker; then
    #echo -e "\n"
echo -e "${COL_LIGHT_CYAN}
             ╔╦╗╔═╗╔═╗╦╔═╔═╗╦═╗
              ║║║ ║║  ╠╩╗║╣ ╠╦╝
             ═╩╝╚═╝╚═╝╩-╩╚═╝╩╚═COMPOSE V2

"
    #docker system df
    echo -e "${docker_filesystem_status} ${red}# "
    echo -e "\n"
else
    echo -e "     "
    echo -e "\e[33;1m  no docker info  - no systems running yet \e[0m"

fi

# Get Raspberry Pi info
cpu_temp=$(cat /sys/class/thermal/thermal_zone0/temp )
gpu_temp=$(vcgencmd measure_temp |  awk '{split($0,numbers,"=")} {print numbers[2]}')
internal_ip=$(hostname -I | awk '{print $2, $3, $4}' | head -3) #only show first three as theres possibily many remove awk part to show all
external_ip=$(curl -s https://icanhazip.com)
date=$(date +"%A, %d %B %Y, %H:%M:%S")
os=$(uname -s)
uptime=$(uptime -p)
memory_usage=$(free -h | grep Mem: | awk '{print $2, $3}')
running_processes=$(ps aux | wc -l)
#weather_info=$(curl -s https://wttr.in/London?format=4) #code check timeout is above already suing this var

# Get the SD card path
sd_path=$(df -h | grep /dev/mmcblk0p1 | awk '{print $1}')

# Get the space used and left in the SD card filesystem
sd_space_used=$(df -h $sd_path | grep -v Filesystem | awk '{print $3}')
sd_space_left=$(df -h $sd_path | grep -v Filesystem | awk '{print $4}')

# Print Raspberry Pi info in block tab mode
echo -e ""

# Trap errors so that the script can continue even if one of the commands fails
trap '{ echo -e "${red}Error: $?" >&2; }' ERR



# Print the rest of the Raspberry Pi info
echo -e " ${white}  ${calendar} Date and Time: ${date}"
echo -e " ${blue}  ${os} Operating System: ${os}"
echo -e " ${cyan}  ${laptop} ${grey}  CPU Temp: ${no_col} $((cpu_temp/1000))°C"
echo -e " ${cyan}  ${gpu} ${grey} GPU Temp:${no_col} ${gpu_temp}"
echo -e " ${red}  ${house} Internal IP: ${internal_ip}"
echo -e " ${green}  ${globe} External IP: ${lgt_green_inv} ${external_ip} ${no_col}"
echo -e " ${grey}  ${clock} Uptime: ${uptime}"
echo -e " ${green}  ${ram} Memory Usage: ${memory_usage}"
echo -e " ${grey}  ${timer} Running Processes: ${running_processes}"
echo -e " ${grey}  ${weather} Weather: ${weather_info}"
echo -e ""


# Print the filesystem usage for `/dev/mmcblk0p1` if it exists
if [[ ! -z "$sd_path" ]]; then
  #echo -e " ${white}  ${filesystem}FILESYSTEM        used     Avail "
  #echo -e " ${green}  ${sd_path} ${sd_space_used} used, ${sd_space_left} left"
  echo -e "${grey} $(df -h /  | awk '{print ("  ",$0)}') \n"
else
  echo -e " ${magenta}  SD card not found"
fi

# Trap errors again so that the script can exit gracefully even if the trap handler fails
trap - ERR
