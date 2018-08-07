# Script name: firmware-updater

########## Set variables
## Notification e-mail
:local emailEnabled true
:local emailAddress "email@example.com"
:local sendBackupToEmail true
##########


## !!!! DO NOT CHANGE ANYTHING BELOW THIS LINE !!!! ##

:global beeUpdateStep;

## Check for update
/system package update
set channel=current
check-for-updates

## Wait on slow connections
:delay 15s;

## First step, check for new updates
:if ([:len $beeUpdateStep] = 0 && [get installed-version] != [get latest-version]) do={ 
	## New version of RouterOS available, let's upgrade
	:log info ("Upgrading RouterOS on router $[/system identity get name], board name: $[/system resource get board-name], serial number: $[/system routerboard get serial-number] | From $[/system package update get installed-version] to $[/system package update get latest-version] (channel:$[/system package update get channel])")     
   
	:if ($emailEnabled = true) do={
		:local attachments;
		
		:if ($sendBackupToEmail = true) do={
			## date and time in format: 2018aug06-215139
			:local dtame ([:pick [/system clock get date] 7 11] . [:pick [/system clock get date] 0 3] . [:pick [/system clock get date] 4 6] . "-" . [:pick [/system clock get time] 0 2] . [:pick [/system clock get time] 3 5] . [:pick [/system clock get time] 6 8]);
			## unified backup file name without extension
			:local bname "$[/system identity get name].$[/system routerboard get serial-number].v$[/system package update get installed-version]_$dtame"
			:local sysFileBackup "$bname.backup"
			:local configFileBackup "$bname.rsc"
			:set attachments {$sysFileBackup;$configFileBackup}

			## Make system backup
			/system backup save dont-encrypt=yes name=$bname
			## Export config file
			/export compact file=$bname

			## Wait until bakup is done
			:delay 15s;
		}
		
		/tool e-mail send to=$emailAddress subject="Upgrade router: $[/system identity get name] FW has been started" body="Upgrading RouterOS on router $[/system identity get name] from $[/system package update get installed-version] to $[/system package update get latest-version] \r\nYou will recieve final report with detailed information when upgrade process is finished. If you have not got second email in next 5 minutes, then probably something went wrong." file=$attachments
		
		## Wait for mail to be send & upgrade
		:delay 15s;
		
		## Remove backups which we have already sent
		:if ($sendBackupToEmail = true && [/tool e-mail get last-status] = "succeeded") do={
			/file remove $attachments; 
		}
	}
	
	
	## Set scheduled task to upgrade routerboard firmware on the next boot, task will be deleted when upgrade is done. (That is why you should keep original script name)
	/system schedule add name=BEE-UPGRADE-NEXT-BOOT on-event=":global beeUpdateStep \"routerboardUpgrade\"; :delay 1s; /system script run firmware-updater;" start-time=startup interval=0
   
	## "install" command is reincarnation of the "upgrade" command - doing exactly the same but under a different name
	install
}

## Second step (after first reboot) routerboard firmware upgrade
:if ( $beeUpdateStep = "routerboardUpgrade") do={
	
	## Remove global variable for this step
	/system script environment remove beeUpdateStep;
	## Remove task because we need it just once, right after reboot next to RouterOS install
	/system scheduler remove BEE-UPGRADE-NEXT-BOOT
	
	## RouterOS latest, let's check for updated firmware
	/system routerboard

	:if ( [get current-firmware] != [get upgrade-firmware]) do={			
		## New version of firmware available, let's upgrade
		:log info ("Upgrading firmware on router $[/system identity get name], board name: $[/system resource get board-name], serial number: $[/system routerboard get serial-number] | From $[/system routerboard get current-firmware] to $[/system routerboard get upgrade-firmware]")
			
		## Start the upgrading process
		upgrade
		
		## Wait until the upgrade is finished
		:delay 60s;
		
		## Set scheduled task to send final report on the next boot, task will be deleted when is is done. (That is why you should keep original script name)
		/system schedule add name=BEE-FINAL-REPORT-NEXT-BOOT on-event=":global beeUpdateStep \"finalReport\"; :delay 1s; /system script run firmware-updater;" start-time=startup interval=0
	
		## Reboot system to boot with new firmware
		/system reboot
	}
}

## Last step (after second reboot) sending final report
:if ( $beeUpdateStep = "finalReport") do={
	## Remove global variable for this step
	/system script environment remove beeUpdateStep;
	## Remove task because we need it just once
	/system scheduler remove BEE-FINAL-REPORT-NEXT-BOOT
	
	:log info "Upgrading RouterOS and routerboard firmware finished. Current RouterOS version: $[/system package update get installed-version], routerboard firmware: $[/system routerboard get current-firmware]."
	
	:if ($emailEnabled = true) do={
		/tool e-mail send to="$emailAddress" subject="Router: $[/system identity get name] has been upgraded with new FW!" body="Upgrading RouterOS and routerboard firmware finished. \r\n\r\nRouter name: $[/system identity get name]\r\nCurrent RouterOS version: $[/system package update get installed-version]; Routerboard firmware: $[/system routerboard get current-firmware]; Update channel: $[/system package update get channel]; \r\nBoard name: $[/system resource get board-name]; Serial number: $[/system routerboard get serial-number]; \r\n\r\n Changelog: https://mikrotik.com/download/changelogs/current-release-tree" 
	}
}