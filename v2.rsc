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
:local emailAddress "zzt.tzz@gmail.com";

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
:local scriptMode "osupdate";

## Additional parameter if you set `scriptMode` to `osupdate` or `osnotify`
# Set `true` if you want the script to perform backup every time its fired, whatever script mode is set.
:local forceBackup false;

## Backup encryption password, no encryption if no password.
:local backupPassword "";

## If true, passwords will be included in exported config.
:local sensitiveDataInConfig true;

## Update channel. Possible values: stable, long-term, testing, development
:local updateChannel "stable";

## Installs only patch versions of RouterOS updates.
## Works only if you set scriptMode to "osupdate"
## Means that new update will be installed only if MAJOR and MINOR version numbers remained the same as currently installed RouterOS.
## Example: v6.43.6 => major.minor.PATCH
## Script will send information if new version is greater than just patch.
:local installOnlyPatchUpdates false;

## If true, device public IP address information will be included into the email message
:local detectPublicIpAddress true;

## Allow anonymous statistics collection. (script mode, device model, OS version)
:local allowAnonymousStatisticsCollection true;

##------------------------------------------------------------------------------------------##
#  !!!! DO NOT CHANGE ANYTHING BELOW THIS LINE, IF YOU ARE NOT SURE WHAT YOU ARE DOING !!!!  #
##------------------------------------------------------------------------------------------##

#Script messages prefix
:local SMP "Bkp&Upd:"

:log info "\n$SMP script \"Mikrotik RouterOS automatic backup & update\" started.";
:log info "$SMP Script Mode: $scriptMode, forceBackup: $forceBackup";

:local scriptVersion "24.06.04";

# Current time `hh-mm-ss`
:local currentTime ([:pick [/system clock get time] 0 2] . "-" . [:pick [/system clock get time] 3 5] . "-" . [:pick [/system clock get time] 6 8]);

# Current date `YYYY-MM-DD`, will be defined later in the script
:local currentDate "undefined";

# Checking if the date is in the old format with slashes and month name (e.g., `nov/11/2023`)
:if ([:len [:tonum [:pick [/system clock get date] 0 1]]] = 0) do={
    # Convert the old date format
    # Example: `nov/11/2023` to `2023-nov-11`
    :set currentDate ([:pick [/system clock get date] 7 11] . "-" . [:pick [/system clock get date] 0 3] . "-" . [:pick [/system clock get date] 4 6]);
} else={
    # getting current date in the new format (e.g., `2023-11-11`)
    :set currentDate [/system clock get date];
};

# current date and time in the format `YYYY-MM-DD-hh-mm-ss` or `YYYY-Mon-11-hh-mm-ss`
:local currentDateTime ($currentDate . "-" . $currentTime);