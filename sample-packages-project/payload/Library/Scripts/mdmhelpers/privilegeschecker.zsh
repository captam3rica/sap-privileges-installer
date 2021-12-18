#!/usr/bin/env zsh

# GitHub: @captam3rica

#
#   privilegeschecker.sh
#
#   A script to check the privilege status of the current logged-in user.
#
#   This script is designed to be used as an add-on for the SAP Privileges App. When
#   the RequireAuthentication option or any other preference key is used the Privileges
#   configuration profile the ability to automatically toggle the logged-in user back to a
#   standard user is disabled. The currently logged-in user will remain an admin until they
#   manually toggle themselves back to a standard user.
#
#   Enter this script ...
#
#   Using this script an IT admin can automatically toggle the currently logged-in user
#   back to standard no matter which preference keys are enabled. The script does this
#   by first checking the currently logged-in user's privilege level. Then, using the
#   SAP PrivilegesCLI, de-elevates the user if they are an admin.
#
#   Basic steps
#
#       1. Launch agent runs in the background running the privilegeschecker.sh script
#          every 30 seconds.
#       2. The privilegeschecker script checks to see if the current user is an admin.
#       3. If not nothing else happens and the script exits.
#       4. If yes then the script waits for a defined amount of time before removing
#          the admin rights.
#
#   CHANGELOG
#
#       - (1.0.1)
#           - Modified the remove_privs_function so that it can both remove or add admin privileges
#           - Updated the function name to modify_user_privileges
#       - (1.0.2)
#           - Bug fix where current user uid was unabled to be determined in some edge cases.
#           - Some additional code refactoring
#       - (1.0.3)
#           - Changed time to wait to minutes

# verbose output for script
set -x

VERSION=1.0.3

###################################################################################################
################################ VARIABLES ########################################################
###################################################################################################

# Number of minutes to wait before removing admin rights from the current user.
MINUTES_TO_WAIT=20

###################################################################################################
####################### FUNCTIONS - DO NOT MODIFY #################################################
###################################################################################################

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
    # $1: current logged in user

    # Returns true if the current logged in user is a member of the local admins group.
    group_membership=$(/usr/bin/dscl . read /groups/admin | /usr/bin/grep "$1")

    if [ "$?" -eq 0 ]; then
        # User is in the admin group
        permissions="admin"
    else
        # User is not in the admin group
        permissions="standard"
    fi

    printf "%s\n" "$permissions"
}

###################################################################################################
#################### MAIN LOGIC - DO NOT MODIFY ###################################################
###################################################################################################

main() {
    # Run the main logic

    # Binaries
    privileges_cli="/Applications/Privileges.app/Contents/Resources/PrivilegesCLI"

    # Get the current logged-in user and user UID
    current_user="$(get_current_user)"
    current_user_uid="$(get_current_user_uid)"

    /usr/bin/logger "--- Start privilegeschecker log ---"
    /usr/bin/logger ""
    /usr/bin/logger "Version: $VERSION"

    /usr/bin/logger "Current Logged-in User: $current_user($current_user_uid)"

    # Only run if the PrivilegesCLI is installed
    if [ -f "$privileges_cli" ]; then
        /usr/bin/logger "Checking the current logged-in user's privileges ..."

        # Return privilege status
        privilege_status="$(current_privileges $current_user)"
        /usr/bin/logger "The current logged-in user's privilege is $privilege_status"

        if [ "$privilege_status" = "admin" ]; then
            # What for the amount of time defined by the MINUTES_TO_WAIT * 60 variable
            /usr/bin/logger "Sleeping for $MINUTES_TO_WAIT minutess before removing privileges ..."
            /bin/sleep $(($MINUTES_TO_WAIT * 60))

            # Remove the user from the admin group
            /usr/bin/logger "Removing $current_user from the admin group ..."

            # Remove the current loggedin user's privileges
            /bin/launchctl asuser "$current_user_uid" /usr/bin/sudo -u "$current_user" --login "$privileges_cli" --remove

            privilege_status="$(current_privileges $current_user)"
            /usr/bin/logger "The current logged-in user's privilege is $privilege_status"

        else
            /usr/bin/logger "$current_user is already a standard user ..."
        fi

    else
        /usr/bin/logger "The PrivilegesCLI tool is not installed ..."
        /usr/bin/logger "User's privileges have not been harmed ..."
    fi

    /usr/bin/logger ""
    /usr/bin/logger "--- End privilegeschecker log ---"
    /usr/bin/logger ""
}

# Run the main
main
