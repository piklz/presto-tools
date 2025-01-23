#!/usr/bin/python

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
# author    : piklz
# github    : https://github.com/piklz/presto-tools.git
# web       : https://github.com/piklz/presto-tools.git
#
#########################################################################################################################


##################################################################################################
# PRESTO DOCKER WRAPPERS TO START STOP CHECK UPDATE REBUILD AND CLEAN /PRUNE IMAGES in one go
##################################################################################################

import os,sys,subprocess

# --- checkfor current user
if [ -z "${USER}" ]; then
    USER="$(id -un)"
fi



os.chdir("/home/$USER/presto/scripts/")
##ping = subprocess.Popen("./update.sh",stdout = subprocess.PIPE,stderr = subprocess.PIPE,shell=True) #quietver
update_ping = subprocess.Popen("./update.sh",shell=True)						    #verbosever
update_out = update_ping.communicate()[0]
output = str(update_out)
##print output

#print(" [presto] updating/recreated  presto stack Complete")


# now use prune-images script  to clean up the mess
print("[presto] pruning-images now one moment...")

#pruneimage_ping = subprocess.Popen('echo y |  ./prune-images.sh',shell=True)
#prune_out = pruneimage_ping.communicate()
#output = str(prune_out)


#print output

os.system("docker image prune -a -f")

print("[presto] presto containers up'd +  pruning-images finished.")

