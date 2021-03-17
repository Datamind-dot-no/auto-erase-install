# auto-erase-install
automate running [Graham Pugh](https://github.com/grahampugh)'s [erase-install.sh](https://github.com/grahampugh/erase-install) with user feedback and getting user confirmation using [DEPnotify](https://gitlab.com/Mactroll/DEPNotify), rolled into a standalone distribution pkg

Primary use-case for this standalone package is to erase and reinstall a Mac which is not (yet) enrolled into MDM. 

As the process normally takes about 15-30 minutes, some user feedback is called for while waiting. 

[erase-install.sh](https://github.com/grahampugh/erase-install) uses jamfHelper for user feedback, but it's license does not permit bundling it to use separately from JAMF Pro as far as I could tell. DEPNotify was chosen as an alternative user feedback utility. 

DEPNotify is used to get user confirmation before proceeding to use `erase-install.sh` to check for and download macOS installer if needed, and before running it again with `-erase`.
The window is visible during macOS installer download phase and while macOS Installer' startos is preparing erase-install. 

`erase-install.sh` uses osascript to prompt the user for account name and password on Apple Silicon M1 Macs when running erase and/or install. If and when [Erase&Install](https://bitbucket.org/prowarehouse-nl/erase-install/src/master/) is updated to support Apple Silicon, it will likely be a pretty good alternative ;-)

The auto-erase-install.sh script is persisted with a Launch Daemon to easily run it again if it would fail or abort the first time.
The LaunchDaemon redirects script output to a logfile at `/var/log/auto-erase-install.log` for debugging purposes. Output from erase-install.sh can also be found there.

`diskutil apfs updatepreboot /` is run on an M1 before calling erase-install.sh to avoid an issue with `startos -erase-install` failing to recognize an admin user as such.
