#!/bin/zsh

# script to get, update, and build auto-erase-install distribution package and it's dependencies.
# Workflow is to 
#  - git clone dependencies into leaf folders beside this repo main folder, then 
#  - make (build/make script or run munkipkg) dependencies, 
#  - build signed main distribution pkg
#  - upload to Apple for notarization, staple to pkg afterwards


# write timestamp + message to stdout
function log() {
	timestamp=$(date +%Y-%m-%d\ %H:%M:%S%z)
	echo "$timestamp [auto-erase-install/build.zsh] $1"
}

# For reading stuff from plist files
PlistBuddy="/usr/libexec/PlistBuddy"

# Get this scripts starting folder, this is the main folder of this repo
# :A resolves symlinks, and :h truncates the last path component
#script_path=${0:A:h}
script_path="$(dirname $0)"
this_script="$0"

# get parent folder of this script, we'll build dependencies on leaf folders to this repo
dev_main="$(dirname $script_path)"
log "dev_main is: $dev_main"


# setup this repo
# assume it was installed manually by running 
#   git clone https://github.com/codeskipper/auto-erase-install.git
if [ ! -d "$dev_main/auto-erase-install/build/include-pkgs" ]; then 
	mkdir -p "$dev_main/auto-erase-install/build/include-pkgs"
	[[ $? ]] && log "added $dev_main/auto-erase-install/build/include-pkgs folder" || log "adding $dev_main/auto-erase-install/build/include-pkgs folder FAILED" 
fi


# dependency:
if [ ! "$(which munkipkg)" ]; then
	if [ ! -f "$dev_main/munki-pkg" ]; then
		git clone https://github.com/munki/munki-pkg.git
	fi
	cd munki-pkg
	sudo cp munkipkg /usr/local/bin/
		[[ $? ]] && log "added munki-pkg to /usr/local/bin/" || log "adding added munki-pkg to /usr/local/bin/ FAILED" 
fi


# dependency: 
# DEPNotify. Download only available without version designation. Need to expand to determine version.
log "Building dependency - DEPNotify"
cd "$dev_main/auto-erase-install/build/include-pkgs"
DEPNotify_exp="$PWD/DEPNotify.pkg.expanded"
if [[ ! -d "$DEPNotify_exp" || ! -f "DEPNotify.pkg" ]]; then 
	rm -f "DEPNotify*.pkg"
	rm -rf "$DEPNotify_exp"
	log "Downloading latest DEPNotify.pkg"
	# curl --remote-name --remote-header-name https://files.nomad.menu/DEPNotify.pkg # No use getting filename from remote headers
	curl https://files.nomad.menu/DEPNotify.pkg -o DEPNotify.pkg
	if [[ ! $? ]]; then
		log "failed to download latest DEPNotify"
		exit 1
	fi
	pkgutil --expand DEPNotify.pkg DEPNotify.pkg.expanded
fi
pkginfo="$DEPNotify_exp/PackageInfo"
if [[ -r "$pkginfo" ]]; then
	#pkgversion=$($PlistBuddy -c "print $CFBundleShortVersionString" "$infoplist")
	pkgversion=$(xmllint --xpath "string(//pkg-info/@version)" ${pkginfo})
else
	log "could not find $pkginfo"
	exit 1
fi
if [[ -n $pkgversion ]]; then
	DEPNotify_pkg="$PWD/DEPNotify-$pkgversion.pkg"
else
	log "Failed to find version of dependency DEPNotify, bailing out"
	exit 1
fi
if [[ ! -f "$DEPNotify_pkg" ]]; then
	ln -s "$PWD/DEPNotify.pkg" "$DEPNotify_pkg"
	if [[ ! $? ]]; then
		log "Failed to provide $DEPNotify_pkg"
		exit 1
	fi
fi
log "Building dependency - DEPNotify - DONE"


# dependency: (codeskipper fork) of https://github.com/grahampugh/erase-install.git (for developing DEPnotify integration)
log "Building dependency - erase-install"
if [ ! -d "$dev_main/erase-install" ]; then
	cd "$dev_main"
	#git clone https://github.com/codeskipper/erase-install.git
	log "Cloning from Github to $dev_main/erase-install"
	git clone https://github.com/grahampugh/erase-install.git
fi
cd "$dev_main/erase-install"
log "Updating $dev_main/erase-install"
git pull
#git checkout main
make
if [[ ! $? ]]; then
	log "make in $dev_main/erase-install FAILED"
	exit 1
else
	log "make in $dev_main/erase-install DONE"
fi 
erase_install_version=$($PlistBuddy -c "Print :version" $dev_main/erase-install/pkg/erase-install/build-info.plist)
erase_install_pkg="$dev_main/erase-install/pkg/erase-install/build/erase-install-$erase_install_version.pkg"
if [[ ! -f "$erase_install_pkg" ]]; then
	log "Could not find $erase_install_pkg - bailing out"
	exit 1
fi
log "Building dependency - erase-install - DONE"


# erase-install-runner pkg to automate running erase-install
log "Building dependency - erase-install-runner"
erase_install_runner_version=$($PlistBuddy -c "Print :version" "$dev_main/auto-erase-install/erase-install-runner/build-info.plist")
#ToDo: check if payload files are newer than pkg to see if it needs building
munkipkg "$dev_main/auto-erase-install/erase-install-runner"
munkipkg --export-bom-info "$dev_main/auto-erase-install/erase-install-runner"
erase_install_runner_pkg="$dev_main/auto-erase-install/erase-install-runner/build/erase-install-runner-$erase_install_runner_version.pkg"
if [[ ! -f "$erase_install_runner_pkg" ]]; then
	log "Could not find $erase_install_runner_pkg - bailing out"
	exit 1
fi
# if [ ! -f "$dev_main/auto-erase-install/build/include-pkgs/erase-install-runner-$erase-install-runner-version.pkg" ]; then
# 	ln -sf "$dev_main/auto-erase-install/erase-install-runner/build/erase-install-runner-$erase-install-runner-version.pkg" "$dev_main/auto-erase-install/build/include-pkgs/"
# fi
log "Building dependency - erase-install-runner DONE"

# test with distribution manifest
#productbuild --synthesize --package "$dev_main/pkgs/erase-install-0.17.3.pkg --package pkgs/erase-install-runner-0.01.pkg auto-erase-install-distribution.xml



# Confidential settings for building and notarization should be in build-secrets.plist and we read variables from it. 
# Secrets file is in .gitignore, and a build-secrets-example.plist is available for use as template in git
log "Reading Build secrets"
build_secrets_file="$dev_main/auto-erase-install/build-secrets.plist"
if [[ ! -f "$build_secrets_file" ]]; then
	log "Could not find $build_-secrets_file - please copy it from the example file and update with your settings"
	exit 1
fi
appl_dev_id=$($PlistBuddy -c "Print :appl-dev-id" "$build_secrets_file")
appl_dev_account=$($PlistBuddy -c "Print :appl-dev-account" "$build_secrets_file")
appl_dev_keychain_item=$($PlistBuddy -c "Print :appl-dev-keychain-item" "$build_secrets_file")


# use version variables for building
# ToDo: check if components are newer than existing pkg to see if it needs building
auto_erase_install_version=$($PlistBuddy -c "Print :version" "$dev_main/auto-erase-install/build-info.plist")
cd "$dev_main/auto-erase-install/build"
log "Building auto-erase-install distribution package"
productbuild --package "$erase_install_pkg" \
    --package "$DEPNotify_pkg" \
    --package "$erase_install_runner_pkg" \
    --sign "$appl_dev_id" \
    "auto-erase-install-$auto_erase_install_version.pkg"
log "Building auto-erase-install distribution package DONE"

#echo "Proceed to notarization?"
read 'go?Proceed to notarization([y]/n)? ' </dev/tty
if [[ "$go" == 'n' ]]; then
	log "Aborting build as prompted after productbuild, before notarization"
	exit 0
fi

altool_cmd=$(xcrun -find altool)
if [[ ! -n $altool_cmd ]]; then
	log "unable to find altool for notarization and stapling"
	exit 1
fi
# check password is in keychain item, if not, ask for it and store in keychain
log "Accessing login keychain to find item: $appl_dev_keychain_item and password for account: $appl_dev_account"
appl_dev_keychain_item_present=$(security find-generic-password -s "$appl_dev_keychain_item" -a "$appl_dev_account")
if [[ ! -n $appl_dev_keychain_item_present ]]; then
	echo "Please enter your developer App password for notarization in order to add it to your login keychain"
	read -rs 'pw?Password: ' </dev/tty
	# Do not use altool --store-password-in-keychain-item because that puts it out-of-reach in Local items keychain
	#xcrun altool --store-password-in-keychain-item "$appl_dev_keychain_item" -u "$appl_dev_account" -p "$pw"
	security add-generic-password -s "$appl_dev_keychain_item" -a "$appl_dev_account" -T "$altool_cmd" -w "$pw"
else
	log "$appl_dev_keychain_item found"
fi


# Notarization
log "Uploading auto-erase-install-$auto_erase_install_version.pkg to Apple for notarization"
xcrun altool \
	--notarize-app \
	--primary-bundle-id no.datamind.auto-erase-install \
	--username "$appl_dev_account" \
	--password "@keychain:$appl_dev_keychain_item" \
	--file "auto-erase-install-$auto_erase_install_version.pkg" \
	--output-format xml \
	1> notarization_upload.xml 2> notarization-errors.txt
myRequestID=$($PlistBuddy -c "Print :notarization-upload:RequestUUID" "notarization_upload.xml")
if [[ ! -n $myRequestID ]]; then
	log "Notarization request failed to upload, altool output:"
	cat notarization_upload.xml
	rm -f notarization_upload.xml
	exit 1
else
	log "Notarization request submitted to Apple - ID: $myRequestID"
	rm -f notarization_upload.xml
	rm -f notarization-errors.txt
fi


#xcrun altool --notarization-history -u "$appl-dev-account" -p "@keychain:$appl_dev_keychain_item"
log "waiting on notarization"
while true; do
	xcrun altool \
		--notarization-info $myRequestID \
		--username "$appl_dev_account" \
		--password "@keychain:$appl_dev_keychain_item" \
		--output-format xml \
		1> notatization_info.xml 2> notarization_errors.txt
	not_status=$($PlistBuddy -c "Print :notarization-info:Status" "notatization_info.xml")
	case $not_status in 
		'invalid')
			log "Notarization failed"
			exit 1
			;;
		'success')
			log "Notarization success"
			rm -f notarization-errors.txt
			break
			;;
		'in progress')
			log "Notarization not ready yet, sleeping 60s"
			sleep 60
		;;
		*)
			log "Notarization status: $not_status, sleeping 60s"
			sleep 60
	esac
done
rm -f notarization-errors.txt


#log "script is working so far, beyond here there be dragons"
#exit 0


# Stapling
log "proceeding to staple the notarized app"
xcrun stapler staple "auto-erase-install-$auto_erase_install_version.pkg"


read 'show_log?Would you like to review the Apple Notarization log (y/[n])? ' </dev/tty
if [[ $show_log == 'y' ]]; then
	LogFileURL=$($PlistBuddy -c "Print :notarization-info:LogFileURL" "notatization_info.xml")
	curl "$LogFileURL" -o notarization_log.json
	less notarization_log.json
fi

log "Thanks for watching"
exit 0
