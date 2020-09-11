#!/usr/bin/env sh

#
#   Post installer script for the SAP Privileges App.
#
#   Once Privileges is installed the installer will attempt to de-elevate the logged-in
#   user automatically.
#
#   Dependencies
#
#       dockutil - Used to move the Privileges app to the macOS Dock.
#                - Must be installed on the Mac prior to running this script.
#                - Example script at
#                - Repo: https://github.com/captam3rica/dockutil.
#                - This version of dockutil is a fork from the original repo. Forked
#                  becasue the original was not python 3 ready when this script was
#                  created.
#


APP_NAME="Privileges.app"
POSITION="1"
LAUNCH_DAEMON="/Library/LaunchDaemons/corp.sap.privileges.helper.plist"
PRIVILEGES_CHECKER_LA="/Library/LaunchAgents/com.github.captam3rica.privileges.checker.plist"


get_current_user() {
    # Return the current logged-in user
    printf '%s' "show State:/Users/ConsoleUser" | \
        /usr/sbin/scutil | \
        /usr/bin/awk '/Name :/ && ! /loginwindow/ {print $3}'
}


get_current_user_uid() {
    # Return the current logged-in user's UID.
    # Will continue to loop until the UID is greater than 500
    # Takes the current logged-in user as input $1

    current_user="$1"

    current_user_uid=$(/usr/bin/dscl . -list /Users UniqueID | \
        /usr/bin/grep "$current_user" | /usr/bin/awk '{print $2}' | \
        /usr/bin/sed -e 's/^[ \t]*//')

    while [ "$current_user_uid" -lt 501 ]; do
        /usr/bin/logger "" "Current user is not logged in ... WAITING"
        /bin/sleep 1

        # Get the current console user again
        current_user="$(get_current_user)"

        # Get uid again
        current_user_uid=$(/usr/bin/dscl . -list /Users UniqueID | \
            /usr/bin/grep "$current_user" | /usr/bin/awk '{print $2}' | \
            /usr/bin/sed -e 's/^[ \t]*//')

        if [ "$current_user_uid" -lt 501 ]; then
            /usr/bin/logger "" "Current user: $current_user with UID ..."
        fi
    done
    printf "%s\n" "$current_user_uid"
}


current_privileges() {
    # Return the current logged-in users group membership.
    #
    # Returns admin if the user is a member of the local admin group. Returns standard
    # if the user is a member of the standard users group "aka not an admin."
    #
    cu="$1"

    # Returns true if the current logged in user is a member of the local admins group.
    group_membership=$(/usr/bin/dscl . read /groups/admin | /usr/bin/grep "$cu")
    RET="$?"

    if [ "$RET" -eq 0 ]; then
        # User is in the admin group
        status="admin"
    else
        # User is not in the admin group
        status="standard"
    fi

    printf "%s\n" "$status"
}


move_app_to_dock() {
    # Use dockutil to move an app to the macOS dock.
    # See if dockutil is installed
    #
    # Args
    #   $1: /path/to/app.app
    #   $2: Postion in the Dock. (1 would be right after Finder.app, which is the first
    #       app in the Dock.)
    if [ -e "/usr/local/bin/dockutil" ]; then

        # See if the Privileges app is installed in /Applications
        if [ -e "$1" ]; then
            echo "Using dockutil to move Privileges.app to the user's Dock ..."
            /bin/launchctl asuser "$current_user_uid" \
                /usr/bin/sudo -u "$current_user" \
                /usr/local/bin/dockutil --add "$1" --position "$2"

        else
            echo "$1 is not installed ..."
            echo "The current user's dock has not been modified ..."
            exit 1
        fi

    else
        echo "dockutil is not installed ..."
        echo "The current user's dock has not been modified ..."
        exit 1
    fi
}


main() {
    # Run main logic

    current_user="$(get_current_user)"
    current_user_uid="$(get_current_user_uid $current_user)"

    # Load the LaunchDaemon
    if [ -f "$LAUNCH_DAEMON" ]; then
        # Load the daemon
        /bin/launchctl load "$LAUNCH_DAEMON"

        # Capture the truthy or falsy of the previous command
        RET="$?"

        if [ "$RET" -ne 0 ]; then
            # Daemon failed to load
            /usr/bin/logger "Failed to load $LAUNCH_DAEMON ..."
            exit "$RET"
        fi

        /usr/bin/logger "$APP_NAME LaunchDaemon installation completed"

    else
        /usr/bin/logger "$LAUNCH_DAEMON not found ..."
    fi

    # Load privilegschecker LaunchAgent if present
    # This needs to be loaded as the current logged in user otherwise this will load
    # the next time a user logs in.
    if [ -f "$PRIVILEGES_CHECKER_LA" ]; then
        # Load the agent
        /bin/launchctl asuser "$current_user_uid" /usr/bin/sudo -u \
            "$current_user" /bin/launchctl load "$PRIVILEGES_CHECKER_LA"

        # Capture the truthy or falsy of the previous command
        RET="$?"

        if [ "$RET" -ne 0 ]; then
            # Daemon failed to load
            /usr/bin/logger "Failed to load $PRIVILEGES_CHECKER_LA ..."
            exit "$RET"
        fi

        /usr/bin/logger "$APP_NAME privilegeschecker LaunchAgent installation completed"

    else
        /usr/bin/logger "$PRIVILEGES_CHECKER_LA not found ..."
    fi

    # Remove the logged-in user from the admin group
    /bin/launchctl asuser "$current_user_uid" sudo -u "$current_user" /Applications/Privileges.app/Contents/Resources/PrivilegesCLI --remove

    # Check the user's privileges
    current_privileges_status="$(current_privileges $current_user)"

    if [ "$current_privileges_status" = "standard" ]; then
        # Remove the user from the admin group
        # Log current logged-in user's privileges after the command runs.
        /usr/bin/logger "" "Current logged-in user's previleges set to standard ..."
    else
        /usr/bin/logger "" "Current logged-in user's previleges remain set to admin ..."
    fi

    # Wait for for dockutil
    /bin/echo "Waiting some time for dockutil to be ready ..."
    /bin/sleep 90

    # Move the app
    /bin/echo "Attempting to move $APP_NAME to the Dock ..."
    move_app_to_dock "/Applications/$APP_NAME" "$POSITION"
}


# Run main
main
