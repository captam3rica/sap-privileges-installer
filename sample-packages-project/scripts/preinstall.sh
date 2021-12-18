#!/usr/bin/env sh

#
#   Pre installer script for the SAP Privileges App.
#
#   Checks for and unloads the privileges daemon and privilegschecker daemon as we ll
#   as the privileges helper before installing the app.
#

#######################################################################################
################################ VARIABLES ############################################
#######################################################################################

# Put the app name here
APP_NAME="Privileges.app"

# LaunchDaemons and Labels
LAUNCH_DAEMON_LABEL="/Library/LaunchDaemons/corp.sap.privileges.helper"
LAUNCH_DAEMON="/Library/LaunchDaemons/corp.sap.privileges.helper.plist"

# LaunchAgents and Labels
PRIVILEGES_CHECKER_LA_LABEL="/Library/LaunchAgents/com.github.captam3rica.privileges.checker"
PRIVILEGES_CHECKER_LA="/Library/LaunchAgents/com.github.captam3rica.privileges.checker.plist"
PRIVILEGES_CHECKER_SCRIPT="/Library/Scripts/mdmhelpers/privilegeschecker.zsh"

# Helpers and scripts
PRIVS_HELPER="/Library/PrivilegedHelperTools/corp.sap.privileges.helper"

#######################################################################################
####################### FUNCTIONS - DO NOT MODIFY #####################################
#######################################################################################

get_current_user() {
    # Return the current logged-in user
    printf '%s' "show State:/Users/ConsoleUser" | /usr/sbin/scutil |
        /usr/bin/awk '/Name :/ && ! /loginwindow/ {print $3}'
}

get_current_user_uid() {
    # Return the current logged-in user's UID.
    # Will continue to loop until the UID is greater than 500

    current_user_uid=$(/usr/bin/id -u "$(get_current_user)")

    while [ "$current_user_uid" -lt 501 ]; do
        /usr/bin/logger "" "Current user is not logged in ... WAITING"
        /bin/sleep 1

        # Get the current console user again
        current_user="$(get_current_user)"

        # Get uid again
        current_user_uid=$(/usr/bin/id -u "$(get_current_user)")

        if [ "$current_user_uid" -lt 501 ]; then
            /usr/bin/logger "Current user: $current_user with UID ..."
        fi
    done
    printf "%s\n" "$current_user_uid"
}

#######################################################################################
#################### MAIN LOGIC - DO NOT MODIFY #######################################
#######################################################################################

main() {
    # Run main logic

    current_user="$(get_current_user)"
    current_user_uid="$(get_current_user_uid)"

    # Stop and Unload the LaunchDaemon
    if [ -f "$LAUNCH_DAEMON" ]; then
        # Stop the LaunchDaemon
        /bin/launchctl stop "$LAUNCH_DAEMON_LABEL" >/dev/null 2>&1

        # Unload the daemon
        /bin/launchctl unload "$LAUNCH_DAEMON" >/dev/null 2>&1

        /usr/bin/logger "$APP_NAME LaunchDaemon unload completed"

    else
        /usr/bin/logger "$LAUNCH_DAEMON not found ..."
    fi

    # Stop and unload privilegschecker LaunchAgent if present
    # This needs to be loaded as the current logged in user otherwise this will load
    # the next time a user logs in.
    if [ -f "$PRIVILEGES_CHECKER_LA" ]; then

        # Stop the agent
        /bin/launchctl asuser "$current_user_uid" /usr/bin/sudo -u \
            "$current_user" /bin/launchctl stop "$PRIVILEGES_CHECKER_LA_LABEL" >/dev/null 2>&1

        # Unload the agent
        /bin/launchctl asuser "$current_user_uid" /usr/bin/sudo -u \
            "$current_user" /bin/launchctl unload "$PRIVILEGES_CHECKER_LA" >/dev/null 2>&1

        /usr/bin/logger "$APP_NAME privilegeschecker LaunchAgent unload completed"

    else
        /usr/bin/logger "$PRIVILEGES_CHECKER_LA not found ..."
    fi

    # Look for the privileges helper. Removes if it exists.
    # This needs to be done in the case of an application upgrade. The helper version
    # and app version must match.
    if [ -f "$PRIVS_HELPER" ]; then
        /bin/rm "$PRIVS_HELPER"
        /usr/bin/logger "$PRIVS_HELPER removed ..."
    fi

    # Remove privilegschecker script
    if [ -f "$PRIVILEGES_CHECKER_SCRIPT" ]; then
        /bin/rm "$PRIVILEGES_CHECKER_SCRIPT"
        /usr/bin/logger "$PRIVILEGES_CHECKER_SCRIPT removed ..."
    fi
}

# Run main
main
