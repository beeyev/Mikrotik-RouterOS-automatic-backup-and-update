# Script name: BackupAndUpdate
#
#----------SCRIPT INFORMATION---------------------------------------------------
#
# Script:  Mikrotik RouterOS automatic backup & update
# Version: 24.06.04
# Created: 07/08/2018
# Updated: 04/06/2024
# Author:  Alexander Tebiev
# Website: https://github.com/beeyev
# You can contact me by e-mail at tebiev@mail.com
#
# IMPORTANT!
# Minimum supported RouterOS version is v6.43.7
#
#----------MODIFY THIS SECTION AS NEEDED----------------------------------------
## Notification e-mail
## (Make sure you have configured Email settings in Tools -> Email)
:local emailAddress "zzt.tzz@gmail.com"

## Script mode, possible values: backup, osupdate, osnotify.
# backup    -   Only backup will be performed. (default value, if none provided)
#
# osupdate  -   The script will install a new RouterOS version if it is available.
#               It will also create backups before and after update process (it does not matter what value `forceBackup` is set to)
#               Email will be sent only if a new RouterOS version is available.
#               Change parameter `forceBackup` if you need the script to create backups every time when it runs (even when no updates were found).
#
# osnotify  -   The script will send email notifications only (without backups) if a new RouterOS update is available.
#               Change parameter `forceBackup` if you need the script to create backups every time when it runs.
:local scriptMode "osnotify"

## Additional parameter if you set `scriptMode` to `osupdate` or `osnotify`
# Set `true` if you want the script to perform backup every time its fired, whatever script mode is set.
:local forceBackup false

## Backup encryption password, no encryption if no password.
:local backupPassword ""

## If true, passwords will be included in exported config.
:local sensitiveDataInConfig true

## Update channel. Possible values: stable, long-term, testing, development
:local updateChannel "stable"

## Installs only patch versions of RouterOS updates.
## Works only if you set scriptMode to "osupdate"
## Means that new update will be installed only if MAJOR and MINOR version numbers remained the same as currently installed RouterOS.
## Example: v6.43.6 => major.minor.PATCH
## Script will send information if new version is greater than just patch.
:local installOnlyPatchUpdates false

## If true, device public IP address information will be included into the email message
:local detectPublicIpAddress true

## Allow anonymous statistics collection. (script mode, device model, OS version)
:local allowAnonymousStatisticsCollection true

##------------------------------------------------------------------------------------------##
#  !!!! DO NOT CHANGE ANYTHING BELOW THIS LINE, IF YOU ARE NOT SURE WHAT YOU ARE DOING !!!!  #
##------------------------------------------------------------------------------------------##

:local scriptVersion "24.06.04"

#Script messages prefix
:local SMP "Bkp&Upd:"

:log info "\n$SMP script \"Mikrotik RouterOS automatic backup & update\" v.$scriptVersion started."
:log info "$SMP Script Mode: `$scriptMode`, forceBackup: `$forceBackup`"


############### vvvvvvvvv GLOBALS vvvvvvvvv ###############
# Global variable to track current update step
:global buGlobalVarUpdateStep
############### ^^^^^^^^^ GLOBALS ^^^^^^^^^ ###############

## STEP ONE: Creating backups, checking for new RouterOs version and sending email with backups,
## Steps 2 and 3 are fired only if script is set to automatically update device and if a new RouterOs version is available.
:if ($updateStep = 1) do={
    :log info ("$SMP Performing the first step.");

    # Checking for new RouterOS version
    if ($scriptMode = "osupdate" or $scriptMode = "osnotify") do={
    
    }

}

# Remove functions from global environment to keep it fresh and clean.
:do {/system script environment remove buGlobalFuncGetOsVerNum} on-error={}
:do {/system script environment remove buGlobalFuncCreateBackups} on-error={}