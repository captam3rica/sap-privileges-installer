#!/usr/bin/env sh

# GitHub: @captam3rica

#
#   A post-install script to launch the SAP Privileges.app uninstaller.
#


RESULT=0

# Define the current working directory
HERE=$(/usr/bin/dirname "$0")

PKG_INST_SCRIPT_NAME="privileges_uninstaller.sh"
PKG_INST_SCRIPT_PATH="$HERE/$PKG_INST_SCRIPT_NAME"

main() {
    /usr/bin/logger "Setting permissions on the package installer script ..."
    /bin/chmod 755 "$PKG_INST_SCRIPT_PATH"

    /usr/bin/logger "Launching the package installer script ..."
    /bin/sh "$PKG_INST_SCRIPT_PATH"
}

# Call main
main

exit "$RESULT"
