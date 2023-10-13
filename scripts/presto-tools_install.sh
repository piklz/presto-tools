#!/usr/bin/env bash
# shellcheck disable=SC1090
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
# 		    automatical one shot updates your whole docker-stacked system with 
# 			image cleanup at the end for a clean, space saving, smooth docker experience , ie. can be used 
# 			with a cron job ,for example to execute it every week and update the containers and prune the left
# 			over images? (see below for instructions )
#  			to use run:  sudo ./presto-tools_install.sh
#
#--------------------------------------------------------------------------------------------------
# author		: piklz
# github		: https://github.com/piklz/presto-tools.git
# web		    : https://github.com/piklz/presto-tools.git
#
#########################################################################################################################

#install tools script
#presto toolkit xtras for future use

set -e
# Append common folders to the PATH to ensure that all basic commands are available.
export PATH+=':/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'



# github update from main func
do_update() {

	echo "Pulling latest project file from Github.com ---------------------------------------------"
	git pull origin main
	echo "git status ------------------------------------------------------------------------------"
	git status

}



#first check if login bash mod is setup already
do_install_prestobashwelcome() {
	if grep -Fxq ". /home/pi/presto-tools/scripts/presto_bashwelcome.sh" /home/pi/.bashrc ; then
		# code if found
		echo "Found presto Welcome login link in bashrc no changes needed -continue check if prestotools git installed.."

	else
		# add code if not found
	echo -e "${COL_LIGHT_RED}${INFO}${clear} ${COL_LIGHT_RED}presto Welcome Bash  (in bash.rc ) is missing ${clear}"
		echo -e "${COL_LIGHT_RED}${INFO}${clear} ${COL_LIGHT_RED}lets add presto_bashwelcome  mod to .bashrc now >${clear}"


		#bashwelcome add to bash.rc here
		echo  "#presto-tools Added: presto_bash_welcome scripty" >> /home/pi/.bashrc
		echo ". /home/pi/presto-tools/scripts/presto_bashwelcome.sh" >> /home/pi/.bashrc
	




		#MAIN CHECK HERE ------------------

		#lets check if there already / git clone it and run it
		if [ ! -d ~/presto-tools ]; then
				echo "GIT cloning the presto-tools now:\n"

				git clone https://github.com/piklz/presto-tools ~/presto-tools
				chmod +x ~/presto-tools/scripts/presto-tools_install.sh

				echo "running presto-tools install..>:\n"
				pushd ~/presto-tools/scripts && sudo ./presto-tools_install.sh
				popd
		else
			
			echo "presto-tools scripts dir already installed - continue LETS CHECK FOR UPDATES instead"
			git fetch
			echo "GIT FETCHING  for updates now " 

			if [ $(git status | grep -c "Your branch is up to date") -eq 1 ]; then

			#delete .outofdate if it does exist
			[ -f .outofdate ] && rm .outofdate      
			echo -e "${INFO} ${COL_LIGHT_GREEN}    PRESTO Git local/repo is up-to-date${clear}"

			else

				echo -e "${INFO} ${COL_LIGHT_GREEN}   PRESTO update is available${COL_LIGHT_GREEN} ✓${clear}"

				if [ ! -f .outofdate ]; then
					whiptail --title "Project update" --msgbox "PRESTO update is available \nYou will not be reminded again until your next update" 8 78
					touch .outofdate
				fi
					#do_update
			fi
		fi
	fi


  
  #all done done 
  echo -e "${COL_LIGHT_RED}${INFO}${clear}files added from git or bash links modded.(bash.rc)\n "
  echo -e "${COL_LIGHT_RED}${INFO}${clear}${COL_LIGHT_GREEN}prestos WELCOME BASH created! Logout and re-login to test  \n"

  source ~/.bashrc
  

}
do_install_prestobashwelcome

