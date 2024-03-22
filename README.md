# Mikrotik RouterOS automatic backup and update

This script allows you to generate daily backups of MikroTik and send them to an email address. You can also choose to enable automatic RouterOS upgrades or receive notifications exclusively for new firmware versions.


> 💡 If you have any ideas about the script or you just want to share your opinion, you are welcome to [Discussions](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/discussions), or you can open an [issue](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/issues) if you found a bug.


## Features:
- Choose the script's operating mode based on your specific requirements. (See details below)
- The script generates backups of the entire system and exports the configuration.
- Customize your preferred update channel.
- When automatic updates are enabled, you can configure the script to install only patch versions of RouterOS updates. *For example, if the current RouterOS version is v6.43.6, the script will automatically install v6.43.7 (a new patch version) but not v6.44.0 (a new minor version).*
- The script includes essential device information into the email message, making it easy to identify the required backup among multiple devices.
- As a safety measure, the automatic update process will not initiate if the script is unable to send backups via email.
- Routerboard firmware can be upgraded automatically based on the installed RouterOS version.

## Script operating modes:
**Backups only** - script creates system and config backups and sends them to specified email as an attachment. Using email account as storage for your backups.  
**Backups and notifications about new RouterOS release** - Except backups, script also checks for new RouterOS firmware release and provides this information in the email.  
**Backups and automatic RouterOS upgrade** - Script makes a backup, then checks for new RouterOS version, and if new firmware released, script will initiate upgrade process. By the end, you receive two emails. The first one contains system backups of the previous RouterOS version, the second message will be sent when the upgrade process is done (including backups of the updated system).

## How to use
> ❗️ **Important**  
> Make sure that your device identity does not contain any spaces or specific symbols! `System -> Identity`

##### 1. Configure parameters
Take the  [script](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/BackupAndUpdate.rsc) and configure it's parameters at the begining of the file.  
This is not difficult because all parameters are well commented.  
**Important!** Don't forget to provide correct email address for backups and pay attention to `scriptMode` variable.

##### 2. Create new script
System -> Scripts [Add]  

**Important!** Script name has to be `BackupAndUpdate`   
Put the script which you configured earlier into the source area.  
![](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/howto/script-name.png)  

##### 3. Configure mail server
Tools -> Email  
Set your email server parameters. If you don't have one, i recommend to use [smtp2go.com](https://smtp2go.com "smtp2go.com") service, it allows sending a thousand emails per month for free.  
![](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/howto/email-config.png)  

To check email settings, send a test message by running the following command in terminal:
```
/tool e-mail send to="yourMail@example.com" subject="backup & update test!" body="It works!";
```

##### 4. Create scheduled task
System -> Scheduler [Add]  
Name: `Backup And Update`  
Start Time: `03:10:00` (the start time has to be different for all your mikrotik device in a chain)  
Interval: `1d 00:00:00`  
On Event: `/system script run BackupAndUpdate;`  
![](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/howto/scheduler-task.png)  
  
Or you can use this command to create the task:
```
/system scheduler add name="Firmware Updater" on-event="/system script run BackupAndUpdate;" start-time=03:10:00 interval=1d comment="" disabled=no
```
##### 5. Test the script
When everything is done, you need to make sure that the script is working correctly.  
To do so, open a New Terminal and Log window in your WinBox, then run the script manually by executing this command `/system script run BackupAndUpdate;` in Terminal.  
You will see the script working process in the log window. If the script finished without errors, check your email, there is a fresh message with backups from your MikroTik waiting for you 🎉

## Contributors

 - DJ5KP, website: [dj5kp.de](http://dj5kp.de/)

## License

The MIT License (MIT). Please see [License File](LICENSE.md) for more information.

---
If you love this project, please consider giving me a ⭐

[__Buy me a coffee! :coffee:__](https://www.buymeacoffee.com/beeyev)

![](https://visitor-badge.laobi.icu/badge?page_id=beeyev.Mikrotik-RouterOS-automatic-backup-and-update)
