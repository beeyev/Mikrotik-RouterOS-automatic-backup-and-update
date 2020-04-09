# Script name: BackupAndUpdate
#
#----------SCRIPT INFORMATION---------------------------------------------------
#
# Script:  Mikrotik RouterOS automatic backup & update
# Version: 20.01.20
# Created: 07/08/2018
# Updated: 20/01/2020
# Author:  Alexander Tebiev
# Website: https://github.com/beeyev
# You can contact me by e-mail at tebiev@mail.com
#
# IMPORTANT!
# Minimum supported RouterOS version is v6.43.7
#
#----------MODIFY THIS SECTION AS NEEDED----------------------------------------
## Notification e-mail
## (Make sure you have configurated Email settings in Tools -> Email)
:local emailAddress "yourmail@example.com";

## Script mode, possible values: backup, osupdate, osnotify.
# backup 	- only backup will be perfomed. (default value, if none provided)
# osupdate 	- script will make a backup and install new RouterOS if it is available.
# osnotify 	- script will make a backup and notify about new RouterOS version.
:local scriptMode "osnotify";

## Backup encryption password, no encryption if no password.
:local backupPassword ""

## If true, passwords will be included in exported config.
:local sensetiveDataInConfig false;

## Update channel. Possible values: stable, long-term, testing, development
:local updateChannel "stable";

## Install only patch versions of RouterOS updates.
## Works only if you set scriptMode to "osupdate"
## Means that new update will be installed only if MAJOR and MINOR version numbers remained the same as currently installed RouterOS.
## Example: v6.43.6 => major.minor.PATCH
## Script will send information if new version is greater than just patch.
:local installOnlyPatchUpdates	false;
##------------------------------------------------------------------------------------------##
#  !!!! DO NOT CHANGE ANYTHING BELOW THIS LINE, IF YOU ARE NOT SURE WHAT YOU ARE DOING !!!!  #
##------------------------------------------------------------------------------------------##

:log info "\r\nBkp&Upd: script \"Mikrotik RouterOS automatic backup & update\" started.";

#Check proper email config
:if ([:len $emailAddress] = 0 or [:len [/tool e-mail get address]] = 0 or [:len [/tool e-mail get from]] = 0) do={
	:log error ("Bkp&Upd: Email configuration is not correct, please check Tools -> Email. Script stopped.");   
	:error "Bkp&Upd: bye!";
}

############### vvvvvvvvv GLOBALS vvvvvvvvv ###############
# Function converts standard mikrotik build versions to the number.
# Possible arguments: osVer
# Example:
# :put [$brGlobalFuncGetOsVerNum osVer=[/system routerboard get current-RouterOS]];
# result will be: 64301, because current RouterOS version is: 6.43.1
:global brGlobalFuncGetOsVerNum do={
	:local osVerNum;
	:local osVerMicroPart;
	:local zro 0;
	:local tmp;
	
	:local dotPos1 [:find $osVer "." 0];

	:if ($dotPos1 > 0) do={ 

		# AA
		:set osVerNum  [:pick $osVer 0 $dotPos1];
		
		:local dotPos2 [:find $osVer "." $dotPos1];
				#Taking minor version, everything after first dot
		:if ([:len $dotPos2] = 0) 	do={:set tmp [:pick $osVer ($dotPos1+1) [:len $osVer]];}
		#Taking minor version, everything between first and second dots
		:if ($dotPos2 > 0) 			do={:set tmp [:pick $osVer ($dotPos1+1) $dotPos2];}
		
		# AA 0B
		:if ([:len $tmp] = 1) 	do={:set osVerNum "$osVerNum$zro$tmp";}
		# AA BB
		:if ([:len $tmp] = 2) 	do={:set osVerNum "$osVerNum$tmp";}
		
		:if ($dotPos2 > 0) do={ 
			:set tmp [:pick $osVer ($dotPos2+1) [:len $osVer]];
			# AA BB 0C
			:if ([:len $tmp] = 1) do={:set osVerNum "$osVerNum$zro$tmp";}
			# AA BB CC
			:if ([:len $tmp] = 2) do={:set osVerNum "$osVerNum$tmp";}
		} else={
			# AA BB 00
			:set osVerNum "$osVerNum$zro$zro";
		}
	} else={
		# AA 00 00
		:set osVerNum "$osVer$zro$zro$zro$zro";
	}

	:return $osVerNum;
}

:global brGlobalVarUpdateStep;
############### ^^^^^^^^^ GLOBALS ^^^^^^^^^ ###############

#Current date time in format: 2020jan15-221324 
:local dateTime ([:pick [/system clock get date] 7 11] . [:pick [/system clock get date] 0 3] . [:pick [/system clock get date] 4 6] . "-" . [:pick [/system clock get time] 0 2] . [:pick [/system clock get time] 3 5] . [:pick [/system clock get time] 6 8]);

:local deviceOsVerInst 		[/system package update get installed-version];
:local deviceOsVerInstNum 	[$brGlobalFuncGetOsVerNum osVer=$deviceOsVerInst];
:local deviceOsVerAvail 	"";
:local deviceOsVerAvailNum 	0;
:local deviceRbModel		[/system routerboard get model];
:local deviceRbSerialNumber [/system routerboard get serial-number];
:local deviceRbCurrentFw 	[/system routerboard get current-firmware];
:local deviceRbUpgradeFw 	[/system routerboard get upgrade-firmware];
:local deviceIdentityName 	[/system identity get name];
:local deviceUpdateChannel 	[/system package update get channel];

:local isOsUpdateAvailable 	false;
:local isOsNeedsToBeUpdated	false;

:local mailSubject   		"";
:local mailBody 	 		"";

:local mailBodyDeviceInfo	"\r\n\r\nDevice information: \r\nIdentity: $deviceIdentityName \r\nModel: $deviceRbModel \r\nSerial number: $deviceRbSerialNumber \r\nCurrent RouterOS: $deviceOsVerInst ($[/system package update get channel]) $[/system resource get build-time] \r\nCurrent routerboard FW: $deviceRbCurrentFw \r\nDevice uptime: $[/system resource get uptime]";
:local mailBodyCopyright 	"\r\n\r\nMikrotik RouterOS automatic backup & update \r\nhttps://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update";
:local changelogUrl			("Check RouterOS changelog: https://mikrotik.com/download/changelogs/" . $updateChannel . "-release-tree");

:local mailAttachments		[:toarray ""];

:local updateStep $brGlobalVarUpdateStep;
:do {/system script environment remove brGlobalVarUpdateStep;} on-error={}
:if ([:len $updateStep] = 0) do={
	:set updateStep 1;
}


## 	STEP ONE: Creating backups, checking for new RouterOs version and sending email with backups,
## 	steps 2 and 3 are fired only if script is set to automatically update device and if new RouterOs is available.
:if ($updateStep = 1) do={
	:log info ("Bkp&Upd: Performing the first step.");   

	# Set email subject and body for the first step
	:set mailSubject	"Bkp&Upd: Backup completed - $[:pick $deviceIdentityName 0 18].";
	:set mailBody 	  	"\"$deviceIdentityName\" system backups were created and attached to this email.";
	
	## PREPARE BACKUP DATA
	:log info ("Bkp&Upd: Creating system backups.");   

	:local bname "$deviceIdentityName.$deviceBoardModel.$deviceSerialNumber.v$deviceOsVerInst.$deviceUpdateChannel.$dateTime";
	:local backupFileSys "$bname.backup";
	:local backupFileConfig "$bname.rsc";

	:set mailAttachments {$backupFileSys;$backupFileConfig};

	## Make system backup
	:if ([:len $backupPassword] = 0) do={
		/system backup save dont-encrypt=yes name=$bname;
	} else={
		/system backup save password=$backupPassword name=$bname;
	}
	:log info ("Bkp&Upd: System backup created. $backupFileSys");   

	## Export config file
	:if ($sensetiveDataInConfig = true) do={
		/export compact file=$bname;
	} else={
		/export compact hide-sensitive file=$bname;
	}
	:log info ("Bkp&Upd: Config file was exported. $backupFileConfig");   

	# Checking for new RouterOS version
	if ($scriptMode = "osupdate" or $scriptMode = "osnotify") do={
		log info ("Bkp&Upd: Checking for new RouterOS version. Current version is: $deviceOsVerInst");
		/system package update set channel=$updateChannel;
		/system package update check-for-updates;
		:delay 5s;
		:set deviceOsVerAvail [/system package update get latest-version];

		# If there is a problem getting information about available RouterOS from server
		:if ([:len $deviceOsVerAvail] = 0) do={
			:log warning ("Bkp&Upd: There is a problem getting information about new RouterOS from server.");
			:set mailSubject	($mailSubject . " Error: No data about new RouterOS!")
			:set mailBody 		($mailBody . "\r\n\r\nError occured! \r\nMikrotik couldn't get any information about new RouterOS from server! \r\nWatch additional information in device logs.")
		} else={
			#Get numeric version of OS
			:set deviceOsVerAvailNum [$brGlobalFuncGetOsVerNum osVer=$deviceOsVerAvail];

			# Checking if OS on server is greater than installed one.
			:if ($deviceOsVerAvailNum > $deviceOsVerInstNum) do={
				:set isOsUpdateAvailable true;
				:log info ("Bkp&Upd: New RouterOS is available! $deviceOsVerAvail");
			} else={
				:set mailSubject ($mailSubject . " No new OS updates.")
				:set mailBody 	 ($mailBody . "\r\nYour system is up to date.")
				:log info ("Bkp&Upd: System is already up to date.")
			}
		};
	} else={
		#Delay after creating backups
		:delay 5s;	
	};


	# if new OS version is available to install
	if ($isOsUpdateAvailable = true) do={
		# If we only need to notify about new available version
		if ($scriptMode = "osnotify") do={
			:set mailSubject 	($mailSubject . " New RouterOS is available! v.$deviceOsVerAvail")
			:set mailBody 		($mailBody . "\r\n\r\nNew RouterOS version is available to install: v.$deviceOsVerAvail ($updateChannel) \r\n$changelogUrl")
		}

		# if we need to initiate RouterOs update process
		if ($scriptMode = "osupdate") do={
			:set isOsNeedsToBeUpdated true;
			# if we need to install only patch updates
			:if ($installOnlyPatchUpdates = true) do={
				#Check if Major and Minor builds are the same.
				:if ([:pick $deviceOsVerInstNum 0 ([:len $deviceOsVerInstNum]-2)] = [:pick $deviceOsVerAvailNum 0 ([:len $deviceOsVerAvailNum]-2)]) do={
					:log info ("Bkp&Upd: New patch version of RouterOS firmware is available.");   
				} else={
					:log info ("Bkp&Upd: New minor version of RouterOS firmware is available. You need to update it manually.");
					:set mailSubject 	($mailSubject . " New major RouterOS is available: v.$deviceOsVerAvail!");
					:set mailBody 		($mailBody . "\r\n\r\nNew major RouterOS version is available to install: v.$deviceOsVerAvail ($updateChannel). \r\nYou chose to automatically install only patch updates, so this major update you need to install manually. \r\n$changelogUrl");
					:set isOsNeedsToBeUpdated false;
				}
			}

			#Check again, because this variable could be changed during checking for installing only patch updats
			if ($isOsNeedsToBeUpdated = true) do={
				:set mailSubject 	($mailSubject . " New RouterOS is going to be installed! v.$deviceOsVerInst -> v.$deviceOsVerAvail");
				:set mailBody 		($mailBody . "\r\n\r\nYour Mikrotik will be updated to the new RouterOS version from v.$deviceOsVerInst to v.$deviceOsVerAvail (Update channel: $updateChannel) \r\nFinal report with detailed information will be sent when update process is completed. \r\nIf you have not received second email in the next 5 minutes, then probably something went wrong.");
				#!! There is more code connected to this part and first step at the end of the script.
			}
		
		}
	}


	# Combine fisrst step email
	:set mailBody ($mailBody . $mailBodyDeviceInfo . $mailBodyCopyright);
	:log info ("Bkp&Upd: Sending email with backups in attachment.");
}

# Remove function brGlobalFuncGetOsVerNum from global environment to keep it fresh and clean.
:do {/system script environment remove brGlobalFuncGetOsVerNum;} on-error={}

## 	STEP TWO: (after first reboot) routerboard firmware upgrade
## 	steps 2 and 3 are fired only if script is set to automatically update device and if new RouterOs is available.
:if ($updateStep = 2) do={
	:log info ("Bkp&Upd: Performing the second step.");   
	## RouterOS is the latest, let's check for upgraded routerboard firmware
	if ($deviceRbCurrentFw != $deviceRbUpgradeFw) do={
		:delay 10s;
		:log info "Bkp&Upd: Upgrading routerboard firmware from v.$deviceRbCurrentFw to v.$deviceRbUpgradeFw";
		## Start the upgrading process
		/system routerboard upgrade;
		## Wait until the upgrade is completed
		:delay 5s;
		:log info "Bkp&Upd: routerboard upgrading process was completed, going to reboot in a moment!";
		## Set scheduled task to send final report on the next boot, task will be deleted when is is done. (That is why you should keep original script name)
		/system schedule add name=BKPUPD-FINAL-REPORT-ON-NEXT-BOOT on-event=":delay 5s; /system scheduler remove BKPUPD-FINAL-REPORT-ON-NEXT-BOOT; :global brGlobalVarUpdateStep 3; :delay 10s; /system script run BackupAndUpdate;" start-time=startup interval=0;
		## Reboot system to boot with new firmware
		/system reboot;
	}
}

## 	STEP THREE: Last step (after second reboot) sending final report
## 	steps 2 and 3 are fired only if script is set to automatically update device and if new RouterOs is available.
:if ($updateStep = 3) do={
	:delay 1m;
	:log info "Bkp&Upd: RouterOS and routerboard upgrading process of was completed. New RouterOS version: v.$deviceOsVerInst, routerboard firmware: v.$deviceRbCurrentFw.";
	:set mailSubject	"Bkp&Upd: Router - $[:pick $deviceIdentityName 0 18] has been upgraded to the new RouterOS v.$deviceOsVerInst!";
	:set mailBody 	  	"RouterOS and routerboard upgrading process was completed. \r\nNew RouterOS version: v.$deviceOsVerInst, routerboard firmware: v.$deviceRbCurrentFw. \r\n$changelogUrl $mailBodyDeviceInfo $mailBodyCopyright";
}

##
## SENDING EMAIL
##
# Trying to send email with backups in attachment.
:if ($updateStep = 1 or $updateStep = 3) do={
	:do {/tool e-mail send to=$emailAddress subject=$mailSubject body=$mailBody file=$mailAttachments;} on-error={
		:log error "Bkp&Upd: could not send email message ($[/tool e-mail get last-status]). Going to try it again in a while."
		:delay 5m;
			:do {/tool e-mail send to=$emailAddress subject=$mailSubject body=$mailBody file=$mailAttachments;} on-error={
				:log error "Bkp&Upd: could not send email message ($[/tool e-mail get last-status]) for the second time."

				if ($isOsNeedsToBeUpdated = true) do={
					:log warning "Bkp&Upd: script didn't initialise update process due to inability to send backups to email."
				}
			}
	}
	:delay 5s;
}



## Remove backups which we have already sent during first step
:if ($updateStep = 1 and [/tool e-mail get last-status] = "succeeded") do={
	:log info "Bkp&Upd: File system cleanup."
	/file remove $mailAttachments; 
	:delay 2s;

	# Fire update process only if backups were successfully sent
	if ($isOsNeedsToBeUpdated = true) do={

		## Set scheduled task to upgrade routerboard firmware on the next boot, task will be deleted when upgrade is done. (That is why you should keep original script name)
		/system schedule add name=BKPUPD-UPGRADE-ON-NEXT-BOOT on-event=":delay 5s; /system scheduler remove BKPUPD-UPGRADE-ON-NEXT-BOOT; :global brGlobalVarUpdateStep 2; :delay 10s; /system script run BackupAndUpdate;" start-time=startup interval=0;
	   
	   :log info "Bkp&Upd: everything is ready to install new RouterOS, going to reboot in a moment!"
		## command is reincarnation of the "upgrade" command - doing exactly the same but under a different name
		/system package update install;
	}
}


:log info "Bkp&Upd: script \"Mikrotik RouterOS automatic backup & update\" completed it's job.\r\n";