#!/usr/bin/env sh

# GitHub: @captam3rica

#
#   privilegeschecker.sh
#
#   A script to check the privilege status of the current logged-in user.
#
#   This script is designed to be used as an add-on for the SAP Privileges App. When
#   the RequireAuthentication option is set in the Privileges configuration profile the
#   ability to automatically toggle the logged-in user back to a standard user is
#   disabled. The currently logged-in user will remain an admin until they manually
#   toggle themselves back to a standard user.
#
#   Enter this script ...
#
#   Using this script an IT admin can automatically toggle the currently logged-in user
#   back to standard with the RequireAuthentication key enabled. The script does this
#   by first checking the currently logged-in user's privilege level. Then, using the
#   SAP PrivilegesCLI, de-elevates the user if they are an admin .
#
#   This script can be executed from an MDM on a set interval or deployed to the client
#   with an accompanying LaunchAgent. A sample LaunchAgent can be found in this repo
#


#######################################################################################
################################ VARIABLES ############################################
#######################################################################################


VERSION=0.3.0

# Number of seconds to wait before removing admin rights from the current user.
SECONDS_TO_WAIT=900

SCRIPT_NAME=$(/usr/bin/basename "$0" | /usr/bin/awk -F "." '{print $1}')

# Binaries
DSCL="/usr/bin/dscl"
PRIVILEGES_CLI="/Applications/Privileges.app/Contents/Resources/PrivilegesCLI"


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


remove_admin_privileges() {
    # Remove current logged-in user's admin privileges using the SAP PrivilegesCLI
    cu_uid="$1"
    cu="$2"

    /bin/launchctl asuser "$cu_uid" /usr/bin/sudo -u "$cu" --login "$PRIVILEGES_CLI" --remove
}


#######################################################################################
#################### MAIN LOGIC - DO NOT MODIFY #######################################
#######################################################################################


main() {
    # Run the main logic

    # Get current logged-in user and user uid.
    current_user="$(get_current_user)"
    current_user_uid="$(get_current_user_uid $current_user)"


    /bin/echo "--- Start $SCRIPT_NAME log ---"
    /bin/echo ""
    /bin/echo "Version: $VERSION"

    /bin/echo "Current Logged-in User: $current_user($current_user_uid)"

    # Only run if the PrivilegesCLI is installed
    if [ -f "$PRIVILEGES_CLI" ]; then
        /bin/echo "Checking the current logged-in user's privileges ..."

        # Return privilege status
        privilege_status="$(current_privileges $current_user)"
        /bin/echo"The current logged-in user's privilege is $privilege_status"

        if [ "$privilege_status" = "admin" ]; then
            # Remove the user from the admin group
            /bin/echo "Removing $current_user from the admin group ..."
            remove_admin_privileges "$current_user_uid" "$current_user"

            privilege_status="$(current_privileges $current_user)"
            /bin/echo "The current logged-in user's privilege is $privilege_status"

        else
            /bin/echo "$current_user is already a standard user ..."
        fi

    else
        /bin/echo "The PrivilegesCLI tool is not installed ..."
        /bin/echo "User's privileges have not been harmed ..."
    fi

    printf "%s\n" "Logs can be found at /Users/$current_user/Library/Logs/$SCRIPT_NAME.log"

    /bin/echo ""
    /bin/echo "--- End $SCRIPT_NAME log ---"
    /bin/echo ""
}

# Run the main
main
