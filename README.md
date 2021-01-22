# sap-privileges-installer

![](readme-images/privileges_installer_icon.png)

## Description 

Use this repo to assist in deploying the SAP Enterprise Privileges App to your Mac fleet.

The base installation of Privileges does not allow reverting admin rights for a specified duration and setting the `RequireAuthentication` preference or any of the other keys removed the toggle ability all together.

**Enter privilegeschecker.sh ...**

When a preference key option is set in the Privileges configuration profile the toggle ability is disabled. The currently logged-in user will remain an admin until they manually toggle themselves back to a standard user. This may not be desirable for some organizations.

Using this script an IT admin can set a default amount of time for the user to remain an admin and automatically toggle the user back to standard with or without a preference key enabled. The script does this by first checking the currently logged-in user's privilege level. Then, using the SAP `PrivilegesCLI`, de-elevates the user if they are an admin .

This script can be executed from an MDM like Jamf on a set interval or deployed to the Mac endpoint with an accompanying LaunchAgent. A sample LaunchAgent can be found in this repo [here](https://github.com/captam3rica/sap-privileges-installer/blob/master/payload/Library/LaunchAgents/com.github.captam3rica.privileges.checker.plist).


### About Privileges.app

**Privileges.app** for macOS is designed to allow users to work as a standard user for day-to-day use, by providing a quick and easy way to get administrator rights when needed. When you do need admin rights, you can get them by clicking on the **Privileges** icon in your Dock.

More info about the Privileges.app can be found in the SAP **[macOS Enterprise Privileges](https://github.com/SAP/macOS-enterprise-privileges)** Repo


## Requirements

**Privileges** supports the following macOS versions:

* macOS 10.12.x
* macOS 10.13.x
* macOS 10.14.x
* macOS 10.15.x
* macOS 11.0 - 11.2 Beta


## Repo Contents

Item | Description
| --- | ---
| **[`payload`](https://github.com/captam3rica/sap-privileges-installer/tree/master/payload)** | **Packages.app** payload configuration used in this project.
| **[`preferences`](https://github.com/captam3rica/sap-privileges-installer/tree/master/preferences)** | Preference payloads used in this project. (notifications.mobileconfig & Privileges.app preferences mobileconfig).
| **[`privileges-checker`](https://github.com/captam3rica/sap-privileges-installer/tree/master/helper-tools/privileges-checker)** | Companion tool that can be used alongside **Privilegs.app**.
| **[`priviletes-checker launchagent`](https://github.com/captam3rica/sap-privileges-installer/blob/master/payload/Library/LaunchAgents/com.github.captam3rica.privileges.checker.plist)** | Example launchAgent used to set a user's privilege back to standard at a specific interval. |
| **[`moving privileges to the dock`](https://github.com/captam3rica/sap-privileges-installer/tree/master/helper-tools/move-privileges-to-dock-with-dockutil)** | Example script that can be used to move Privileges.app to the Dock. |
| **[`scripts`](https://github.com/captam3rica/sap-privileges-installer/tree/master/scripts)** | Contains pre and post installer scripts related to this Packages project.

## Installation

1. Create a deployment package. The Packages.app tool was used here, but any packaging method can be used.
2. Upload the package to your MDM.
3. Scope and deploy the package to your Mac fleet.


## Support

This project is 'as-is' with no support. You are welcome to make changes to improve it but we are not available for questions or support of any kind.
