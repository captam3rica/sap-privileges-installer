#!/usr/bin/env sh

# GitHub: @captam3rica

#
#   An example script to show how to use dockutil
#

APP="Privileges.app"
POSITION="1"

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

main() {
    # Do the main logic

    current_user="$(get_current_user)"
    current_user_uid="$(get_current_user_uid)"

    /usr/bin/logger "Current User: $current_user"

    if [ -e "/usr/local/bin/dockutil" ]; then

        # See if the Privileges app is installed in /Applications
        if [ -e "/Applications/$APP" ]; then
            /usr/bin/logger "Using dockutil to move Privileges.app to the user's Dock ..."
            /bin/launchctl asuser "$current_user_uid" \
                /usr/bin/sudo -u "$current_user" \
                /usr/local/bin/dockutil --add "/Applications/$APP" --position "$POSITION" --allhomes

        else
            /usr/bin/logger "$APP is not installed ..."
            /usr/bin/logger "The current user's dock has not been modified ..."
            exit 1
        fi

    else
        /usr/bin/logger "dockutil is not installed ..."
        /usr/bin/logger "The current user's dock has not been modified ..."
        exit 1
    fi
}

# Call main
main

exit 0
