# sap-privileges-installer

![](readme-images/privileges_installer_icon.png)

## Description 

Use this repo to assist in deploying the SAP macOS Enterprise Privileges App.

**Privileges.app** for macOS is designed to allow users to work as a standard user for day-to-day use, by providing a quick and easy way to get administrator rights when needed. When you do need admin rights, you can get them by clicking on the **Privileges** icon in your Dock.

More info about the Privileges.app can be found in the SAP **[macOS Enterprise Privileges](https://github.com/SAP/macOS-enterprise-privileges)** Repo


## Requirements

**Privileges** supports the following macOS versions:

* macOS 10.12.x
* macOS 10.13.x
* macOS 10.14.x
* macOS 10.15.x


## Repo Contents

Item | Description
| --- | ---
| **[`example-profiles`]()** | Example preferences. Pulled form the SAP Privileges Repo.
| **[`payload`]()** | **Packages.app** payload configuration used in this project.
| **[`preferences`]()** | Preference payloads used in this project. (notifications.mobileconfig & Privileges.app preferences mobileconfig).
| **[`privileges-checker`]()** | Companion tool that can be used alongside **Privilegs.app**.
| **[`readme-images`]()** | Images used in this repo's README file.
| **[`scripts`]()** | Contains pre and post installer scripts related to this Packages project.

## Installation

1. Create a deployment package. The Packages.app tool was used here, but any packaging method can be used.
2. Upload the package to your MDM.
3. Scope and deploy the package to your Mac fleet.


## Support

This project is 'as-is' with no support, no changes being made.  You are welcome to make changes to improve it but we are not available for questions or support of any kind.
