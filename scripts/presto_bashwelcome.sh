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


# USER ADJUSTABLE OPTIONS to display when login-in 
#
#
# show_systemstatusicons    =  1 # set to 1 to show system status, set to 0 to skip
 show_dockerinfo=0 # set to 1 to show docker info, set to 0 to skip
 show_smartdriveinfo=0 # set to 1 to show smart drive info, set to 0 to skip
 show_driveinfo=0 # set to 1 to show drive info, set to 0 to skip 


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
magenta_dim="\e[35;2m"
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
  "$magenta_dim"
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
clock="🕛"
ram="🐏"
weather="🌘"
timer="⏳"
fan="🔄"
wind="🌀"

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
  "wind"
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
#echo -e "${cyan}\n  Perfectly Rationalized Engine for Superior Tidiness\n                         and \n                     Organization ${no_col}\n "
#echo -e "  https://github.com/piklz/presto-tools"
#======================================================================================================================


<<'###BLOCK-COMMENT'
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

###BLOCK-COMMENT



# --- CHECK WEATHER URL AND TIMEOUT IF DEAD LINK or busy
weather_info=$(timeout 4 curl -s https://wttr.in/London?format="%l:+%c+%C+%t+feels-like+%f+\n+++++++++++++++++++phase%m++humid+%h+🌞+%S+🌇+%s+\n" 2>/dev/null)

if [[ -n "$weather_info" ]]; then
  echo ""
  #echo -e "☁️"
else
  echo -e "  The weather [wttr.in] is downright now .. continue\n"
  weather_info="..might be sunny somewhere?"
fi

#echo "$weather_info"



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






print_docker_status() {
  # is docker installed? show user their containers active status
  if is_command docker; then
    echo -e "${cyan}  DOCKER STACK INFO 🐋"
    docker_filesystem_status=$(docker system df | awk '{print $1, $2, $3, $4, $5, $6}' | while read type total active size reclaimable; do printf "  %-12s ${cyan}%-8s ${magenta}%-8s ${white}%-8s ${green}%-8s\n" "$type" "$total" "$active" "$size" "$reclaimable";done)

    echo -e "${docker_filesystem_status} "

    # --- notify if there's a newer compose plugin out on GitHub then offer to update
    # Function to compare versions (returns "newer" if latest > current)
    compare_versions() {
      awk -v current="$1" -v latest="$2" '
      BEGIN {
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

    if [[ $(timeout 2 curl -s https://api.github.com/repos/docker/compose/releases/latest) ]] 2>/dev/null; then
      # ---- Docker Compose Version Check ----
      CURRENT_COMPOSE_VERSION=$(docker compose version 2>/dev/null | grep "Docker Compose version" | awk '{print $4}' | cut -c 2-)
      LATEST_COMPOSE_TAG=$(curl -s "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4)
      LATEST_COMPOSE_VERSION="${LATEST_COMPOSE_TAG#v}"

      COMPOSE_UPDATE=$(compare_versions "$CURRENT_COMPOSE_VERSION" "$LATEST_COMPOSE_VERSION")

      # ---- Docker Engine Version Check ----
      CURRENT_DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
      LATEST_DOCKER_TAG=$(curl -s "https://api.github.com/repos/moby/moby/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4)
      LATEST_DOCKER_VERSION="${LATEST_DOCKER_TAG#v}"

      DOCKER_UPDATE=$(compare_versions "$CURRENT_DOCKER_VERSION" "$LATEST_DOCKER_VERSION")

      # ---- Show update notifications ----
      UPDATE_NEEDED=0

      if [[ "$COMPOSE_UPDATE" == "newer" ]]; then
        echo -e "${yellow}  ✅ A newer version of Docker Compose is available (v$LATEST_COMPOSE_VERSION).${no_col}"
        UPDATE_NEEDED=1
      fi

      if [[ "$DOCKER_UPDATE" == "newer" ]]; then
        echo -e "${yellow}  ✅ A newer version of Docker Engine is available (v$LATEST_DOCKER_VERSION).${no_col}"
        UPDATE_NEEDED=1
      fi

      if [[ "$UPDATE_NEEDED" -eq 0 ]]; then
        echo -e "${green}  ✅ Docker and Docker Compose are up to date 🐋.${no_col}"
      fi
    else
      echo -e "${red}  Docker ver checker down right now .. continue try login later"
    fi

    if [[ "$UPDATE_NEEDED" -eq 1 ]]; then
      echo -e "${magenta}  ✅ Run PRESTO_ENGINE_UPDATE to update Docker/Compose Engine.${no_col}"
    fi
  else
    echo -e "     "
    echo -e "\e[33;1m  no docker info - no systems running yet \e[0m"
  fi
}



# Function to display the RAM usage as a graphical bar
ram_usage_bar() {
    # Get total and used RAM (in MB)
    total_ram=$(free -m | awk '/Mem:/ {print $2}')
    used_ram=$(free -m | awk '/Mem:/ {print $3}')

    # Calculate percentage used
    percentage=$((used_ram * 100 / total_ram))

    # Set bar length
    bar_length=14

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
    echo -e "${bar_color}[$filled_bar${grey_dim}$empty_bar] $percentage%${bar_reset} ($used_ram MB / $total_ram MB)"

} # Call the function #ram_usage_bar




# --- Retrieve Raspberry Pi info variables here for later use
cpu_temp=$(cat /sys/class/thermal/thermal_zone0/temp )
gpu_temp=$(vcgencmd measure_temp |  awk '{split($0,numbers,"=")} {print numbers[2]}')
internal_ip=$(hostname -I | awk '{print $1, $2, $3}') #only show first three as theres possibily many remove awk part to show all
external_ip=$(curl -s https://ipv4.icanhazip.com) #curl -s https://ipv6.icanhazip.com for ipv6 values
timezone=$(timedatectl | grep "Time zone" | awk '{print $3$4$5}')
date=$(date +"%A, %d %B %Y,%H:%M:%S "$timezone)
#os=$(uname -s)
os=$(lsb_release  -d -r -c   | awk -F: '{split($2,a," "); printf a[1]" "  }';uname -s -m)
uptime=$(uptime -p)
#memory_usage=$(free -h | grep Mem: | awk '{print $3, $2}')
memory_usage=$(ram_usage_bar)
running_processes=$(ps aux | wc -l)
raspberry_model=$(cat /proc/device-tree/compatible | awk -v RS='\0' 'NR==1')

#weather_info=$(curl -s https://wttr.in/London?format=4) #code check timeout is above already suing this var


  # example of print_pi_drive_info()
 # PI 🍓Model:  raspberrypi,4-model-b
 # -----------------------------------------------
 # DRIVE           HDSIZE  USED   FREE   USE%  LABEL
 # /dev/mmcblk0p2    59G   5.9G    50G    11%  -
 # /dev/mmcblk0p1   510M    66M   445M    13%  -
 # /dev/sda1        1.8T   1.2T   576G    68%  seagate2tb
  
print_pi_drive_info() {
  #------ Print Raspberry Pi info in block tab mode
  echo -e "${magenta}
  PI 🍓Model:  ${raspberry_model}${no_col}"

  # Get the longest drive name and label lengths for alignment
  max_drive_length=15  # Length of "/dev/mmcblk0p1" (longest typical drive name)
  max_label_length=0

  # Collect drive labels and find the longest label
  declare -A drive_labels
  while read -r device label; do
    drive_labels["$device"]="$label"
    label_length=${#label}
    if [ $label_length -gt $max_label_length ]; then
      max_label_length=$label_length
    fi
  done < <(lsblk -n -o NAME,LABEL -l | grep -v '^$' | while read -r name label; do
    if [[ -n "$label" ]]; then
      echo "/dev/$name $label"
    else
      echo "/dev/$name -"
    fi
  done)

  # Ensure minimum label length for alignment (e.g., for "LABEL" header)
  if [ $max_label_length -lt 5 ]; then
    max_label_length=5  # Minimum to fit "LABEL" header
  fi

  # Calculate total line length and create separator
  total_line_length=$((max_drive_length + 6 + 6 + 6 + 5 + max_label_length + 7))  # Columns + spaces
  separator=$(printf '%*s' "$total_line_length" '' | tr ' ' '-')

  # Print separator
  echo -e "  ${magenta}${separator}${no_col}"

  # Print header with fixed-width columns
  printf "  ${grey}%-${max_drive_length}s %6s %6s %6s %5s %-${max_label_length}s${no_col}\n" "DRIVE" "HDSIZE" "USED" "FREE" "USE%" "LABEL"

  # Loop through 'df' output and color code usage
  df -h --output=source,size,used,avail,pcent | grep "^/dev/" | while read -r line; do
    # Extract fields
    drive=$(echo "$line" | awk '{print $1}')
    hdsize=$(echo "$line" | awk '{print $2}')
    used=$(echo "$line" | awk '{print $3}')
    free=$(echo "$line" | awk '{print $4}')
    usep=$(echo "$line" | awk '{print $5}' | tr -d '%')

    # Get label for the drive
    label="${drive_labels[$drive]:--}"  # Use "-" if no label

    local color
    # Set color based on usage percentage
    if [ "$usep" -lt 40 ]; then
      color=$green
    elif [ "$usep" -le 65 ]; then
      color=$yellow
    else
      color=$red
    fi

    # Print formatted output with aligned columns
    printf "  ${color}%-${max_drive_length}s %6s %6s %6s %5s %-${max_label_length}s${no_col}\n" "$drive" "$hdsize" "$used" "$free" "$usep%" "$label"
  done
  echo -e ""
}


# Trap errors so that the script can continue even if one of the commands fails
trap '{ echo -e "${laptop}${red}Error: $?" >&2; }' ERR



# <<'###BLOCK-COMMENT'




# --- Print Raspberry Pi info STARTS HERE


echo -e ""
#echo -e "  ${white}Raspberry Pi SysInfo"
printf "  %-3s ${red}%-13s${no_col} ${white}%s\n" "Raspberry Pi SysInfo"

#echo -e "  ${grey_dim}----------------------------------------${no_col}"
printf "  %-3s ${white}%-13s${no_col} %s" "──────────────────────────────────────────"





# --- Display docker system status  if enabled
if [[ "$show_dockerinfo" -eq 1 ]]; then
    print_docker_status # Displays docker status and updates if needed
    
else
    echo -e "\n  ${grey_dim}Docker status display skipped as per user preference.${no_col}"
fi  



#test if user wants to show  hd smart info  presto_drive_status.sh
if [[ "$show_smartdriveinfo" -eq 1 ]]; then
    drive_report=$(sudo /$HOME/presto-tools/scripts/presto_drive_status.sh) # Displays drives smart status and space usage
    echo "$drive_report"
else
    echo -e "\n  ${grey_dim}Drive smart information display skipped as per user preference.${no_col}"
fi  





#test if user wants to show  print_pi_drive_info
if [[ "$showdriveinfo" -eq 1 ]]; then
    print_pi_drive_info # Displays Raspberry Pi drive information including drive name, size, usage, and labels in a formatted table
else
    echo -e "\n  ${grey_dim}Drive information display skipped as per user preference.${no_col}"
fi  

#print_pi_drive_info #run command to show drive space info


printf "  %-3s ${cyan}%-13s${no_col} ${yellow}%s\n"   "Operating System:"  "${os}"


printf "  %-3s ${white}%-13s${no_col} ${white}%s\n" "${calendar}"   "${date}"

echo -e "\n"
# --- FAN info - Check if the fan input file exists first and show RPM if exists
fan_input_path=$(find /sys/devices/platform/ -name "fan1_input" 2>/dev/null)

if [[ -n "$fan_input_path" ]]; then
    # Fan input file exists, check fan speed
    fan_speed=$(cat "$fan_input_path")
    if [[ "$fan_speed" -gt 1000 ]]; then
        
        printf "  %-3s ${green}%-13s${no_col} ${green}%s\n" "${fan}"  "Fan is on" "${wind}${fan_speed} RPM"
    else
        
        printf "  %-3s ${grey}%-13s${no_col} ${grey}%s\n" "${fan}"  "Fan is off" "${wind}${fan_speed} RPM"
    fi
else
    # Fan input file doesn't exist
    
    printf "  %-3s ${yellow}%-13s${no_col} \n" "${fan}" "No Fan Detected"
fi

# ###BLOCK-COMMENT




if [[ "$((cpu_temp/1000))" -lt 50 ]]; then 
   printf "  %-3s ${cyan}%-13s${no_col} ${green}%d°C\n"  "${laptop}"  "CPU Temp:" "$((cpu_temp/1000))"
   printf "  %-3s ${cyan}%-13s${no_col} ${green}%s\n"  "${gpu}"  "GPU Temp:" "$gpu_temp"
elif [[ "$((cpu_temp/1000))" -lt 62 ]]; then
   printf "  %-3s ${cyan}%-13s${no_col} ${yellow}%d°C\n"  "${laptop}"  "CPU Temp:" "$((cpu_temp/1000))"
   printf "  %-3s ${cyan}%-13s${no_col} ${yellow}%s\n"  "${gpu}"  "GPU Temp:" "$gpu_temp"
else
   printf "  %-3s ${cyan}%-13s${no_col} ${red}%d°C\n"  "${laptop}"  "CPU Temp:" "$((cpu_temp/1000))"
   printf "  %-3s ${cyan}%-13s${no_col} ${red}%s\n"  "${gpu}"  "GPU Temp:" "$gpu_temp"
fi

printf "  %-3s ${blue}%-13s${no_col} ${blue}%s\n"  "${house}"  "Internal IP:" "$internal_ip"
printf "  %-3s ${magenta_dim}%-13s${no_col} %s\n"  "${globe}"  "External IP:" "$external_ip"
printf "  %-3s ${yellow}%-15s${no_col} ${yellow}%s\n"  "${clock}"  "Uptime┐" "$uptime"
printf "  %-3s ${yellow}%-13s${no_col} %s\n"  "${timer}"  "  Processes:" "$running_processes"
printf "  %-3s ${green}%-13s${no_col} %s\n"  "${ram}"  "  RAM Usage:" "$memory_usage"

printf "  %-3s ${white}%-13s${no_col} %s\n"  "${weather}"  "Weather:" "$weather_info"

echo -e "\n"
echo -e "   Hello $USER ◕ ‿ ◕ "






# Trap errors again so that the script can exit gracefully even if the trap handler fails
trap - ERR
