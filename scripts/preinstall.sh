#!/usr/bin/env sh

#
#   Pre installer script for the SAP Privileges App.
#
#   Once Privileges is installed the installer will attempt to de-elevate the logged-in
#   user automatically.
#


APP_NAME="SAP Enterprise Privileges"
LAUNCH_DAEMON_LABEL="/Library/LaunchDaemons/corp.sap.privileges.helper"
LAUNCH_DAEMON="/Library/LaunchDaemons/corp.sap.privileges.helper.plist"
PRIVILEGES_CHECKER_LA_LABEL="/Library/LaunchAgents/com.github.captam3rica.privileges.checker"
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
        /usr/bin/grep "$current_user" | \
        /usr/bin/awk '{print $2}' | \
        /usr/bin/sed -e 's/^[ \t]*//')

    while [ "$current_user_uid" -lt 501 ]; do
        /usr/bin/logger "" "Current user is not logged in ... WAITING"
        /bin/sleep 1

        # Get the current console user again
        current_user="$(get_current_user)"

        # Get uid again
        current_user_uid=$(/usr/bin/dscl . -list /Users UniqueID | \
            /usr/bin/grep "$current_user" | \
            /usr/bin/awk '{print $2}' | \
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
    group_membership=$("$DSCL" . read /groups/admin | /usr/bin/grep "$cu")
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


main() {
    # Run main logic

    current_user="$(get_current_user)"
    current_user_uid="$(get_current_user_uid $current_user)"

    # Stop and Unload the LaunchDaemon
    if [ -f "$LAUNCH_DAEMON" ]; then
        # Stop the LaunchDaemon
        /bin/launchctl stop "$LAUNCH_DAEMON_LABEL"

        # Unload the daemon
        /bin/launchctl unload "$LAUNCH_DAEMON"

        # Capture the truthy or falsy of the previous command
        RET="$?"

        if [ "$RET" -ne 0 ]; then
            # Daemon failed to load
            /usr/bin/logger "Failed to unload $LAUNCH_DAEMON ..."
            exit "$RET"
        fi

        /usr/bin/logger "$APP_NAME LaunchDaemon unload completed"

    else
        /usr/bin/logger "$LAUNCH_DAEMON not found ..."
    fi

    # Stup adn unload privilegschecker LaunchAgent if present
    # This needs to be loaded as the current logged in user otherwise this will load
    # the next time a user logs in.
    if [ -f "$PRIVILEGES_CHECKER_LA" ]; then

        # Stop the agent
        /bin/launchctl asuser "$current_user_uid" /usr/bin/sudo -u \
            "$current_user" --login /bin/launchctl stop "$PRIVILEGES_CHECKER_LA_LABEL"

        # Unload the agent
        /bin/launchctl asuser "$current_user_uid" /usr/bin/sudo -u \
            "$current_user" --login /bin/launchctl unload "$PRIVILEGES_CHECKER_LA"

        # Capture the truthy or falsy of the previous command
        RET="$?"

        if [ "$RET" -ne 0 ]; then
            # Daemon failed to load
            /usr/bin/logger "Failed to unload $PRIVILEGES_CHECKER_LA ..."
            exit "$RET"
        fi

        /usr/bin/logger "$APP_NAME privilegeschecker LaunchAgent unload completed"

    else
        /usr/bin/logger "$PRIVILEGES_CHECKER_LA not found ..."
    fi

}

# Run main
main
