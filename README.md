# Mikrotik RouterOS automatic backup and update

This script allows you to generate daily backups of MikroTik and send them to an email address. You can also choose to enable automatic RouterOS upgrades or receive notifications exclusively for new firmware versions.
> 💡 If you have any ideas about the script or you just want to share your opinion, you are welcome to [Discussions](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/discussions), or you can open an [issue](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/issues) if you found a bug.


## Features:
- Select the script's operational mode according to your specific needs (details provided below). 
- This script is designed to create full system backups and export configurations. 
- Customize the update channel according to your preference. 
- With automatic updates activated, the script can be set to apply only patch updates for RouterOS. For instance, should the current RouterOS version be v6.43.6, the script will autonomously upgrade to v6.43.7 (a patch update), while avoiding v6.44.0 (a minor update).*
- The script also incorporates vital device details in the email alerts, facilitating easy identification of the necessary backup among several devices. 
- For added security, the script is programmed to stop the automatic update process if it fails to dispatch backups via email. 
- Routerboard firmware can be upgraded automatically based on the installed RouterOS version.

## Script operating modes:
**Backups only** - The script generates system and configuration backups and forwards them to a specified email as attachments. It uses your email account as a storage for these backups.  
**Backups and notifications about new RouterOS release** -  In addition to creating backups, the script also monitors for any new releases of RouterOS firmware and communicates this information via email.  
**Backups and automatic RouterOS upgrade** - The script begins by creating a backup, followed by a check for any new versions of RouterOS. If a newer firmware version is detected, the script initiates the upgrade process. Upon completion, two emails are sent: the first includes the system backups from the prior RouterOS version, and the second, sent post-upgrade, contains backups of the updated system.

## How to use
> ❗️ **Important**  
> Ensure your device identity does not contain spaces and special characters! `System -> Identity`

##### 1. Configure parameters
Take the  [script](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/BackupAndUpdate.rsc) and configure it's parameters at the beginning of the file.  
This step is straightforward as all parameters are well-commented.
**Important!** Don't forget to provide correct email address for backups and pay attention to `scriptMode` variable.

##### 2. Create new script
System -> Scripts [Add]  

**Important!** Script name must be `BackupAndUpdate`   
Insert the script which you configured earlier into the source area.  
![](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/howto/script-name.png)  

##### 3. Configure mail server
Tools -> Email  
Configure your email server parameters. If you don't have one, i recommend using the [smtp2go.com](https://smtp2go.com "smtp2go.com") service, which allows sending a thousand emails per month for free.  
![](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/howto/email-config.png)  

To check email settings, send a test message by running the following command in terminal:
```
/tool e-mail send to="yourMail@example.com" subject="backup & update test!" body="It works!";
```

##### 4. Create scheduled task
System -> Scheduler [Add]  
Name: `Backup And Update`  
Start Time: `03:10:00` (the start time has to be different for all your mikrotik devices in a chain)  
Interval: `1d 00:00:00`  
On Event: `/system script run BackupAndUpdate;`  
![](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/howto/scheduler-task.png)  
  
Or you can use this command to create the task:
```
/system scheduler add name="Firmware Updater" on-event="/system script run BackupAndUpdate;" start-time=03:10:00 interval=1d comment="" disabled=no
```
##### 5. Test the script
Once everything is set up, it's important to verify that the script is functioning properly. 
To do this, open a New Terminal and a Log window in your WinBox, then manually execute the script by typing `/system script run BackupAndUpdate;` in the Terminal.
You will see the script the script's operation in the log window. If the script completes without any errors, check your email. You'll find a new message with backups from your MikroTik awaiting you. 🎉






## Acknowledgements
I would like to extend my sincere gratitude to the following individuals who have contributed to this project:
 - DJ5KP, website: [dj5kp.de](http://dj5kp.de/)

Special thanks to the talented people who are working at [MikroTik](https://mikrotik.com) for their contributions in creating such outstanding products.

## License

The MIT License (MIT). Please see [License File](LICENSE.md) for more information.

---
If you love this project, please buy more mikrotiks ;) and consider giving me a ⭐

[__Buy me a coffee! :coffee:__](https://www.buymeacoffee.com/beeyev)

![](https://visitor-badge.laobi.icu/badge?page_id=beeyev.Mikrotik-RouterOS-automatic-backup-and-update)
