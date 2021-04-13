![auto-erase-install icon](/auto-erase-install-resources/auto-erase-install.png)

# auto-erase-install
automate running [Graham Pugh](https://github.com/grahampugh)'s [erase-install.sh](https://github.com/grahampugh/erase-install) with user feedback and getting user confirmation using [DEPnotify](https://gitlab.com/Mactroll/DEPNotify), rolled into a standalone distribution pkg

Primary use-case for this standalone package is to erase and reinstall a Mac which is not (yet) enrolled into MDM. 

**WARNING. This is a self-destruct script. Do not try it out on your own device!**

Easier than using Recovery mode for a not so tech savvy user, and does not require a lengthy user instruction to cover different macOS versions. Especially helpful if the Mac has a firmware password set, an admin user does not need the firmware password to erase and reinstall this way.

Works on Macs running macOS High Sierra version 13.x or later due to APFS requirement for the -erase-install option in macOS installers' startosinstall.  Runs on either Intel or Apple Silicon M1 Macs.

As the process normally takes about 15-30 minutes, some user feedback is called for while waiting. 

[erase-install.sh](https://github.com/grahampugh/erase-install) uses jamfHelper for user feedback. As far as I could tell, jamfHelper's license does not permit using it separately from JAMF Pro. DEPNotify was chosen as an alternative user feedback utility to avoid the dependency on jamfHelper. DEPNotify is also a good fit to provide continuous user feedback during the lengthy macOS installer download and Preparing phases. 

DEPNotify is used to get user confirmation before proceeding to use `erase-install.sh` to check for and download macOS installer if needed, and before running it again with `-erase`.
The window is visible during macOS installer download phase and while macOS Installer' startos is preparing erase-install. 

`erase-install.sh` uses osascript to prompt the user for account name and password on Apple Silicon M1 Macs when running erase and/or install. If and when [Erase&Install](https://bitbucket.org/prowarehouse-nl/erase-install/src/master/) is updated to support Apple Silicon, it will likely be a pretty good alternative ;-)

The auto-erase-install.sh script is persisted with a Launch Daemon to easily run it again if it would fail or abort the first time.
The LaunchDaemon redirects script output to a logfile at `/var/log/auto-erase-install.log` for debugging purposes. Output from erase-install.sh can also be found there. 

A signed and notarized package is available in [the releases](https://github.com/Datamind-dot-no/auto-erase-install/releases) That helps to make it trustworthy and easy to install for end-users.

Screenshots for a (debug) run are in [this wiki page](https://github.com/Datamind-dot-no/auto-erase-install/wiki/auto-erase-install---doing-it-manually)

Building the package is done by running the `build.zsh` script. In order to do so, you need to prepare a `build-secrets.plist` file with your Apple developer settings for signing and notarizing the package. You can copy `build-secrets-example.plist` to use as a template.

Release 0.1.0 uses the --update command in the call to `erase-install.sh` in order to get the latest macOS version available. If you need an updated version that keeps the same macOS version instead of upgrading, you can add the "--sameOS" argument in `auto-erase-install.sh`.