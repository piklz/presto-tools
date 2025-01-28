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
# 			  Automatical one shot updates your whole docker-stacked system with 
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


# --- player one start



sleep 0

# --- tv color bar gfx

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

# --- presto rainbow road title

text="PRESTO"
colors=("\e[31m" "\e[33m" "\e[32m" "\e[36m" "\e[34m" "\e[35m")

for ((i=0; i<${#text}; i++)); do
  color_index=$((i % ${#colors[@]}))
  echo -ne "  ${colors[$color_index]}${text:i:1}"
done

echo -e "\e[0m"





# --- Set some colour default values so we can run in color




# Set group colors
no_col="\e[0m"
#no_col="\033[0m"
white="\e[37m"
cyan="\e[36m"
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
magenta="\e[35m"
grey="\e[1;30m"
grey_dim="\e[2;30m"
lgt_red="\e[1;31m"
lgt_green="\e[1;32m"
lgt_green_inv="\e[7;32m"

#italic="[3m"
#dim="[2m"

TICK="[${lgt_green}✓${no_col}]"
CROSS="[${lgt_red}✗${no_col}]"
INFO="[i]"
# shellcheck disable=SC2034
DONE="${lgt_green} done!${no_col}"


group_colors=(  #grouped use: eg.  ' selected_color="${group_colors[4]}" # green ''
  "$no_col"
  "$white"
  "$cyan"
  "$red"
  "$green"
  "$yellow"
  "$blue"
  "$magenta"
  "$grey"
  "$grey_dim"
  "$lgt_green"
  "$lgt_green_inv"
)

# Set icon graphics
laptop="💻"
gpu="🎮"
house="🏠"
globe="🌐"
calendar="📅"
os="☄️"
filesystem="💾"
clock="🕰️"
ram="🐏"
weather="☁️"
timer="⏳"
fan="⚙️"


icon_graphics=( #grouped use: eg.  ' selected_gfx="${icon_graphics[3]}" # globe ''
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
  "fan"
)




#echo -e "${cyan}
#${cyan}  ██████╗${cyan} ██████╗ ███████╗███████╗████████╗ ██████╗
#${cyan}  ██╔══██╗${cyan}██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔═══██╗
#${cyan}  ██████╔╝${cyan}██████╔╝█████╗  ███████╗   ██║   ██║   ██║
#${cyan}  ██╔═══╝ ${cyan}██╔══██╗██╔══╝  ╚════██║   ██║   ██║   ██║
#${cyan}  ██║     ${cyan}██║  ██║███████╗███████║   ██║   ╚██████╔╝
#${cyan}  ╚═╝     ${cyan}╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝    ╚═════╝ "

#echo -e "\n"
#echo -e "${italic}${lgt_green}HI ${no_col}\n"
sleep 1
echo -e "${cyan}\n  Perfectly Rationalized Engine for Superior Tidiness\n                         and \n                     Organization ${no_col}\n "
#echo -e "  https://github.com/piklz/presto-tools"
#======================================================================================================================


# --- Lets fetch weather +  timeout  to fail /gracefully and move on 

# get weather  :    wttr.in/London?format="%l:+%c+%t+%m+%w"  
# long version :  curl wttr.in/London?format="%l:+%c+%C+%t+feels-like+%f+phase%m++humid+%h+🌞+%S+🌇+%s+\n"

# if wttr not avail/down  continue script 
if [[ $(timeout 4 curl -s https://wttr.in/London?format=4 ) ]] 2>/dev/null
  then #echo "This page exists."
      #short curl wttr.in/London?format="%l:+%c+%t+%m+%w"
      #curl -s wttr.in/London?format="%l:+%c+%C+%t+feels-like+%f+phase%m++humid+%h+🌞+%S+🌇+%s+\n" # this code in term runs as is
      weather_info=$(curl -s https://wttr.in/London?format="%l:+%c+%C+%t+feels-like+\n+%f+phase%m++humid+%h+🌞+%S+🌇+%s+\n")
  else echo -e "The weather [wttr.in] is downright now .. continue\n"
    weather_info=" might be sunny somewhere?"
 fi




# --- 'is it a command?' helper . returns 1 or 0
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






#is docker is installed? show user their containers active status
if is_command docker; then
    #echo -e "\n"
#echo -e "${cyan}
#  ╔╦╗╔═╗╔═╗╦╔═╔═╗╦═╗
#   ║║║ ║║  ╠╩╗║╣ ╠╦╝
#  ═╩╝╚═╝╚═╝╩-╩╚═╝╩╚═COMPOSE V2 🐋"
    compose_version=$(docker compose version | awk '{print $4}')
echo -e "${cyan}  DOCKER STACK INFO (Compose:$compose_version) 🐋"

    #docker system df
    # check docker exists and if so show the file system here
    docker_filesystem_status=$(docker system df | awk '{print $1, $2, $3, $4, $5, $6}' | while read type total active size reclaimable; do printf "  %-12s ${cyan}%-8s ${magenta}%-8s ${white}%-8s ${green}%-8s\n" "$type" "$total" "$active" "$size" "$reclaimable";done)

    echo -e "${docker_filesystem_status} "
    #echo -e "\n"
else
    echo -e "     "
    echo -e "\e[33;1m  no docker info  - no systems running yet \e[0m"

fi


# Function to display the RAM usage as a graphical bar
ram_usage_bar() {
    # Get total and used RAM (in MB)
    total_ram=$(free -m | awk '/Mem:/ {print $2}')
    used_ram=$(free -m | awk '/Mem:/ {print $3}')

    # Calculate percentage used
    percentage=$((used_ram * 100 / total_ram))

    # Set bar length
    bar_length=18

    # Calculate filled and empty portions
    filled_length=$((percentage * bar_length / 100))
    empty_length=$((bar_length - filled_length))

    # Create the bar with custom characters
    filled_bar=$(printf "%0.s▓" $(seq 1 $filled_length))
    empty_bar=$(printf "%0.s░" $(seq 1 $empty_length))

    # Determine color based on usage percentage
    if [ $percentage -lt 50 ]; then
        bar_color=${green}    # Green for <50%
    elif [ $percentage -lt 75 ]; then
        bar_color=${yellow}   # Yellow for 50%-74%
    else
        bar_color=${red}      # Red for 75%+
    fi

    # Reset color
    bar_reset="\033[0m"

    # Print the bar with the percentage
    echo -e "Usage: ${bar_color}[$filled_bar${grey_dim}$empty_bar] $percentage%${bar_reset} ($used_ram MB / $total_ram MB)"

} # Call the function #ram_usage_bar




# --- Retrieve Raspberry Pi info variables here for later use
cpu_temp=$(cat /sys/class/thermal/thermal_zone0/temp )
gpu_temp=$(vcgencmd measure_temp |  awk '{split($0,numbers,"=")} {print numbers[2]}')
internal_ip=$(hostname -I | awk '{print $1, $2, $3}') #only show first three as theres possibily many remove awk part to show all
external_ip=$(curl -s https://ipv4.icanhazip.com) #curl -s https://ipv6.icanhazip.com for ipv6 values
date=$(date +"%A, %d %B %Y, %H:%M:%S")
#os=$(uname -s)
os=$(lsb_release  -d -r -c   | awk -F: '{split($2,a," "); printf a[1]" "  }';uname -s -m)
uptime=$(uptime -p)
#memory_usage=$(free -h | grep Mem: | awk '{print $3, $2}')
memory_usage=$(ram_usage_bar)
running_processes=$(ps aux | wc -l)
raspberry_model=$(cat /proc/device-tree/compatible | awk -v RS='\0' 'NR==1')

#weather_info=$(curl -s https://wttr.in/London?format=4) #code check timeout is above already suing this var





#------ Print Raspberry Pi info in block tab mode

echo -e "${magenta}
  PI 🍓${magenta}Model:  ${raspberry_model}"

#echo -e ""

# Print header
echo -e "  ${grey_dim}DRIVE        HDSIZE   USED   FREE   USE%"

# Loop through 'df' output and color code usage
df -h --output=source,size,used,avail,pcent | grep "^/dev/" | while read -r line; do
  # Extract fields
  drive=$(echo "$line" | awk '{print $1}')
  hdsize=$(echo "$line" | awk '{print $2}')
  used=$(echo "$line" | awk '{print $3}')
  free=$(echo "$line" | awk '{print $4}')
  usep=$(echo "$line" | awk '{print $5}' | tr -d '%')

  # Set color based on usage percentage
  if [ "$usep" -lt 40 ]; then
    color=$green
  elif [ "$usep" -le 65 ]; then
    color=$yellow
  else
    color=$red
  fi

  # Print formatted output
printf "  ${color}%-12s %-8s %-6s %-6s %-5s${no_col}\n" "$drive" "$hdsize" "$used" "$free" "$usep%"
done
echo -e ""



# Trap errors so that the script can continue even if one of the commands fails
trap '{ echo -e "${laptop}${red}Error: $?" >&2; }' ERR



# --- Print Raspberry Pi info STARTS HERE


echo -e ""
echo -e "  ${white}Raspberry Pi System Information"
echo -e "  ${grey_dim}----------------------------------------${no_col}"

echo -e "${white}  Operating System: ${blue}${os}"

echo -e "${white}  ${calendar}   ${date}"

# --- FAN info - Check if the fan input file exists first and show RPM if exists
fan_input_path=$(find /sys/devices/platform/ -name "fan1_input" 2>/dev/null)

if [[ -n "$fan_input_path" ]]; then
    # Fan input file exists, check fan speed
    fan_speed=$(cat "$fan_input_path")
    if [[ "$fan_speed" -gt 1000 ]]; then
        echo -e "  ${fan}${green}   Fan is on ${fan} (${fan_speed} RPM)${no_col} "
    else
        echo -e "  ${fan}${grey}   Fan is off (${fan_speed} RPM)${no_col} "
    fi
else
    # Fan input file doesn't exist
    echo -e "  ${fan}${yellow}   No fan detected.${no_col} "
fi


# --- Print the rest of the Raspberry Pi info


if [[ "$((cpu_temp/1000))" -lt 50 ]]; then 

   echo -e "${cyan}  ${laptop}${green}   CPU Temp: ${green}$((cpu_temp/1000))°C"
   echo -e "${cyan}  ${gpu}${green}  GPU Temp: ${no_col}${green}${gpu_temp}"
elif [[ "$((cpu_temp/1000))" -lt 62 ]]; then

   echo -e "${cyan}  ${laptop}${yellow}   CPU Temp: ${yellow}$((cpu_temp/1000))°C"
   echo -e "${cyan}  ${gpu}${yellow}  GPU Temp:${no_col} ${yellow}${gpu_temp}"
else
   echo -e "${cyan}  ${laptop}${red}   CPU Temp: ${red}$((cpu_temp/1000))°C"
   echo -e "${cyan}  ${gpu}${red}  GPU Temp:${no_col} ${red}${gpu_temp}"
fi
echo -e "${blue}  ${house}${grey_dim}   Internal IP: ${internal_ip}${no_col}"
echo -e "${blue}  ${globe}${grey_dim}   External IP: ${external_ip}${no_col}"
echo -e "${white}  ${clock}${yellow}  Uptime: ${uptime}"
echo -e "${yellow}  ${timer}   Running Processes: ${running_processes}"
echo -e "${green}  ${ram}${no_col}  ${memory_usage}${no_col} "
echo -e "${white}  ${weather}   Weather: ${weather_info}"
echo -e ""



# Print the filesystem usage for `/dev/mmcblk0p1` if it exists
#if [[ ! -z "$sd_path" ]]; then
#  #echo -e " ${white}  ${filesystem}FILESYSTEM        used     Avail "
#  #echo -e " ${green}  ${sd_path} ${sd_space_used} used, ${sd_space_left} left"
#  echo -e "${grey} $(df -h /  | awk '{print ("  ",$0)}') \n"
#else
#  echo -e " ${magenta}  SD card not found"
#fi




# Trap errors again so that the script can exit gracefully even if the trap handler fails
trap - ERR
