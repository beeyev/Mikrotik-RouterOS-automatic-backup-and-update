# Script name: firmware-updater

########## Set variables
## Notification e-mail
:local emailEnabled true;
:local emailAddress "email@example.com";
:local sendBackupToEmail true;

## Backup encryption password, no encryption if no password.
:local backupPassword ""
## If true, passwords will be included in exported config
:local sensetiveDataInConfig false;

## Update channel. Possible values: current, bugfix
:local updateChannel "current";
##########


## !!!! DO NOT CHANGE ANYTHING BELOW THIS LINE, IF YOU ARE NOT SURE WHAT YOU ARE DOING !!!! ##
:log info ("Firmware checking and upgrade process has started");   
## Set global var to the local one, then delete it form the global environment
:global beeGlobalUpdateStep;
:local updateStep $beeGlobalUpdateStep;
/system script environment remove beeGlobalUpdateStep

## if it is a very first step
:if ([:len $updateStep] = 0) do={
	## Check for update
	/system package update set channel=$updateChannel;
	/system package update check-for-updates;
	
	# If we found some updates
	:if ([/system package update get installed-version] != [/system package update get latest-version]) do={ 
		## New version of RouterOS available, let's upgrade
		:log info ("Upgrading RouterOS on router $[/system identity get name], board name: $[/system resource get board-name], serial number: $[/system routerboard get serial-number] | From $[/system package update get installed-version] to $[/system package update get latest-version] (channel:$[/system package update get channel])");   
	   
		:if ($emailEnabled = true) do={
			:local attachments;
			
			:if ($sendBackupToEmail = true) do={
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
					/system backup save encryption=aes-sha256 password=$backupPassword name=$bname;
				}
				
				## Export config file
				:if ($sensetiveDataInConfig = true) do={
					/export compact file=$bname;
				} else={
					/export compact hide-sensitive file=$bname;
				}
				
				## Wait until bakup is done
				:delay 15s;
			}
			
			/tool e-mail send to=$emailAddress subject="Upgrade router: $[/system identity get name] FW has been started" body="Upgrading RouterOS on router $[/system identity get name] from $[/system package update get installed-version] to $[/system package update get latest-version] \r\nYou will recieve final report with detailed information when upgrade process is finished. If you have not got second email in next 5 minutes, then probably something went wrong." file=$attachments;
			
			## Wait for mail to be send & upgrade
			:delay 15s;
			
			## Remove backups which we have already sent
			:if ($sendBackupToEmail = true && [/tool e-mail get last-status] = "succeeded") do={
				/file remove $attachments; 
			}
		}
		
		## Set scheduled task to upgrade routerboard firmware on the next boot, task will be deleted when upgrade is done. (That is why you should keep original script name)
		/system schedule add name=BEE-UPGRADE-NEXT-BOOT on-event="/system scheduler remove BEE-UPGRADE-NEXT-BOOT; :global beeGlobalUpdateStep \"routerboardUpgrade\"; :delay 5s; /system script run firmware-updater;" start-time=startup interval=0;
	   
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
		:delay 30s;
		
		## Set scheduled task to send final report on the next boot, task will be deleted when is is done. (That is why you should keep original script name)
		/system schedule add name=BEE-FINAL-REPORT-NEXT-BOOT on-event="/system scheduler remove BEE-FINAL-REPORT-NEXT-BOOT; :global beeGlobalUpdateStep \"finalReport\"; :delay 10s; /system script run firmware-updater;" start-time=startup interval=0;
	
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