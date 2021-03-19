#!/bin/zsh

# Beginnings of a script to get, update, and build auto-erase-install distribution package and it's dependencies.
# Workflow is to 
#  - git clone dependencies into leaf folders beside this repo main folder, then 
#  - make (build/make script or munkipkg) dependencies, 
#  - symlink dependencies into build/include-pkgs folder in this repo
#  - build main distribution pkg
#  - git commit for distribution pkg
#  - repeat 
#      - update local git repo or it's dependencies, commit and git push origin
#      - make dependencies, 
#      - update dependency symlinks
#      - update distribution XML to use latest versions of packages, erase-pkg-runner to be installed as last in chain
#      - build main distribution pkg
#      - git commit for distrubution pkg

# WORK IN PROGRESS
# in the process of converting notes of manual commands to variables for commands and adding sanity checks 

# write timestamp + message to stdout
function log() {
	timestamp=$(date +%Y-%m-%dT%H:%M:%S%z)
	echo "$timestamp [auto-erase-install/build.sh] $1"
}


PlistBuddy="/usr/libexec/PlistBuddy"

# Get this scripts starting folder, this is the main folder of this repo
# :A resolves symlinks, and :h truncates the last path component
#script_path=${0:A:h}
script_path="$(dirname $0)"

# get parent folder of this script, we'll build dependencies on leaf folders to this repo
dev_main="$(dirname $script_path)"
log "dev_main is: $dev_main"


# setup this repo
# assume it was installed manually by running 
#   git clone https://github.com/codeskipper/auto-erase-install.git
if [ ! -f "$dev_main/auto-erase-install/build/include-pkgs" ]; then 
	mkdir -p "$dev_main/auto-erase-install/build/include-pkgs"
	[[ $? ]] && log "added build/include-pkgs folder" || log "adding build/include-pkgs folder FAILED" 
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
if [ ! -f "$dev_main/auto-erase-install/build/include-pkgs/DEPNotify-1.1.6.pkg" ]; then 
	cd "$dev_main/auto-erase-install/build/include-pkgs/"
	curl https://files.nomad.menu/DEPNotify.pkg -o DEPNotify-1.1.6.pkg
	[[ $? ]] && log "downloaded DEPNotify-1.1.6.pkg to build/include-pkgs/" || log "downloading DEPNotify-1.1.6.pkg to build/include-pkgs/ FAILED"
fi


# dependency: codeskipper fork of https://github.com/grahampugh/erase-install.git for developing DEPnotify integration
if [ ! -d "$dev_main/erase-install" ]; then
	cd "$dev_main"
	git clone https://github.com/codeskipper/erase-install.git
fi
cd "$dev_main/erase-install"
make
if [[ ! $? ]]; then
	log "make in $dev_main/erase-install FAILED"
	exit 1
else
	log "make in $dev_main/erase-install DONE"
fi 
erase-install-version=$(PlistBuddy -c Print:version $dev_main/erase-install/pkg/erase-install/build-info.plist)
if [[ ! -f "$dev_main/auto-erase-install/build/include-pkgs/erase-install-$erase-install-version.pkg" ]]; then
	ln -sf "$dev_main/erase-install/build/erase-install-$erase-install-version.pkg" "$dev_main/auto-erase-install/build/include-pkgs/"
fi


# erase-install-runner pkg to automate running erase-install
erase-install-runner-version=$(PlistBuddy -c Print:version $dev_main/auto-erase-install/erase-install-runner/build-info.plist)
#ToDo: check if payload files are newer than pkg to see if it needs building
munkipkg "$dev_main/auto-erase-install/erase-install-runner"
munkipkg --export-bom-info "$dev_main/auto-erase-install/erase-install-runner"
if [ ! -f "$dev_main/auto-erase-install/build/include-pkgs/erase-install-runner-$erase-install-runner-version.pkg" ]; then
	ln -sf "$dev_main/auto-erase-install/erase-install-runner/build/erase-install-runner-$erase-install-runner-version.pkg" "$dev_main/auto-erase-install/build/include-pkgs/"
fi

# test with distribution manifest
#productbuild --synthesize --package "$dev_main/pkgs/erase-install-0.17.3.pkg --package pkgs/erase-install-runner-0.01.pkg auto-erase-install-distribution.xml


# script is working until here, beyond there be dragons
exit 0


# ToDo: put confidential settings for building and notarization in build-secrets.plist and read variables from it. Should be in .gitignore, and add a build-secrets-example.plist to git


# ToDo: use version variables for building
cd "$dev_main/auto-erase-install/build"
productbuild --package "$dev_main/auto-erase-install/build/include-pkgs/erase-install-0.18.0.pkg" \
    --package "$dev_main/auto-erase-install/build/include-pkgs/DEPnotify-1.1.6.pkg" \
    --package "$dev_main/auto-erase-install/build/include-pkgs/erase-install-runner-0.02.pkg" \
    --sign "Developer ID Installer: macDevPlaceHolder (XYZ123456)" \
    auto-erase-install-0.02.pkg


# Notarization
# ToDo - automate like in https://stackoverflow.com/a/63348606/4326287
xcrun altool --store-password-in-keychain-item APPLE_DEV_account -u my_apple_dev_account@mac.com -p mySecretOne

xcrun altool --notarize-app -f auto-erase-install-0.02.pkg --primary-bundle-id no.datamind.auto-erase-install -u my_apple_dev_account@mac.com -p @keychain:APPLE_DEV_account

xcrun altool --notarization-history -u my_apple_dev_account@mac.com -p @keychain:APPLE_DEV_account


# Stapling
xcrun stapler staple auto-erase-install-0.02.pkg