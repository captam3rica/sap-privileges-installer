#!/usr/bin/env sh

#
#   Post installer script for the SAP Privileges App.
#
#   Once Privileges is installed the installer will attempt to de-elevate the logged-in
#   user automatically.
#
#   dockutil is used to move the application to the current user's dock.
#
#   Dependencies
#
#       dockutil - Used to move the Privileges app to the macOS Dock.
#                - Must be installed on the Mac prior to running this script.
#                - Example script at
#                - Repo: https://github.com/captam3rica/dockutil.
#                   - This version of dockutil is a fork from the original repo. Forked
#                     becasue the original was not python 3 ready when this script was
#                     created.
#


#######################################################################################
################################ VARIABLES ############################################
#######################################################################################

APP_NAME="Privileges.app"

# This is the location in the user's dock where we want to place the app.
# Position 1 is the spot just after the Finder.app icon.
POSITION="1"

LAUNCH_DAEMON="/Library/LaunchDaemons/corp.sap.privileges.helper.plist"
PRIVILEGES_CHECKER_LA="/Library/LaunchAgents/com.github.captam3rica.privileges.checker.plist"


#######################################################################################
####################### FUNCTIONS - DO NOT MODIFY #####################################
#######################################################################################


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


#######################################################################################
#################### MAIN LOGIC - DO NOT MODIFY #######################################
#######################################################################################


main() {
    # Run main logic

    # Get the current logged in user and uid
    current_user="$(get_current_user)"
    current_user_uid="$(get_current_user_uid $current_user)"

    /usr/bin/logger "Current logged in user: $current_user"
    /usr/bin/logger "Current logged in UID: $current_user_uid"

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
    /usr/bin/logger "Waiting some time for dockutil to be ready ..."
    /bin/sleep 90

    # Move the app
    /usr/bin/logger "Attempting to move $APP_NAME to the Dock of $current_user ..."
    # move_app_to_dock "/Applications/$APP_NAME" "$POSITION" "$current_user" "$current_user_uid"

    # Use dockutil to move an app to the macOS dock.
    # See if dockutil is installed
    #
    # Args
    #   $1: /path/to/app.app
    #   $2: Postion in the Dock. (1 would be right after Finder.app, which is the first
    #       app in the Dock.)
    #   $3: The current_user var passed in
    #   $4: current user's UID
    if [ -e "/usr/local/bin/dockutil" ]; then

        # See if the Privileges app is installed in /Applications before trying to move
        if [ -e "/Applications/$APP_NAME" ]; then

            # Use dockutil to check for the app in the current users dock
            check_priv_in_dock=$(/usr/local/bin/dockutil \
                --find 'Privileges' /Users/"$current_user" | grep "was found")

            # If the app is not found in the current user's dock use dockutil to add
            # the app to the current user's dock.
            if [ -z "$check_priv_in_dock" ]; then
                # Use dockutil to add app to user's dock.
                /usr/bin/logger "Using dockutil to add $APP_NAME to the user's Dock ..."
                dockutil_response=$(/usr/local/bin/dockutil \
                    --add "/Applications/$APP_NAME" --position "$POSITION" --allhomes)
                # Log the dockutil output received from the --add command.
                /usr/bin/logger "$dockutil_response"

            else
                # If the app is already in the current user's dock make sure that it is
                # in the first position by using the dockutil --move command.
                /usr/bin/logger "Not attempting to add via dockutil, going to move ..."
                move_response=$(/usr/local/bin/dockutil --move 'Privileges' \
                    --position "$POSITION" --allhomes)

                # Log the response.
                 /usr/bin/logger "$move_response"

            fi

        else
            /usr/bin/logger "$APP_NAME is not installed ..."
            /usr/bin/logger "The current user's dock has not been modified ..."
            exit 1
        fi

    else
        /usr/bin/logger "dockutil is not installed ..."
        /usr/bin/logger "The current user's dock has not been modified ..."
        # exit 1
    fi
}


# Run main
main
