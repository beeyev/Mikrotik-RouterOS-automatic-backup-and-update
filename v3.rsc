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
:local scriptMode "osupdate"

## Additional parameter if you set `scriptMode` to `osupdate` or `osnotify`
# Set `true` if you want the script to perform backup every time its fired, whatever script mode is set.
:local forceBackup true

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

:local exitErrorMessage "$SMP script stopped due to an error. Please check logs for more details."

:log info "\n$SMP Script \"Mikrotik RouterOS automatic backup & update\" v.$scriptVersion started."
# TODO Improve this line
#:log info "$SMP Script Mode: `$scriptMode`, forceBackup: `$forceBackup`"

#
# Initial validation
# 

## Check email settings
:if ([:len $emailAddress] < 3) do={
    :log error ("$SMP Script parameter `\$emailAddress` is not set, or contains invalid value. Script stopped.")
    :error $exitErrorMessage
}

# Values will be defined later in the script
:local emailServer ""
:local emailFromAddress [/tool e-mail get from]

:log info "$SMP Validating email settings..."
:do {
    :set emailServer [/tool e-mail get server]
} on-error={
    # This is a workaround for the RouterOS v7.12 and older versions
    :set emailServer [/tool e-mail get address]
}
:if ($emailServer = "0.0.0.0") do={
    :log error ("$SMP Email server address is not correct: `$emailServer`, please check `Tools -> Email`. Script stopped.");
    :error $exitErrorMessage
}
:if ([:len $emailFromAddress] < 3) do={
    :log error ("$SMP Email configuration FROM address is not correct: `$emailFromAddress`, please check `Tools -> Email`. Script stopped.");
    :error $exitErrorMessage
}

# Script mode validation
if ($scriptMode != "backup" and $scriptMode != "osupdate" and $scriptMode != "osnotify") do={
    :log error ("$SMP Script parameter `\$scriptMode` is not set, or contains invalid value: `$scriptMode`. Script stopped.")
    :error $exitErrorMessage
}

# Update channel validation
if ($updateChannel != "stable" and $updateChannel != "long-term" and $updateChannel != "testing" and $updateChannel != "development") do={
    :log error ("$SMP Script parameter `\$updateChannel` is not set, or contains invalid value: `$updateChannel`. Script stopped.")
    :error $exitErrorMessage
}

# Check if the script is set to install only patch updates and if the update channel is valid
if ($scriptMode = "osupdate" and $installOnlyPatchUpdates=true) do={
    if ($updateChannel != "stable" and $updateChannel != "long-term") do={
        :log error ("$SMP Script parameter `\$installOnlyPatchUpdates` is set to true, but the update channel is not valid: `$updateChannel`. Script stopped.")
        :error $exitErrorMessage
    }

    :local isValidVersionString do={
        :local version $1
        :local allowedChars "0123456789."
        :local i 0
        :local c ""

        # Check each character
        :for i from=0 to=([:len $version] - 1) do={
            :set c [:pick $version $i]
            :if ([:len [:find $allowedChars $c]] = 0) do={
                :return false
            }
        }

        :return true
    }

    :local susInstalledOs [/system package update get installed-version]

    :if ([$isValidVersionString $susInstalledOs] = true) do={
        :log error ("$SMP Current RouterOS is testing or development version: `$susInstalledOs`, patch updates supported only for stable and long-term versions. Script stopped.")
        :error $exitErrorMessage
    }
}

#
# Get current system date and time 
#
:local rawTime [/system clock get time]
:local rawDate [/system clock get date]

## Current time in specific format `hh-mm-ss`
:local currentTime ([:pick $rawTime 0 2] . "-" . [:pick $rawTime 3 5] . "-" . [:pick $rawTime 6 8])

## Current date `YYYY-MM-DD` or `YYYY-Mon-DD`, will be defined later in the script
:local currentDate "undefined"

## Check if the date is in the old format, it should not start with a number
:if ([:len [:tonum [:pick $rawDate 0 1]]] = 0) do={
    # Convert old format `nov/11/2023` → `2023-nov-11`
    :set currentDate ([:pick $rawDate 7 11] . "-" . [:pick $rawDate 0 3] . "-" . [:pick $rawDate 4 6])
} else={
    # Use new format as is `YYYY-MM-DD`
    :set currentDate $rawDate
}

## Combine date and time → `YYYY-MM-DD-hh-mm-ss` or `YYYY-Mon-DD-hh-mm-ss`
:local currentDateTime ($currentDate . "-" . $currentTime)


#####


## Check if it's a cloud hosted router or a hardware based device

:local deviceBoardName [/system resource get board-name]

:local isCloudHostedRouter false;
:if ([:pick $deviceBoardName 0 3] = "CHR" or [:pick $deviceBoardName 0 3] = "x86") do={
    :set isCloudHostedRouter true;
};


:local deviceCurrentUpdateChannel   [/system package update get channel]
:local deviceOsVerInstalled         [/system package update get installed-version]

:local mailAttachments  [:toarray ""];

:local backupNameTemplate       "v$deviceOsVerInstalled_$deviceCurrentUpdateChannel_$currentDateTime";
:local backupNameBeforeUpdate   "backup_before_update_$backupNameTemplate";
:local backupNameAfterUpdate    "backup_after_update_$backupNameTemplate";


## Email body template

:local mailBodyDeviceInfo  ""
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\n\nDevice information")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\n---------------------")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nName: $deviceIdentityName")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nModel: $deviceRbModel")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nSerial number: $deviceRbSerialNumber")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nRouterOS version: v$deviceOsVerInstalled ($deviceCurrentUpdateChannel)")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nBuild time: $[/system resource get build-time]")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nRouterboard FW: $deviceRbCurrentFw")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nDate time: $rawDate $rawTime")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nUptime: $[/system resource get uptime]")


############### vvvvvvvvv FUNCTIONS vvvvvvvvv ###############

# Function: FuncIsPatchUpdateOnly
# ----------------------------
# Determines if two RouterOS version strings differ only by the patch version.
#
# Parameters:
#    `version1`  | string | The first version string (e.g., "6.2.1").
#    `version2`  | string | The second version string (e.g., "6.2.4").
#
# Returns:
#    boolean | true if only the patch versions differ; false otherwise.
#
# Example:
# :put [$FuncIsPatchUpdateOnly "6.2.1" "6.2.4"]  # Output: true
# :put [$FuncIsPatchUpdateOnly "6.2.1" "6.3.1"]  # Output: false
:local FuncIsPatchUpdateOnly do={
    :local ver1 $1
    :local ver2 $2

    # Internal function to extract the major and minor components from a version string.
    :local extractMajorMinor do={
        :local ver $1
        :local dot1 [:find $ver "."]
        :if ($dot1 = -1) do={ :return $ver }

        :local major [:pick $ver 0 $dot1]
        :local rest [:pick $ver ($dot1 + 1) [:len $ver]]
        :local dot2 [:find $rest "."]
        :local minor $rest
        :if ($dot2 >= 0) do={ :set minor [:pick $rest 0 $dot2] }

        :return ($major . "." . $minor)
    }

    # Compare the major and minor components of both version strings.
    :if ([$extractMajorMinor $ver1] = [$extractMajorMinor $ver2]) do={
        :return true
    }
    :return false
}

# Function creates backups (system and config) and returns array of names of created files.
# Possible arguments:
#    `backupName`               | string    | backup file name, without extension!
#    `backupPassword`           | string    |
#    `sensitiveDataInConfig`    | boolean   |
# Example:
# :put [$FuncCreateBackups backupName="daily-backup"]
:local FuncCreateBackups do={
    #Script messages prefix
    :local SMP "Bkp&Upd:"
    :log info ("$SMP global function `FuncCreateBackups` started, input: `$backupName`")

    # validate required parameter: backupName
    :if ([:typeof $backupName] != "str" or [:len $backupName] = 0) do={
        :local errMesg "$SMP parameter 'backupName' is required and must be a non-empty string"
        :log error $errMesg
        :error $errMesg
    } 

    :local backupFileSys "$backupName.backup"
    :local backupFileConfig "$backupName.rsc"
    :local backupNames {$backupFileSys;$backupFileConfig}

    ## Perform system backup
    :if ([:len $backupPassword] = 0) do={
        :log info ("$SMP starting backup without password, backup name: `$backupName`")
        /system backup save dont-encrypt=yes name=$backupName
    } else={
        :log info ("$SMP starting backup with password, backup name: `$backupName`")
        /system backup save password=$backupPassword name=$backupName
    }

    :log info ("$SMP system backup created: `$backupFileSys`")

      ## Export config file
    :if ($sensitiveDataInConfig = true) do={
        :log info ("$SMP starting export config with sensitive data, backup name: `$backupName`")
        # Since RouterOS v7 it needs to be explicitly set that we want to export sensitive data
        :if ([:pick [/system package update get installed-version] 0 1] < 7) do={
            :execute "/export compact terse file=$backupName"
        } else={
            :execute "/export compact show-sensitive terse file=$backupName"
        }
    } else={
        :log info ("$SMP starting export config without sensitive data, backup name: `$backupName`")
        /export compact hide-sensitive terse file=$backupName
    }
    
    :log info ("$SMP Config export complete: `$backupFileConfig`")
    :log info ("$SMP Waiting a little to ensure backup files are written")

    :delay 20s

    :log info ("$SMP global function `FuncCreateBackups` finished. Created backups, system: `$backupFileSys`, config: `$backupFileConfig`")

    :return $backupNames
}

# Global variable to track current update step
:global buGlobalVarUpdateStep
############### ^^^^^^^^^ FUNCTIONS ^^^^^^^^^ ###############

:local updateStep $buGlobalVarUpdateStep
:do {/system script environment remove buGlobalVarUpdateStep} on-error={}
:if ([:len $updateStep] = 0) do={
    :set updateStep 1
}

## STEP ONE: Creating backups, checking for new RouterOs version and sending email with backups,
## Steps 2 and 3 are fired only if script is set to automatically update device and if a new RouterOs version is available.
:if ($updateStep = 1) do={
    :log info ("$SMP Performing the first step.")

    :local deviceOsVerAvailable "0.0.0"
    :local packageUpdateStatus "undefined"
    :local isNewOsUpdateAvailable false
    :local isLatestOsAlreadyInstalled true
    :local isOsNeedsToBeUpdated false

    # Checking for new RouterOS version
    if ($scriptMode = "osupdate" or $scriptMode = "osnotify") do={
            log info ("$SMP Setting update channel to `$updateChannel`")
            /system package update set channel=$updateChannel
            log info ("$SMP Checking for new RouterOS version. Current installed version is: `$deviceOsVerInstalled`")
            /system package update check-for-updates

            # Wait for 5 seconds to allow the system to check for updates
            :delay 5s;

            :set deviceOsVerAvailable [/system package update get latest-version]
            :set packageUpdateStatus [/system package update get status]

            if ($packageUpdateStatus = "New version is available") do={
                :log info ("$SMP New RouterOS version is available: `$deviceOsVerAvailable`")
                :set isNewOsUpdateAvailable true
                :set isLatestOsAlreadyInstalled false
            } else={
                if ($packageUpdateStatus = "System is already up to date") do={
                    :log info ("$SMP No new RouterOS version is available, this device is already up to date: `$deviceOsVerInstalled`")
                } else={
                    :log error ("$SMP Failed to check for new RouterOS version. Package check status: `$packageUpdateStatus`")
                }
            }
    }

    # TODO Check for minor version updates
    if ($scriptMode = "osupdate" and $isNewOsUpdateAvailable = true) do={
        :set isOsNeedsToBeUpdated true
    }


    # Checking If the script needs to create a backup
    if ($forceBackup = true or $scriptMode = "backup" or $isOsNeedsToBeUpdated = true) do={
        :log info ("$SMP Starting backup process.")

        :local backupName $backupNameTemplate

        # This means it's the first step where we create a backup before the update process
        if ($isOsNeedsToBeUpdated = true) do={
            :set backupName $backupNameBeforeUpdate
        }

        :set mailAttachments [$FuncCreateBackups backupName=$backupName backupPassword=$backupPassword sensitiveDataInConfig=$sensitiveDataInConfig];
    }
}

# Remove functions from global environment to keep it fresh and clean.
# :do {/system script environment remove FuncIsPatchUpdateOnly} on-error={}
# :do {/system script environment remove FuncCreateBackups} on-error={}