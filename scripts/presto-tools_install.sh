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


#CHECK IF WE HAVE EVER INSTALLED PRESTO /folder exists?

git_pull(){

	echo -e "GIT cloning the presto-tools now:\n"
	#TEST develop
	git clone -b develop https://github.com/piklz/presto-tools ~/presto-tools
	#git clone https://github.com/piklz/presto-tools ~/presto-tools
	#since we installed presto lets link to bashwelcome in bashrc
    do_install_prestobashwelcome

}




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
	fi 
}


	if [ ! -d ~/presto-tools ]; then 
		git_pull

	else 
		echo -e "presto-tools folder already exists no need to clone"
		do_install_prestobashwelcome
		echo -e "lest check for updates"
		git fetch

	fi