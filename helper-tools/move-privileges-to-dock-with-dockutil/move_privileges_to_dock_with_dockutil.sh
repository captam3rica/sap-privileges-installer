#!/usr/bin/env sh

# GitHub: @captam3rica

#
#   move_privileges_app_with_dockutil.sh
#
#   A script using dockutil to move Privileges.app to the macOS dock so that
#   end-user can take advantage of Privileges capabilities immediately after install.
#
#   Dependencies
#
#       dockutil - https://github.com/captam3rica/dockutil. This version of dockutil is
#                  a fork from the original repo. Forked becasue the original was not
#                  python 3 ready when this script was created.
#


APP_NAME="Privileges.app"
SCRIPT_NAME=$(/usr/bin/basename "$0" | /usr/bin/awk -F "." '{print $1}')


main() {
    # Run the main logic

    # Get current logged-in user and user uid.
    # These are used to run the tool as the currently logged-in user.
    current_user="$(get_current_user)"
    current_user_uid="$(get_current_user_uid $current_user)"

    # Move the app
    /bin/echo "Attempting to move $APP_NAME to the Dock ..."
    move_app_to_dock "/Applications/$APP_NAME" "1"
}


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
        if [ -e "/Applications/Privileges.app" ]; then
            /bin/echo "Using dockutil to move Privileges.app to the user's Dock ..."
            /bin/launchctl asuser "$current_user_uid" \
                /usr/bin/sudo -u "$current_user" \
                /usr/local/bin/dockutil --add "$1" --position "$2"

        else
            /bin/echo "Privileges.app is not installed ..."
            /bin/echo "The current user's dock has not been modified ..."
            exit 1
        fi

    else
        /bin/echo "dockutil is not installed ..."
        /bin/echo "The current user's dock has not been modified ..."
        exit 1
    fi
}


# Run the main
main

exit 0
