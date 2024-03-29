#!/usr/bin/env sh

#
#   Unistaller script for the SAP Privileges App.
#
#   Removes the SAP Privileges.app and all of its dependencies, scripts, LaunchAgents,
#   and LaunchDaemons
#
#   PRE-REQUISITES
#
#       - Make sure that the target computer(s) is removed from scope for any MDM
#         profiles or policies related to this app.
#
#   DEPENDENCIES
#
#       - dockutil - https://github.com/captam3rica/dockutil
#           - macadmins/python - https://github.com/macadmins/python
#
#   PROCESS
#
#       1. Check the current logged-in user's privileges and elevate if needed.
#       2. Stop and unload LaunchDaemons and LaunchAgents
#       3. Check to see if the app is running
#       4. Remove App, LaunchAgents, LaunchDaemons, helper tools, and scripts
#       5. Kill cfprefsd
#       6. Using dockutil, remove app from the current user's Dock
#

#######################################################################################
################################ VARIABLES ############################################
#######################################################################################

# Name of the app to remove
APP_NAME="Privileges.app"

# Root dirs for LaunchAgents and LaunchDaemons
LD_DIR="/Library/LaunchDaemons"
LA_DIR="/Library/LaunchAgents"

# Privileges LaunchDaemon and label
PRIVS_DAEMON_LABEL="$LD_DIR/corp.sap.privileges.helper"
PRIVS_DAEMON="$LD_DIR/corp.sap.privileges.helper.plist"

# Privileges LaunchAgent and label
PRIVS_LA_LABEL="$LA_DIR/corp.sap.privileges"
PRIVS_LA="$LA_DIR/corp.sap.privileges.plist"

# Privileges checker LaunchAgent and label
PRIVSCHECKER_LA_LABEL="$LA_DIR/com.github.captam3rica.privileges.checker"
PRIVS_CHECKER_LA="$LA_DIR/com.github.captam3rica.privileges.checker.plist"

# Helpers and scripts
PRIVS_HELPER="/Library/PrivilegedHelperTools/corp.sap.privileges.helper"
PRIVSCHECKER_SCRIPT="/Library/Scripts/mdmhelpers/privilegeschecker.sh"

# Script name
SCRIPT_NAME=$(/usr/bin/basename "$0" | /usr/bin/awk -F "." '{print $1}')

# Binaries
PRIVS_CLI="/Applications/Privileges.app/Contents/Resources/PrivilegesCLI"

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

add_admin_privileges() {
    # Remove current logged-in user's admin privileges using the SAP PrivilegesCLI
    cu_uid="$1"
    cu="$2"

    /bin/launchctl asuser "$cu_uid" /usr/bin/sudo -u "$cu" --login "$PRIVS_CLI" --add
}

unload_and_stop_agent_or_daemon() {
    # Stop and unload LaunchAgents and LaunchDaemons

    # input variables
    daemon="$1"
    label="$2"

    # Unload the LaunchDaemon
    if [ -f "$daemon" ]; then

        # Stop the LaunchDaemon
        /usr/bin/logger "Stopping $label ..."
        /bin/launchctl stop "$label"

        # Unload the daemon
        /usr/bin/logger "Unloading $daemon ..."
        /bin/launchctl unload "$daemon"

        # Capture the truthy or falsy of the previous command
        ret="$?"

        if [ "$ret" -ne 0 ]; then
            # Daemon failed to load
            /usr/bin/logger "Failed to unload $daemon ..."
            exit "$ret"
        fi

        /usr/bin/logger "$daemon unload completed"

    else
        /usr/bin/logger "$daemon not found ..."
    fi
}

kill_process() {
    # Kill a process by name

    /usr/bin/logger "Killing the $1 ..."
    /usr/bin/killall "$1"

    # Capture the truthy or falsy of the previous command
    ret="$?"

    if [ "$ret" -ne 0 ]; then
        # Daemon failed to load
        /usr/bin/logger "Failed kill the $1 process ..."
        exit "$ret"
    fi
}

#######################################################################################
#################### MAIN LOGIC - DO NOT MODIFY #######################################
#######################################################################################

/usr/bin/logger ""
/usr/bin/logger "Start uninstaller ..."
/usr/bin/logger ""
/usr/bin/logger "Running $SCRIPT_NAME"
/usr/bin/logger ""

# Grab the current user and current user uuid
current_user="$(get_current_user)"
current_user_uid="$(get_current_user_uid)"

#
#   CHECK CURRENT PRIVILEGES LEVEL FOR CURRENT LOGGED-IN USER
#

# Only run if the PrivilegesCLI is installed
if [ -f "$PRIVS_CLI" ]; then
    /usr/bin/logger "Checking the current logged-in user's privileges ..."

    # Return privilege status
    privilege_status="$(current_privileges $current_user)"
    /usr/bin/logger "The current logged-in user's privilege is $privilege_status"

    if [ "$privilege_status" = "admin" ]; then
        # Remove the user from the admin group
        /usr/bin/logger "$current_user is already an admin user ..."

    else
        /usr/bin/logger "Adding $current_user to the admin group ..."
        add_admin_privileges "$current_user_uid" "$current_user"

        privilege_status="$(current_privileges $current_user)"
        /usr/bin/logger "The current logged-in user's privilege is $privilege_status"
    fi

else
    /usr/bin/logger "The PrivilegesCLI tool is not installed ..."
    /usr/bin/logger "User's privileges have not been harmed ..."
fi

#
#   STOP AND UNLOAD AGENTS AND DAEMONS
#

unload_and_stop_agent_or_daemon "$PRIVS_DAEMON" "$PRIVS_DAEMON_LABEL"
unload_and_stop_agent_or_daemon "$PRIVS_LA" "$PRIVS_LA_LABEL"
unload_and_stop_agent_or_daemon "$PRIVS_CHECKER_LA" "$PRIVSCHECKER_LA_LABEL"

#
#   CHECK TO SEE IF THE APP IS RUNNING
#

# Get the app process if it is running
APP_PROC=$(/usr/bin/pgrep "Privileges")

if [ "$APP_PROC" != "" ]; then
    /usr/bin/logger "The $APP_NAME process is running with id $APP_PROC ..."
    /usr/bin/logger "Killing the process ..."
    /usr/bin/killall "$APP_PROC"

    if [ "$?" -ne 0 ]; then
        # Daemon failed to load
        /usr/bin/logger "Failed kill the $APP_NAME process ..."
        exit "$RET"
    fi

else
    /usr/bin/logger "The $APP_NAME process is not running ..."
fi

#
#   REMOVE APP, AGENTS, DAEMONS, SCRIPTS, AND SUPPORTING FILES
#

## build a list containing the files to be removed.
REM_LIST="
    /Applications/$APP_NAME
    $PRIVS_DAEMON
    $PRIVS_LA
    $PRIVS_CHECKER_LA
    $PRIVS_HELPER
    $PRIVSCHECKER_SCRIPT"

# Loop over all files in the list until they are all processed.
for file in $REM_LIST; do

    if [ -e "$file" ]; then
        #statements
        /usr/bin/logger "Removing $file ..."
        /bin/rm -Rf "$file"

    else
        /usr/bin/logger "$file does not exist ..."
    fi

done

#
#   KILL CFPREFSD
#

kill_process "cfprefsd"

#
#   RMOVE APP FROM DOCK with DOCKUTIL
#

# Make sure that dockutil is installed on the system before calling it.
if [ -e "/usr/local/bin/dockutil" ]; then
    /usr/bin/logger "Removing $APP_NAME from the current user's Dock ..."
    /usr/local/bin/dockutil --remove 'Privileges'
else
    /usr/bin/logger "The dockutil binary is not installed on this system 🙁"
fi

/usr/bin/logger ""
/usr/bin/logger "End uninstaller ..."
/usr/bin/logger ""
