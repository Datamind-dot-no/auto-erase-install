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

# just making notes of manual commands at this stage and substituting variables


$dev_main="$HOME/dev"
mkdir -p "$dev_main"
cd "$dev_main"

# dependency:
git clone https://github.com/munki/.git
cd munki-pkg
sudo cp munkipkg /usr/local/bin/

# clone this repo
git clone https://github.com/codeskipper/auto-erase-install.git
mkdir -p "$dev_main/auto-erase-install/build/include-pkgs"

# erase-install-runner pkg to automate running erase-install
munkipkg "$dev_main/auto-erase-install/erase-install-runner"
ln -s "$dev_main/auto-erase-install/erase-install-runner/build/erase-install-runner-0.01.pkg" "$dev_main/auto-erase-install/build/include-pkgs/"

# dependency: codeskipper fork of https://github.com/grahampugh/erase-install.git for developing DEPnotify integration
git clone https://github.com/codeskipper/erase-install.git

# test with distribution manifest
#productbuild --synthesize --package "$dev_main/pkgs/erase-install-0.17.3.pkg --package pkgs/erase-install-runner-0.01.pkg auto-erase-install-distribution.xml

cd "$dev_main/auto-erase-install/build"
productbuild --package "$dev_main/auto-erase-install/build/include-pkgs/erase-install-0.17.3.pkg" --package "$dev_main/auto-erase-install/build/include-pkgs/erase-install-runner-0.01.pkg" auto-erase-install-0.01.pkg

## new round adding dependency DEPnotify, new version erase-install-0.18.pkg, new version of erase-install-runner pkg
cd $dev_main/erase-install
git pull
make
ln -s "$dev_main/auto-erase-install/erase-install-runner/build/erase-install-0.18.0.pkg" "$dev_main/auto-erase-install/build/include-pkgs/"

munkipkg "$dev_main/auto-erase-install/erase-install-runner"
munkipkg --export-bom-info "$dev_main/auto-erase-install/erase-install-runner"
ln -s "$dev_main/auto-erase-install/erase-install-runner/build/erase-install-runner-0.02.pkg" "$dev_main/auto-erase-install/build/include-pkgs/"

cd "$dev_main/auto-erase-install/build/include-pkgs/"
curl https://files.nomad.menu/DEPNotify.pkg -o DEPNotify-1.1.6.pkg

ln -s "$dev_main/auto-erase-install/auto-erase-install-resources/auto-erase-install.png" "$dev_main/auto-erase-install/erase-install-runner/payload/Library/Management/erase-install/Resources"

cd "$dev_main/auto-erase-install/build"
productbuild --package "$dev_main/auto-erase-install/build/include-pkgs/erase-install-0.18.0.pkg" \
    --package "$dev_main/auto-erase-install/build/include-pkgs/DEPnotify-1.1.6.pkg" \
    --package "$dev_main/auto-erase-install/build/include-pkgs/erase-install-runner-0.02.pkg" \
    --sign "Developer ID Installer: macDevPlaceHolder (XYZ123456)" \
    auto-erase-install-0.02.pkg

