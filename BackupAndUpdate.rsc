# Script name: BackupAndUpdate
#
#----------SCRIPT INFORMATION---------------------------------------------------
#
# Script:  Mikrotik RouterOS automatic backup & update
# Version: 25.04.12
# Created: 07/08/2018
# Updated: 12/04/2025
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
:local emailAddress "yourmail@example.com";

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
:local forceBackup false

## Backup encryption password, no encryption if no password.
:local backupPassword ""

## If true, passwords will be included in exported config.
:local sensitiveDataInConfig true

## Update channel. Possible values: stable, long-term, testing, development
:local updateChannel "stable"

## Install only patch updates (requires scriptMode = "osupdate")
## Works only for `stable` and `long-term` channels.
## Update will run only if MAJOR and MINOR versions match the current one
## Example: current = v6.43.2 → v6.43.6 = allowed, v6.44.1 = skipped
## Script will send information if new version is greater than just patch.
:local installOnlyPatchUpdates false

## If true, device public IP address information will be included into the email message
:local detectPublicIpAddress true

## Allow anonymous statistics collection. (script mode and generic non-sensitive device info)
:local allowAnonymousStatisticsCollection true

##------------------------------------------------------------------------------------------##
#  !!!! DO NOT CHANGE ANYTHING BELOW THIS LINE, IF YOU ARE NOT SURE WHAT YOU ARE DOING !!!!  #
##------------------------------------------------------------------------------------------##

:local scriptVersion "25.04.12"

# default and fallback public IP detection services
:local ipAddressDetectServiceDefault "https://ipv4.mikrotik.ovh/"
:local ipAddressDetectServiceFallback "https://api.ipify.org/"

#Script messages prefix
:local SMP "Bkp&Upd:"

:local exitErrorMessage "$SMP script stopped due to an error. Please check logs for more details."
:log info "\n\n$SMP Script \"Mikrotik RouterOS automatic backup & update\" v.$scriptVersion started."
:log info "$SMP Script Mode: `$scriptMode`, Update channel: `$updateChannel`, Force backup: `$forceBackup`, Install only patch updates: `$installOnlyPatchUpdates`"

############### vvvvvvvvv FUNCTIONS vvvvvvvvv ###############

# Function: FuncGetRunningOsVersion
# ----------------------------
# Returns currently running RouterOS version
#
# Example:
# :put [$FuncGetRunningOsVersion]  # Output: 6.48.1
:local FuncGetRunningOsVersion do={
    :local runningOsAndChannel [/system resource get version]

    :local spacePos [:find $runningOsAndChannel " "]
    :if ([:len $spacePos] = 0) do={
        :log error "Bkp&Upd: Could not extract installed OS version string: `$runningOsAndChannel`. Script stopped."
        :error "Bkp&Upd: script stopped due to an error. Please check logs for more details."
    }

    :local versionOnly [:pick $runningOsAndChannel 0 $spacePos]

    :return $versionOnly
}

# Function: FuncGetRunningOsChannel
# ----------------------------
# Returns currently running RouterOS channel (stable, long-term, testing, development)
#
# Example:
# :put [$FuncGetRunningOsChannel]  # Output: stable
:local FuncGetRunningOsChannel do={
    :local runningOsAndChannel [/system resource get version]
    :local errorMessage "Bkp&Upd: Could not extract installed OS channel from version string: `$runningOsAndChannel`. Script stopped."
    :local exitErrorMessage "Bkp&Upd: script stopped due to an error. Please check logs for more details."

    :local open [:find $runningOsAndChannel "("]
    :if ([:len $open] = 0) do={
        :log error ($errorMessage . " (1)")
        :error $exitErrorMessage
    }

    :local rest [:pick $runningOsAndChannel ($open+1) [:len $runningOsAndChannel]]

    :local close [:find $rest ")"]
    :if ([:len $close] = 0) do={
        :log error ($errorMessage . " (2)")
        :error $exitErrorMessage
    }

    :local channel [:pick $rest 0 $close]
    :if ([:len $channel] = 0) do={
        :log error ($errorMessage . " (3)")
        :error $exitErrorMessage
    }

    :return $channel
}

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
# :put [$FuncCreateBackups "daily-backup"]
:local FuncCreateBackups do={
    :local backupName $1
    :local backupPassword $2
    :local sensitiveDataInConfig $3

    #Script messages prefix
    :local SMP "Bkp&Upd:"
    :local exitErrorMessage "$SMP script stopped due to an error. Please check logs for more details."
    :log info ("$SMP global function `FuncCreateBackups` started, input: `$backupName`")

    # validate required parameter: backupName
    :if ([:typeof $backupName] != "str" or [:len $backupName] = 0) do={
        :log error "$SMP parameter 'backupName' is required and must be a non-empty string"
        :error $exitErrorMessage
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
        :if ([:pick [/system resource get version] 0 1] < 7) do={
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

    :if ([:len [/file find name=$backupFileSys]] > 0) do={
        :log info ("$SMP system backup file successfully saved to the file system: `$backupFileSys`")
    } else={
        :log error ("$SMP system backup was not created, file does not exist: `$backupFileSys`")
        :error $exitErrorMessage
    }

    :if ([:len [/file find name=$backupFileConfig]] > 0) do={
        :log info ("$SMP config backup file successfully saved to the file system: `$backupFileConfig`")
    } else={
        :log error ("$SMP config backup was not created, file does not exist: `$backupFileConfig`")
        :error $exitErrorMessage
    }

    :log info ("$SMP global function `FuncCreateBackups` finished. Created backups, system: `$backupFileSys`, config: `$backupFileConfig`")

    :return $backupNames
}

# Function: FuncSendEmailSafe
# ---------------------------
# Sends an email and checks if it was sent successfully.
#
# Parameters:
#    $1 - to (email address)
#    $2 - subject
#    $3 - body
#    $4 - file attachments (optional; pass "" if not needed)
#
# Example:
# :do {
#     $FuncSendEmailSafe "admin@domain.com" "Backup Done" "Backup complete." "backup1.backup"
# } on-error={
#     :log error "Email failed to send"
# }
:local FuncSendEmailSafe do={

    :local emailTo $1
    :local emailSubject $2
    :local emailBody $3
    :local emailAttachments $4

    :local SMP "Bkp&Upd:"
    :local exitErrorMessage "$SMP script stopped due to an error. Please check logs for more details."

    :log info "$SMP Attempting to send email to `$emailTo`"

    # SAFETY: wait for any previously queued email to finish
    :local waitTimeoutPre 60
    :local waitCounterPre 0
    :while (([/tool e-mail get last-status] = "resolving-dns" or [/tool e-mail get last-status] = "in-progress")) do={
        :if ($waitCounterPre >= $waitTimeoutPre) do={
            :log error "$SMP Email send aborted: previous send did not complete after $waitTimeoutPre seconds"
            :error $exitErrorMessage
        }

        :log info "$SMP Waiting for previous email to finish (status: $[/tool e-mail get last-status])..."
        :delay 1s
        :set waitCounterPre ($waitCounterPre + 1)
    }

    # Send the email
    :do {
        /tool e-mail send to=$emailTo subject=$emailSubject body=$emailBody file=$emailAttachments
    } on-error={
        :log error "$SMP Email send command failed to execute. Check logs and verify email settings."
        :error $exitErrorMessage
    }

    # Wait for send status to change from "in-progress" / "resolving-dns"
    :local waitTimeout 60
    :local waitCounter 0
    :local emailStatus ""
    :log info "$SMP Waiting for email to be sent, timeout in `$waitTimeout` seconds..."
    :while ($waitCounter < $waitTimeout) do={
        :set emailStatus [/tool e-mail get last-status]
        :if ($emailStatus != "in-progress" and $emailStatus != "resolving-dns") do={
            :log info "$SMP Email send status received: $emailStatus"

            # exit loop
            :set waitCounter $waitTimeout
        } else={
            :delay 1s
            :set waitCounter ($waitCounter + 1)
        }
    }

    # Final decision based on last status
    :if ($emailStatus = "succeeded") do={
        :log info  "$SMP Email successfully sent to `$emailTo`"
    } else={
        :log error "$SMP Email failed to send. Status: `$emailStatus`. Check logs for more details and verify email settings."
        :error $exitErrorMessage
    }
}

# Global variable to track current update step
# They need to be initialized here first to be available in the script
:global buGlobalVarTargetOsVersion

:global buGlobalVarScriptStep
:local scriptStep $buGlobalVarScriptStep
:do {/system script environment remove buGlobalVarScriptStep} on-error={}
:if ([:len $scriptStep] = 0) do={
    :set scriptStep 1
}
############### ^^^^^^^^^ FUNCTIONS ^^^^^^^^^ ###############


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
:if ($scriptMode != "backup" and $scriptMode != "osupdate" and $scriptMode != "osnotify") do={
    :log error ("$SMP Script parameter `\$scriptMode` is not set, or contains invalid value: `$scriptMode`. Script stopped.")
    :error $exitErrorMessage
}

# Update channel validation
:if ($updateChannel != "stable" and $updateChannel != "long-term" and $updateChannel != "testing" and $updateChannel != "development") do={
    :log error ("$SMP Script parameter `\$updateChannel` is not set, or contains invalid value: `$updateChannel`. Script stopped.")
    :error $exitErrorMessage
}

# Check if the script is set to install only patch updates and if the update channel is valid
:if ($scriptMode = "osupdate" and $installOnlyPatchUpdates = true) do={
    :if ($updateChannel != "stable" and $updateChannel != "long-term") do={
        :log error ("$SMP Script is set to install only patch updates, but the update channel is not valid: `$updateChannel`. Only `stable` and `long-term` channels supported. Script stopped.")
        :error $exitErrorMessage
    }

    :local susRunningOsChannel [$FuncGetRunningOsChannel]

    :if ($susRunningOsChannel != "stable" and $susRunningOsChannel != "long-term") do={
        :log error ("$SMP Script is set to install only patch updates, but the installed RouterOS version is not from `stable` or `long-term` channel: `$susRunningOsChannel`. Script stopped.")
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

:local deviceBoardName [/system resource get board-name]

## Check if it's a cloud hosted router or a hardware based device
:local isCloudHostedRouter false;
:if ([:pick $deviceBoardName 0 3] = "CHR" or [:pick $deviceBoardName 0 3] = "x86") do={
    :set isCloudHostedRouter true;
};

:local deviceIdentityName       [/system identity get name];
:local deviceIdentityNameShort  [:pick $deviceIdentityName 0 18]

:local deviceRbModel            "CloudHostedRouter";
:local deviceRbSerialNumber     "--"
:local deviceRbCurrentFw        "--"
:local deviceRbUpgradeFw        "--"

:if ($isCloudHostedRouter = false) do={
    :set deviceRbModel          [/system routerboard get model]
    :set deviceRbSerialNumber   [/system routerboard get serial-number]
    :set deviceRbCurrentFw      [/system routerboard get current-firmware]
    :set deviceRbUpgradeFw      [/system routerboard get upgrade-firmware]
};

:local runningOsChannel [$FuncGetRunningOsChannel]
:local runningOsVersion [$FuncGetRunningOsVersion]
:local deviceOsVerAndChannelRunning [/system resource get version]

:local backupNameTemplate       "backup_v$runningOsVersion_$runningOsChannel_$currentDateTime"
:local backupNameBeforeUpdate   "backup_before_update_$backupNameTemplate"
:local backupNameAfterUpdate    "backup_after_update_$backupNameTemplate"

## Email body template

:local mailSubjectPrefix    "$SMP Device - `$deviceIdentityNameShort`"

:local mailBodyCopyright    "Mikrotik RouterOS automatic backup & update (ver. $scriptVersion) \nhttps://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update"
:local changelogUrl         "Check RouterOS changelog: https://mikrotik.com/download/changelogs/"

:local mailBodyDeviceInfo  ""
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "Device information:")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\n---------------------")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nName: $deviceIdentityName")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nModel: $deviceRbModel")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nBoard: $deviceBoardName")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nSerial number: $deviceRbSerialNumber")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nRouterOS version: v$deviceOsVerAndChannelRunning")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nBuild time: $[/system resource get build-time]")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nRouterboard FW: $deviceRbCurrentFw")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nDevice date-time: $rawDate $rawTime ($[/system clock get time-zone-name ])")
:set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nUptime: $[/system resource get uptime]")
# IP address will be appended later if needed

:local mailAttachments  [:toarray ""]

## IP address detection & anonymous statistics collection
:if ($scriptStep = 1 or $scriptStep = 3) do={
    :if ($scriptStep = 3) do={
        :log info ("$SMP Waiting for one minute before continuing to the final step.")
        :delay 1m
    }
    # default values, to be set later
    :local publicIpAddress "not-detected"
    :local telemetryDataQuery ""

    :if ($detectPublicIpAddress = true or $allowAnonymousStatisticsCollection = true) do={
        :if ($allowAnonymousStatisticsCollection = true) do={
            :set telemetryDataQuery ("\?mode=" . $scriptMode . "&scriptver=" . $scriptVersion . "&updatechannel=" . $updateChannel . "&osver=" . $runningOsVersion . "&step=" . $scriptStep . "&forcebackup=" . $forceBackup . "&onlypatchupdates=" . $installOnlyPatchUpdates . "&model=" . $deviceRbModel . "&deviceboard=" . $deviceBoardName)
        }

        :do {:set publicIpAddress ([/tool fetch http-method="get" url=($ipAddressDetectServiceDefault . $telemetryDataQuery) output=user as-value]->"data")} on-error={
            :if ($detectPublicIpAddress = true) do={
                :log warning "$SMP Could not detect public IP address using default detection service: `$ipAddressDetectServiceDefault`"
                :log warning "$SMP Trying to detect public IP using fallback detection service: `$ipAddressDetectServiceFallback`"
                :do {
                    :set publicIpAddress ([/tool fetch http-method="get" url=$ipAddressDetectServiceFallback output=user as-value]->"data")
                } on-error={
                    :log warning "$SMP Could not detect public IP address using fallback detection service: `$ipAddressDetectServiceFallback`"
                }
            }
        }

        :set publicIpAddress ([:pick $publicIpAddress 0 15])

        :if ($detectPublicIpAddress = true) do={
            # truncate IP to max 15 characters (basic safety)
            :set mailBodyDeviceInfo ($mailBodyDeviceInfo . "\nPublic IP address: $publicIpAddress")
            :log info "$SMP Public IP address detected: `$publicIpAddress`"
        }
    }
}

## STEP ONE: Creating backups, checking for new RouterOs version and sending email with backups,
## Steps 2 and 3 are fired only if script is set to automatically update device and if a new RouterOs version is available.
:if ($scriptStep = 1) do={
    :local routerOsVersionAvailable "0.0.0"
    :local isNewOsUpdateAvailable false
    :local isLatestOsAlreadyInstalled true
    :local isOsNeedsToBeUpdated false
    :local isUpdateCheckSucceeded false
    :local isEmailNeedsToBeSent false

    :local mailSubjectPartAction ""
    :local mailPtBodyAction ""

    :local mailPtSubjectBackup ""
    :local mailPtBodyBackup ""

    # Checking for new RouterOS version
    :if ($scriptMode = "osupdate" or $scriptMode = "osnotify") do={
        log info ("$SMP Setting update channel to `$updateChannel`")
        /system package update set channel=$updateChannel
        log info ("$SMP Checking for new RouterOS version. Current installed version is: `$runningOsVersion`")
        /system package update check-for-updates

        # Wait for 5 seconds to allow the system to check for updates
        :delay 5s;

        :local packageUpdateStatus "undefined"

        :set routerOsVersionAvailable [/system package update get latest-version]
        :set packageUpdateStatus [/system package update get status]

        :if ($packageUpdateStatus = "New version is available") do={
            :log info ("$SMP New RouterOS version is available: `$routerOsVersionAvailable`")
            :set isNewOsUpdateAvailable true
            :set isLatestOsAlreadyInstalled false
            :set isUpdateCheckSucceeded true
            :set isEmailNeedsToBeSent true

            :set mailSubjectPartAction "New RouterOS available"
            :set mailPtBodyAction    "New RouterOS version is available, current version: v$runningOsVersion, new version: v$routerOsVersionAvailable. \n$changelogUrl"
        } else={
            :if ($packageUpdateStatus = "System is already up to date") do={
                :log info ("$SMP No new RouterOS version is available, the latest version is already installed: `v$runningOsVersion`")
                :set isUpdateCheckSucceeded true

                :set mailSubjectPartAction "No os update available"
                :set mailPtBodyAction    "No new RouterOS version is available, the latest version is already installed: `v$runningOsVersion`"
            } else={
                :log error ("$SMP Failed to check for new RouterOS version. Package check status: `$packageUpdateStatus`")
                :set isEmailNeedsToBeSent true

                :set mailSubjectPartAction "Error unable to check new os version"
                :set mailPtBodyAction    "An error occurred while checking for a new RouterOS version.\nStatus returned: `$packageUpdateStatus`\n\nPlease review the logs on the device for more details and verify internet connectivity."
            }
        }
    }

    # Checking if the script needs to install new RouterOS version
    :if ($scriptMode = "osupdate" and $isNewOsUpdateAvailable = true) do={
        :if ($installOnlyPatchUpdates = true) do={
            :if ([$FuncIsPatchUpdateOnly $runningOsVersion $routerOsVersionAvailable] = true) do={
                :log info "$SMP New RouterOS version is available, and it is a patch update. Current version: v$runningOsVersion, new version: v$routerOsVersionAvailable"
                :set isOsNeedsToBeUpdated true
            } else={
                :log info "$SMP The script will not install this update, because it is not a patch update. Current version: v$runningOsVersion, new version: v$routerOsVersionAvailable"
                :set mailPtBodyAction ($mailPtBodyAction . "\nThis update will not be installed, because the script is set to install only patch updates.")
            }
        } else={
            :set isOsNeedsToBeUpdated true
        }
    }


    # Checking If the script needs to create a backup
    :if ($forceBackup = true or $scriptMode = "backup" or $isOsNeedsToBeUpdated = true) do={
        :log info ("$SMP Starting backup process.")

        :set isEmailNeedsToBeSent true

        :local backupName $backupNameTemplate

        # This means it's the first step where we create a backup before the update process
        :if ($isOsNeedsToBeUpdated = true) do={
            :set backupName $backupNameBeforeUpdate

            #Email body if the purpose of the script is to update the device
            :set mailSubjectPartAction "Update preparation"
            :set mailPtBodyAction ($mailPtBodyAction . "\nThe update process for device '$deviceIdentityName' is scheduled to upgrade RouterOS from version v.$runningOsVersion to version v.$routerOsVersionAvailable (Update channel: $updateChannel)")
            :set mailPtBodyAction ($mailPtBodyAction . "\nPlease note: The update will proceed only after a successful backup.")
            :set mailPtBodyAction ($mailPtBodyAction . "\nA final report with detailed information will be sent once the update process is completed.")
            :set mailPtBodyAction ($mailPtBodyAction . "\nIf you do not receive a second email within the next 10 minutes, there may be an issue. Please check your device logs for further information.")
        }

        :do {
            :set mailAttachments [$FuncCreateBackups $backupName $backupPassword $sensitiveDataInConfig];

            :set mailPtSubjectBackup "Backup created"
            :set mailPtBodyBackup "System backups have been successfully created and attached to this email."
        } on-error={
            #failed to create backup
            :set isOsNeedsToBeUpdated false

            :set mailPtSubjectBackup "Backup failed"
            :set mailPtBodyBackup "The script failed to create backups. Please check device logs for more details."

            :log warning "$SMP Failed to create backup files. Update process will be cancelled, if the script is set to update the device."
        }
    }

    :if ($isEmailNeedsToBeSent = true) do={
        :log info "$SMP Preparing to send email..."

        :local mailStep1Subject $mailSubjectPrefix
        :local mailStep1Body    ""

        # Assemble email subject
        :if ($mailSubjectPartAction != "")  do={:set mailStep1Subject ($mailStep1Subject . " - " . $mailSubjectPartAction)}
        :if ($mailPtSubjectBackup != "")    do={:set mailStep1Subject ($mailStep1Subject . " - " . $mailPtSubjectBackup)}
        # Assemble email body
        :if ($mailPtBodyAction != "") do={:set mailStep1Body ($mailStep1Body . $mailPtBodyAction . "\n\n")}
        :if ($mailPtBodyBackup != "") do={:set mailStep1Body ($mailStep1Body . $mailPtBodyBackup . "\n\n")}

        :set mailStep1Body ($mailStep1Body . $mailBodyDeviceInfo . "\n\n" . $mailBodyCopyright)

        # Send email with backup files attached
        :do {$FuncSendEmailSafe $emailAddress $mailStep1Subject $mailStep1Body $mailAttachments} on-error={
            :set isOsNeedsToBeUpdated false
            :log error "$SMP The script will not proceed with the update process, because the email was not sent."
            #:error $exitErrorMessage
        }
    }

    :if ([:len $mailAttachments] > 0) do={
        :log info "$SMP Cleaning up backup files from the file system..."
        /file remove $mailAttachments;
        :delay 2s;
    }

    :if ($isOsNeedsToBeUpdated = true) do={
        :log info "$SMP everything is ready to install new RouterOS, going to start the update process and reboot the device."
        :do {
            :local nextStep 2
            :if ($isCloudHostedRouter = true) do={
                :log info "$SMP The device is a cloud hosted router, the second step updating the Routerboard firmware will be skipped."
                :set nextStep 3
            }

            :local scheduledCommand (":delay 5s; /system scheduler remove BKPUPD-NEXT-BOOT-TASK; :global buGlobalVarScriptStep $nextStep; :global buGlobalVarTargetOsVersion \"$routerOsVersionAvailable\"; :delay 10s; /system script run BackupAndUpdate;")
            /system scheduler add name=BKPUPD-NEXT-BOOT-TASK on-event=$scheduledCommand start-time=startup interval=0

            /system package update install
        } on-error={
            # Failed to install new RouterOS version, remove the scheduled task
            :do {/system scheduler remove BKPUPD-NEXT-BOOT-TASK} on-error={}

            :log error "$SMP Failed to install new RouterOS version. Please check device logs for more details."

            :local mailUpdateErrorSubject ($mailSubjectPrefix . " - Update failed")
            :local mailUpdateErrorBody "The script was unable to install new RouterOS version. Please check device logs for more details."

            # Send email with error message
            $FuncSendEmailSafe $emailAddress $mailUpdateErrorSubject $mailUpdateErrorBody ""

            :error $exitErrorMessage
        }
    }
}

## STEP TWO: (after first reboot) routerboard firmware upgrade
## Steps 2 and 3 are fired only if script is set to automatically update device and if new RouterOs is available.
:if ($scriptStep = 2) do={
    :log info "$SMP The script is in the second step, updating Routerboard firmware."

    :log info "$SMP Upgrading routerboard firmware from v.$deviceRbCurrentFw to v.$deviceRbUpgradeFw"

    /system routerboard upgrade
    ## Wait until the upgrade is completed
    :delay 2s
    :log info "$SMP routerboard upgrade process was completed, going to reboot in a moment!";

    ## Set scheduled task to send final report on the next boot, task will be deleted when it is done. (That is why you should keep original script name)
    /system scheduler add name=BKPUPD-NEXT-BOOT-TASK on-event=":delay 5s; /system scheduler remove BKPUPD-NEXT-BOOT-TASK; :global buGlobalVarScriptStep 3; :global buGlobalVarTargetOsVersion \"$buGlobalVarTargetOsVersion\"; :delay 10s; /system script run BackupAndUpdate;" start-time=startup interval=0

    ## Reboot system to boot with new firmware
    /system reboot;
}

## STEP THREE: Last step (after second reboot) sending final report
## Steps 2 and 3 are fired only if script is set to automatically update device and if new RouterOs is available.
## This step is executed after some delay
:if ($scriptStep = 3) do={
    :log info ("$SMP The script is in the third step, sending final report.")

    :local targetOsVersion $buGlobalVarTargetOsVersion
    :do {/system script environment remove buGlobalVarTargetOsVersion} on-error={}
    :if ([:len $targetOsVersion] = 0) do={
        :log warning "$SMP Something is wrong, the script was unable to get the target updated OS version from the global variable."
    }

    :local mailStep3Subject $mailSubjectPrefix
    :local mailStep3Body    ""

    :if ($targetOsVersion = $runningOsVersion) do={
        :log info "$SMP The script has successfully verified that the new RouterOS version was installed, target version: `$targetOsVersion`, current version: `$runningOsVersion`"

        :set mailStep3Subject ($mailStep3Subject . " - Update completed - Backup created")
        :set mailStep3Body ($mailStep3Body . "RouterOS and routerboard upgrade process was completed")
        :set mailStep3Body ($mailStep3Body . "\nNew RouterOS version: v.$targetOsVersion, routerboard firmware: v.$deviceRbCurrentFw")
        :set mailStep3Body ($mailStep3Body . "\n$changelogUrl")
        :set mailStep3Body ($mailStep3Body . "\nBackups of the upgraded system are in the attachment of this email.")
        :set mailStep3Body ($mailStep3Body . "\n\n" . $mailBodyDeviceInfo . "\n\n" . $mailBodyCopyright)

        :set mailAttachments [$FuncCreateBackups $backupNameAfterUpdate $backupPassword $sensitiveDataInConfig];
    } else={
        :log error "$SMP The script was unable to verify that the new RouterOS version was installed, target version: `$targetOsVersion`, current version: `$runningOsVersion`"
        :set mailStep3Subject ($mailStep3Subject . " - Update failed")

        :set mailStep3Body ($mailStep3Body . "The script was unable to verify that the new RouterOS version was installed, target version: `$targetOsVersion`, current version: `$runningOsVersion`")
        :set mailStep3Body ($mailStep3Body . "\nPlease check device logs for more details.")
        :set mailStep3Body ($mailStep3Body . "\n\n" . $mailBodyDeviceInfo . "\n\n" . $mailBodyCopyright)
    }

    $FuncSendEmailSafe $emailAddress $mailStep3Subject $mailStep3Body $mailAttachments

    :if ([:len $mailAttachments] > 0) do={
        :log info "$SMP Cleaning up backup files from the file system..."
        /file remove $mailAttachments;
        :delay 2s;
    }

    :log info "$SMP Final report email sent successfully, and the script has finished."
}

:log info "$SMP the script has finished, script step: `$scriptStep` \n\n"
