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

# write to the DEPNotify command file if the executable is present
function doDEPNotify() {
	text="$1"
	# Test for executble present && then write text to command file
	[[ -x "$DEPNotify/Contents/MacOS/DEPNotify" ]] && echo "$text" >> "$DEPNotify_CommandFile"
}

# write timestamp + message to stdout, redirected to logfile when running  from LaunchDaemon
function log() {
	timestamp=$(date +%Y-%m-%dT%H:%M:%S%z)
	echo "$timestamp [auto-erase-install.sh] $1"
}

# search for running process by name, try and kill, log result 
# Thanks to Graham Pugh - copied from erase-install.sh
function kill_process() {
    process="$1"
    if /usr/bin/pgrep -a "$process" >/dev/null ; then 
        /usr/bin/pkill -a "$process" && log "$process ended" || \
        log "$process could not be killed"
    fi
}

# Wait until Finder is running to ensure a console user is logged in
while ! pgrep -q Finder ; do
		timestamp=$(date +%Y-%m-%dT%H:%M:%S%z)
		log "Waiting until console user is logged in"
done

# get Console user
# Thanks to Graham Pugh - copied from erase-install.sh
current_user=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')

# Wait until console is logged in and screen is unlocked
# Thanks to https://stackoverflow.com/users/908494/abarnert https://stackoverflow.com/a/11511419/4326287
# 2021-03-13 This does not work from script running as root when launched from system wide LaunchDaemon, would have to be a user LaunchAgent if really needed. Commenting away to test without it.
# while true ; do
# 	timestamp=$(date +%Y-%m-%dT%H:%M:%S%z)
# 	sudo -u $current_user python -c 'import sys,Quartz; d=Quartz.CGSessionCopyCurrentDictionary(); sys.exit(d and d.get("CGSSessionScreenIsLocked", 0) == 0 and d.get("kCGSSessionOnConsoleKey", 0) == 1)'
# 	if [ $? != 0 ] ; then
# 		echo "$timestamp [auto-erase-install.sh] User presence detected"
# 		break
# 	else
# 		echo "$timestamp [auto-erase-install.sh] Waiting until console user is logged in and screen is unlocked"
# 	fi
# 	sleep 10
# done

# Kill DEPNotify if still running from possible previous session
kill_process "DEPNotify"

# check if present, and open DEPNotify 
if [[ -x "$DEPNotify/Contents/MacOS/DEPNotify" ]]; then
	# remove any existing commandfile before start
	rm -f "$DEPNotify_CommandFile"
	
	# ToDo: should maybe run as current console user, but sudo -u "$current_user" throws open error "The executable is missing"
	open "$DEPNotify"
else
		log "[auto-erase-install.sh] Did not find DEPNotify.app to open" 
fi
doDEPNotify "Command: MainTitle: Auto Erase Install"
doDEPNotify "Command: MainText: Getting ready to ERASE and reinstall this Mac. \n\n The process normally takes about 15-30 minutes with a normal download speed on a internet connection of 50Mbps or better. \n A macOS installer will be downloaded if needed. \n\n Please ensure any data you need to keep is backed up elsewhere before proceeding."
doDEPNotify "Command: WindowStyle: ActivateOnStep"
doDEPNotify "Command: Image: /Library/Management/erase-install/Resources/auto-erase-install.png"

# macOS 10.13 and higher are supported because only APFS can be used for erase-onstall
# Thanks to Armin Briegel for https://gist.github.com/scriptingosx/670991d7ec2661605f4e3a40da0e37aa
os_ver=$( /usr/bin/sw_vers -productVersion )
os_ver_major=$( echo "$os_ver" | awk -F. '{ print $1; }' )
os_ver_minor=$( echo "$os_ver" | awk -F. '{ print $2; }' )
if (( $os_ver_major < 11 )) ; then
	if (( $os_ver_minor < 13 )) ; then
		doDEPNotify "Status: Sorry mate, OSX older than High Sierra (10.13) will have to be erased and reinstalled manually" 
		doDEPNotify "Command: Quit: Please get assistance, bailing out..."
		log "OSX < 10.13 is not supported, need APFS for Erase-reinstall"
		exit 1
	fi
fi

# Get user confirmation
rm -f /Users/Shared/UserInput.plist
sudo -u "$current_user" defaults write menu.nomad.DEPNotify registrationMainTitle "Confirm Mac ERASE and reinstall"
sudo -u "$current_user" defaults write menu.nomad.DEPNotify registrationButtonLabel "Engage"
sudo -u "$current_user" defaults write menu.nomad.DEPNotify textField1IsOptional -bool false
sudo -u "$current_user" defaults write menu.nomad.DEPNotify textField1Placeholder "I DO NOT AGREE"
sudo -u "$current_user" defaults write menu.nomad.DEPNotify textField1Label "Confirmation"
sudo -u "$current_user" defaults write menu.nomad.DEPNotify textField1Bubble -array "Confirm Mac ERASE" "Please type \'I AGREE\' to confirm you've got a perfectly good backup of the data you need to keep, and that you\'re ready to proceed erasing the contents of this Mac and reinstall macOS"
confirmation=1
while [ ! $confirmation == 0 ] ; do
	rm -f /var/tmp/com.depnotify.registration.done
	doDEPNotify "Status: please press Continue button to proceed..."
	doDEPNotify "Command: ContinueButtonRegister: Continue"
	while [[ ! -f /var/tmp/com.depnotify.registration.done ]]; do
		sleep 3
	done
	getConfirm=$(defaults read /Users/Shared/UserInput.plist Confirmation)
	if [[ $getConfirm == *"I AGREE"* ]]; then 
		confirmation=0
	else
		doDEPNotify "Status: Mumble mumble..."
		sleep 3
	fi
done

doDEPNotify "Command: Determinate: 5"

# find out if we're running on Intel or Apple Silicone
arch=$(/usr/bin/arch)
	# Run updatepreboot on a Silicon M1 Mac to prevent issue with startosinstall complaining about user not being an admin
if [[ "$arch" == "arm64" ]]; then 
	#echo "Command: WindowStyle: Activate" >> "$DEPNotify_CommandFile"
	doDEPNotify "Status: updating preboot to prevent issue startosinstall on M1 Macs"
	result=$(diskutil apfs updatepreboot / | grep "overall error=(ZeroMeansSuccess)=0")
	# check if it went as planned
	if [[ $? != 0 ]]; then
		doDEPNotify "Status: preboot update failed!"
		doDEPNotify "Command: Quit: Please get assistance, bailing out..."
		exit 1
	fi
fi

# start the download, and then erase-install 
doDEPNotify "Status: starting macOS installer check, download if needed"
/Library/Management/erase-install/erase-install.sh --replace_invalid --sameos

doDEPNotify "Status: starting macOS installer with erase-install"
/Library/Management/erase-install/erase-install.sh --sameos --erase

# script is supposed to be aborted by macOS' installer startos --eraseinstall at this point
#[[ -x "$DEPNotify/Contents/MacOS/DEPNotify" ]] && open "$DEPNotify"
#doDEPNotify "Command: MainTitle: Auto Erase Install"
#doDEPNotify "Command: MainText: The erase-install workflow was aborted"
doDEPNotify "Status: the erase and reinstall workflow was aborted!"
doDEPNotify "Command: Quit: Please get assistance if needed, bailing out..."


