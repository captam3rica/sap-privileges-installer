# sap-privileges-installer

![](readme-images/privileges_installer_icon.png)

## Description 

Use this repo to assist in deploying the SAP Enterprise Privileges App to your Mac fleet.

The base installation of Privileges does not allow toggling admin rights for a specified duration and setting additional preferences like `RequireAuthentication` at the same time.

**Enter privilegeschecker.sh ...**

When preference like the `RequireAuthentication` option is set in the Privileges configuration profile the ability to automatically toggle the logged-in user back to a standard user is disabled. The currently logged-in user will remain an admin until they manually toggle themselves back to a standard user. This may not be desirable for some organizations.

Using this script an IT admin can set a default amount of time for the user to remain an admin and automatically toggle the user back to standard with preference keys enabled. The script does this by first checking the currently logged-in user's privilege level. Then, using the SAP `PrivilegesCLI`, demotes the user if they are an admin.

This script can be executed from an MDM on a set interval or deployed to the client with an accompanying LaunchAgent. A sample LaunchAgent can be found in this repo [here](https://github.com/captam3rica/sap-privileges-installer/blob/master/payload/Library/LaunchAgents/com.github.captam3rica.privileges.checker.plist).


### About Privileges.app

**Privileges.app** for macOS is designed to allow users to work as a standard user for day-to-day use, by providing a quick and easy way to get administrator rights when needed. When you do need admin rights, you can get them by clicking on the **Privileges** icon in your Dock.

More info about the Privileges.app can be found in the SAP **[macOS Enterprise Privileges](https://github.com/SAP/macOS-enterprise-privileges)** Repo


## Requirements

**Privileges** supports the following macOS versions:

* macOS 10.12.x
* macOS 10.13.x
* macOS 10.14.x
* macOS 10.15.x

## Installation

1. Create a deployment package. The Packages.app tool was used here, but any packaging method can be used.
2. Upload the package to your MDM.
3. Deploy the package to your Mac fleet.


## Support

This project is 'as-is' with no support. You are welcome to make changes to improve it but we are not available for questions or support of any kind.
