#!/bin/bash

###########################      About this script      ##########################
#                                                                                #
#   File: auto-erase-install.sh                                                  #   
#   Purpose:                                                                     #
#            Runs the erase-install script installed by the erase-install        #
#            package to download the latest update of macOS installer for the    #
#            currently installed macOS major version.                            #
#            run the startosinstall command with --eraseinstall option           #
#                                                                                #
#   Created by Mart Verburg                                                      #
#               March 2021                                                       #
#                                                                                #
#   Version history                                                              #
#                                                                                #
#                                                                                #
#                                                                                #
#   Instructions                                                                 #
#            Installed in /Library/Management/erase-install/ and                 #
#            run automatically by LaunchAgent                                    #
#                                                                                #
##################################################################################


# configure for notifications using DEPNotify
DEPNotify="/Applications/Utilities/DEPNotify.app"
DEPNotify_CommandFile="/var/tmp/depnotify.log"

# check for, init if present, and open DEPNotify 
if [[ -f "$DEPNotify" ]]; then
	DEPNotifi_init_file="/Library/Management/erase-install/erase-instal-DEPnotify.txt"
	if [[ -f "$DEPNotifi_init_file" ]]; then
		cp "$DEPNotifi_init_file" "$DEPNotify_CommandFile"
	fi
	open "$DEPNotify"
fi

	# Run updatepreboot on a Silicon M1 Mac to prevent issue with startosinstall complaining about user not being an admin
arch=$(/usr/bin/arch)
if [[ "$arch" == "arm64" ]]; then 
	#echo "Command: WindowStyle: Activate" >> "$DEPNotify_CommandFile"
	echo "Status: updating preboot to prevent issue startosinstall on M1 Macs" >> "$DEPNotify_CommandFile"
	result=$(diskutil apfs updatepreboot / | grep "overall error=(ZeroMeansSuccess)=0")
	# check if it went as planned
	if [[ $? != 0 ]]; then
		echo "Status: preboot update failed!" >> "$DEPNotify_CommandFile"
		echo "Quit: Please get assistance, bailing out..." >> "$DEPNotify_CommandFile"
		exit 1
fi

# start the download, and then erase-install 
echo "Status: starting macOS installer check, download, and erase-install" >> "$DEPNotify_CommandFile"
/Library/Management/erase-install/erase-install.sh --update --sameos --erase

# script is supposed to be aborted by macOS' installer startos --eraseinstall at this point
echo "Status: When you read this message, something has gone wrong with macOS installer --erase-install" >> "$DEPNotify_CommandFile"
echo "Quit: Please get assistance, bailing out..." >> "$DEPNotify_CommandFile"


