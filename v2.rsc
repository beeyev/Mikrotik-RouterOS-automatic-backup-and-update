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

###########

# Get current system time and date
:local rawTime [/system clock get time]
:local rawDate [/system clock get date]

# Current time in specific format `hh-mm-ss`
:local currentTime ([:pick $rawTime 0 2] . "-" . [:pick $rawTime 3 5] . "-" . [:pick $rawTime 6 8])

# Current date `YYYY-MM-DD` or `YYYY-Mon-DD`, will be defined later in the script
:local currentDate "undefined";

# Check if the date is in the old format, it should not start with a number
:if ([:len [:tonum [:pick $rawDate 0 1]]] = 0) do={
    # Convert old format `nov/11/2023` → `2023-nov-11`
    :set currentDate ([:pick $rawDate 7 11] . "-" . [:pick $rawDate 0 3] . "-" . [:pick $rawDate 4 6])
} else={
    # Use new format as is `YYYY-MM-DD`
    :set currentDate $rawDate
}

# Combine date and time → `YYYY-MM-DD-hh-mm-ss` or `YYYY-Mon-11-hh-mm-ss`
:local currentDateTime ($currentDate . "-" . $currentTime)

:local isSoftBased false
:local boardName [/system resource get board-name]

# Check if board name contains "CHR" or starts with "x86"
:if ([:len [:find $boardName "CHR"]] > 0 or [:pick $boardName 0 3] = "x86") do={
    :set isSoftBased true
}


############### vvvvvvvvv GLOBALS vvvvvvvvv ###############
# Function converts standard mikrotik build versions to the number.
# Possible arguments: paramOsVer
# Example:
# :put [$buGlobalFuncGetOsVerNum paramOsVer="6.49.2"]
# :put [$buGlobalFuncGetOsVerNum paramOsVer=[/system routerboard get current-firmware]]
# Result will be: 64301, because current RouterOS version is: 6.43.1
:global buGlobalFuncGetOsVerNum do={
    :local osVer $paramOsVer
    :local allowedChars "0123456789."
    :local i 0
    :local c ""

    if ([:len $osVer] < 3 or [:len $osVer] > 10) do={
        :error ("Bkp&Upd: getOsVerNum: invalid version string length, given version: `$osVer`")
    }

    # validate that each character is a digit or a dot
	:for i from=0 to=([:len $osVer] - 1) do={
		:set c [:pick $osVer $i]
		:if ([:len [:find $allowedChars $c]] = 0) do={
			:error ("Bkp&Upd: invalid version string, invalid character: `$c`, given version: `$osVer`")
		}
	}

    :local major ""
    :local minor "00"
    :local patch "00"

    :if ([:find $osVer "."] >= 0) do={
        :set major [:pick $osVer 0 [:find $osVer "."]]
        :local rest [:pick $osVer ([:find $osVer "."] + 1) [:len $osVer]]

        :if ([:find $rest "."] >= 0) do={
            :set minor [:pick $rest 0 [:find $rest "."]]
            :set patch [:pick $rest ([:find $rest "."] + 1) [:len $rest]]
        } else={
            :set minor $rest
        }
    } else={:set major $osVer}

    :if ([:len $minor] = 1) do={:set minor ("0" . $minor)}

    :if ([:len $patch] = 1) do={:set patch ("0" . $patch)}

    :return ($major . $minor . $patch)
}
