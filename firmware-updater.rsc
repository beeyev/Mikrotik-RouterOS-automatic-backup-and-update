# Script name: firmware-updater

########## Set variables
## Notification e-mail
:local emailEnabled true;
:local emailAddress "yourmail@example.com";
:local sendBackupToEmail true;

## Backup encryption password, no encryption if no password.
:local backupPassword ""
## If true, passwords will be included in exported config
:local sensetiveDataInConfig false;

## Update channel. Possible values: stable, long-term
:local updateChannel "stable";

## Install only patch versions of firmware updates.
## Means that new update will be installed only if major and minor version numbers are the same as currently installed firmware.
## Example: v6.43.6 => major.minor.PATCH
:local onlyPatchUpdates	false;
##########

## !!!! DO NOT CHANGE ANYTHING BELOW THIS LINE, IF YOU ARE NOT SURE WHAT YOU ARE DOING !!!! ##

############### vvvvvvvvv GLOBAL FUNCTIONS vvvvvvvvv ###############
# Function converts standard mikrotik build versions to the number.
# Possible arguments: osVer
# Example:
# :put [$getOsVerNum osVer=[/system routerboard get current-firmware]];
# result will be: 64301, because current-firmware value is: 6.43.1
:global getOsVerNum do={
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
############### ^^^^^^^^^ GLOBAL FUNCTIONS ^^^^^^^^^ ###############

#Check proper email config
:if ($emailEnabled = true and ([:len $emailAddress] = 0 or [:len [/tool e-mail get address]] = 0 or [:len [/tool e-mail get from]] = 0)) do={
	:log warning ("Email notifications switched off, you need to check your e-mail configuration. Tools -> Email");   
	:set emailEnabled false;
}

:log info ("Firmware checking and upgrade process has started");   
#load global var
:global beePatchUpdateInapplicable;
## Set global var to the local one, then delete it form the global environment
:global beeGlobalUpdateStep;
:local updateStep $beeGlobalUpdateStep;
/system script environment remove beeGlobalUpdateStep;

:log info ("Update step: $updateStep");   

## if it is a very first step
:if ([:len $updateStep] = 0) do={

	# Convert current version to numeric (6.43.8 => 64308)
	:local osVerCurrent [/system package update get installed-version];
	:local osVerCurrentNum [$getOsVerNum osVer=$osVerCurrent];

	## We need this part to keep compatibility with firmware older than 6.43.7
	:if ($osVerCurrentNum < 64307 and [:len [:find "bugfix current release-candidate" $updateChannel 0]] = 0) do={
		:if ($updateChannel = "stable") do={
			:set updateChannel "current";
		} else={
			:if ($updateChannel = "long-term") do={
				:set updateChannel "bugfix";
			} else={
				:if ($updateChannel = "testing") do={
					:set updateChannel "release-candidate";
				}
			}
		}
	}
	log info ("Checking for new firmware version. Current version is: $osVerCurrent");
	/system package update set channel=$updateChannel;
	/system package update check-for-updates;
	:delay 5s;

	# Getting info about new available firmware version
	:local osVerNew [/system package update get latest-version];
	:delay 5s;
	
	# If there is a problem getting information about available firmware from server
	:if ([:len $osVerNew] = 0) do={
		:log info ("There is a problem getting information about available firmware from server. No internet connection \?");
		:error "Error during firmware-updater script execution, please see log.";
	}
	
	# Convert new version to numeric (6.43.8 => 64308)
	:local osVerNewNum [$getOsVerNum osVer=$osVerNew];
	# Remove function getOsVerNum from global environment to keep it fresh and clean.
	:set getOsVerNum;

	# Compare new and current versions
	:local isUpdateAvailable false;
	:if ($osVerNewNum > $osVerCurrentNum) do={
		:set isUpdateAvailable true;
		:log info ("New firmware version found: $osVerNew");
	} else={
		:log info ("New firmware version not found.")
	}

	# If only patch updates are allowed
	:if ($onlyPatchUpdates = true and $isUpdateAvailable = true) do={
		#Check if Major and Minor builds are the same.
		:if ([:pick $osVerCurrentNum 0 ([:len $osVerCurrentNum]-2)] = [:pick $osVerNewNum 0 ([:len $osVerNewNum]-2)]) do={
			:log info ("New patch version of RouterOS firmware is available.");   
		} else={
			:log info ("New major version of RouterOS firmware is available. You have to update it manually.");   
			:set isUpdateAvailable false;
			#Send email just once
			:if ($beePatchUpdateInapplicable != true and $emailEnabled = true) do={
				:log info ("Email was sent just once.");   
				/tool e-mail send to="$emailAddress" subject="Router: $[/system identity get name], new major version of RouterOS firmware is available: v$osVerNew" body="New major version of RouterOS firmware is available. You have to update it manually.. \r\n\r\nRouter name: $[/system identity get name]\r\nCurrent RouterOS version: $osVerCurrent; Routerboard firmware: $[/system routerboard get current-firmware]; Update channel: $[/system package update get channel]; \r\nBoard name: $[/system resource get board-name]; Serial number: $[/system routerboard get serial-number]; \r\n\r\n Changelog: https://mikrotik.com/download/changelogs/current-release-tree"; 
				:delay 5s;
				# If notification was sent, we no longer bother with it.
				:if ([/tool e-mail get last-status] = "succeeded") do={
					:global beePatchUpdateInapplicable true;
				}
			}
		}
	}

	#Keep environment clean
	:if ($isUpdateAvailable = true and $beePatchUpdateInapplicable = true) do={
		/system script environment remove beePatchUpdateInapplicable;
	}

	# If we found some updates
	:if ($isUpdateAvailable = true) do={ 
		## New version of RouterOS available, let's upgrade
		:log info ("Going to update RouterOS firmware from $osVerCurrent to $osVerNew (channel:$updateChannel)");   
		
		:if ($emailEnabled = true) do={
			:local attachments;
			
			#M# acking system backups to attach them in email.
			:if ($sendBackupToEmail = true) do={
				:log info ("Making system backups.");   
				## date and time in format: 2018aug06-215139
				:local dtame ([:pick [/system clock get date] 7 11] . [:pick [/system clock get date] 0 3] . [:pick [/system clock get date] 4 6] . "-" . [:pick [/system clock get time] 0 2] . [:pick [/system clock get time] 3 5] . [:pick [/system clock get time] 6 8]);
				## unified backup file name without extension
				:local bname "$[/system identity get name].$[/system routerboard get serial-number].v$[/system package update get installed-version]_$dtame";
				:local sysFileBackup "$bname.backup";
				:local configFileBackup "$bname.rsc";
				:set attachments {$sysFileBackup;$configFileBackup}

				## Make system backup
				:if ([:len $backupPassword] = 0) do={
					/system backup save dont-encrypt=yes name=$bname;
				} else={
					/system backup save password=$backupPassword name=$bname;
				}
				
				## Export config file
				:if ($sensetiveDataInConfig = true) do={
					/export compact file=$bname;
				} else={
					/export compact hide-sensitive file=$bname;
				}
				:delay 5s;
			}
			
			:log info ("Sending email");   
			/tool e-mail send to=$emailAddress subject="Upgrade router: $[/system identity get name] FW has been started" body="Upgrading RouterOS on router $[/system identity get name] from $osVerCurrent to $osVerNew \r\nYou will recieve final report with detailed information when upgrade process is finished. If you have not got second email in next 5 minutes, then probably something went wrong." file=$attachments;
			:delay 5s;
			
			## Remove backups which we have already sent
			:if ($sendBackupToEmail = true && [/tool e-mail get last-status] = "succeeded") do={
				/file remove $attachments; 
			}
			
		}
		
		## Set scheduled task to upgrade routerboard firmware on the next boot, task will be deleted when upgrade is done. (That is why you should keep original script name)
		/system schedule add name=BEE-UPGRADE-NEXT-BOOT on-event="/system scheduler remove BEE-UPGRADE-NEXT-BOOT; :global beeGlobalUpdateStep \"routerboardUpgrade\"; :delay 15s; /system script run firmware-updater;" start-time=startup interval=0;
	   
		## command is reincarnation of the "upgrade" command - doing exactly the same but under a different name
		/system package update install;
	}
}


## Second step (after first reboot) routerboard firmware upgrade
:if ( $updateStep = "routerboardUpgrade") do={
	
	## RouterOS latest, let's check for updated firmware

	:if ( [/system routerboard get current-firmware] != [/system routerboard get upgrade-firmware]) do={			
		## New version of firmware available, let's upgrade
		:log info ("Upgrading firmware on router $[/system identity get name], board name: $[/system resource get board-name], serial number: $[/system routerboard get serial-number] | From $[/system routerboard get current-firmware] to $[/system routerboard get upgrade-firmware]");
			
		## Start the upgrading process
		/system routerboard upgrade;
		
		## Wait until the upgrade is finished
		:delay 5s;
		
		## Set scheduled task to send final report on the next boot, task will be deleted when is is done. (That is why you should keep original script name)
		/system schedule add name=BEE-FINAL-REPORT-NEXT-BOOT on-event="/system scheduler remove BEE-FINAL-REPORT-NEXT-BOOT; :global beeGlobalUpdateStep \"finalReport\"; :delay 15s; /system script run firmware-updater;" start-time=startup interval=0;
	
		## Reboot system to boot with new firmware
		/system reboot;
	}
}

## Last step (after second reboot) sending final report
:if ( $updateStep = "finalReport") do={
	:log info "Upgrading RouterOS and routerboard firmware finished. Current RouterOS version: $[/system package update get installed-version], routerboard firmware: $[/system routerboard get current-firmware].";
	
	:if ($emailEnabled = true) do={
		/tool e-mail send to="$emailAddress" subject="Router: $[/system identity get name] has been upgraded with new FW!" body="Upgrading RouterOS and routerboard firmware finished. \r\n\r\nRouter name: $[/system identity get name]\r\nCurrent RouterOS version: $[/system package update get installed-version]; Routerboard firmware: $[/system routerboard get current-firmware]; Update channel: $[/system package update get channel]; \r\nBoard name: $[/system resource get board-name]; Serial number: $[/system routerboard get serial-number]; \r\n\r\n Changelog: https://mikrotik.com/download/changelogs/current-release-tree"; 
	}
}

:log info ("Firmware updater has finished it's job");   