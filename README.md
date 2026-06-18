# Mikrotik RouterOS automatic backup and update

This script allows you to generate daily backups of MikroTik and send them to an email address or upload them to an FTP/SFTP server. You can also choose to enable automatic RouterOS upgrades or receive notifications exclusively for new firmware versions.
> 💡 If you have any ideas about the script or you just want to share your opinion, you are welcome to [Discussions](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/discussions), or you can open an [issue](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/issues) if you found a bug.


## Features:
- Select the script's operational mode according to your specific needs (details provided below). 
- This script is designed to create full system backups and export configurations. 
- Choose between email delivery, FTP/SFTP upload, or both for backup storage.
- Customize the update channel according to your preference. 
- With automatic updates activated, the script can be set to apply only patch updates for RouterOS. For instance, should the current RouterOS version be v6.43.6, the script will autonomously upgrade to v6.43.7 (a patch update), while avoiding v6.44.0 (a minor update).*
- The script also incorporates vital device details in the notifications, facilitating easy identification of the necessary backup among several devices.
- For added security, the script is programmed to stop the automatic update process if it fails to dispatch backups.
- Routerboard firmware can be upgraded automatically based on the installed RouterOS version.

## Script operating modes:
- **Backups only** - The script generates system and configuration backups and sends them via email or uploads them to an FTP/SFTP server. It uses your email account or FTP/SFTP server as storage for these backups.
- **Backups and notifications about new RouterOS release** -  In addition to creating backups, the script also monitors for any new releases of RouterOS firmware and communicates this information via email (if email is configured).
- **Backups and automatic RouterOS upgrade** - The script begins by creating a backup, followed by a check for any new versions of RouterOS. If a newer firmware version is detected, the script initiates the upgrade process. Upon completion, two notifications are sent: the first includes the system backups from the prior RouterOS version, and the second, sent post-upgrade, contains backups of the updated system.

## How to use
> ❗️ **Important**  
> Ensure your device identity does not contain spaces and special characters! `System -> Identity`

##### 1. Configure parameters
Take the  [script](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/BackupAndUpdate.rsc) and configure it's parameters at the beginning of the file.  
This step is straightforward as all parameters are well-commented.  
**Important!** Pay attention to `scriptMode` and `backupTransport` variables.

**Backup Transport Options:**
- `{"email"}` - Send backups via email (default, requires email configuration)
- `{"ftp"}` - Upload backups to FTP/SFTP server (requires FTP URL configuration)
- `{"email";"ftp"}` - Use both methods (array with multiple values)

##### 2. Create new script
> In this example we use [WinBox](https://mikrotik.com/download/winbox)  

Go to: `System` -> `Scripts` and click  the `[New]` button. 

**Important!** Script name must be `BackupAndUpdate`   
Insert the script which you configured earlier into the source area.  
![](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/howto/script-name.png)  

##### 3. Configure backup transport

**Option A: Email (default)**
Go to: `Tools` -> `Email` and click  the `[New]` button.  
Configure your email server parameters. If you don't have one, i recommend using the [smtp2go.com](https://smtp2go.com "smtp2go.com") service, which allows sending a thousand emails per month for free.  
![](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/howto/email-config.png)  

To check email settings, send a test message by running the following command in terminal:
```bash
/tool e-mail send to="yourMail@example.com" subject="backup & update test!" body="It works!";
```

**Option B: FTP/SFTP Upload**
Configure an FTP or SFTP server to receive the backup files. Most NAS devices have built-in FTP/SFTP servers, or you can enable SSH on any Linux server (SFTP is included with SSH).

**Script configuration for FTP:**
```rsc
:local backupTransport {"ftp"}
:local backupFtpUrl "ftp://192.168.1.10"
:local backupFtpPath "/backups/"
:local backupFtpUser "backup-user"
:local backupFtpPassword "secure-password"

# Optional: Configure email for error notifications even when using FTP for backups
:local emailAddress "admin@example.com"
```

**Script configuration for SFTP:**
```rsc
:local backupTransport {"ftp"}
:local backupFtpUrl "sftp://192.168.1.10"
:local backupFtpPath "/home/backup/"
:local backupFtpUser "backup-user"
:local backupFtpPassword "secure-password"
```

**Configuration notes:**
- `backupFtpUrl`: Server address only (no path). Use `ftp://` or `sftp://` scheme.
- `backupFtpPath`: Remote directory path. Must start and end with `/`.
  - Supports `%identity%` placeholder for device-specific directories.
  - Example: `"/backups/%identity%/"` expands to `"/backups/myrouter/"`
  - **Important**: The directory must exist on the FTP/SFTP server before first upload.
- Both FTP and SFTP are supported via the URL scheme.
- **Error notifications**: If `emailAddress` is configured, error notifications will be sent via email even when using FTP-only for backups. This is recommended for monitoring update failures.

**Example with per-device directories:**
```rsc
:local backupFtpPath "/backups/%identity%/"
```
This creates separate directories for each device based on its identity name.

**Setting up directories:**
When using `%identity%` placeholder, you'll need to create the directories on your FTP/SFTP server before the first backup runs. For example, if you have devices named `hEX`, `Office-Switch`, and `Gateway`:
```bash
# On your FTP/SFTP server:
mkdir -p /backups/hEX
mkdir -p /backups/Office-Switch
mkdir -p /backups/Gateway
```

Or run the script once on each device to see the expanded path in the logs, then create those directories.

**Testing FTP/SFTP upload:**
```bash
/tool fetch url="ftp://192.168.1.10" upload=yes src-path="somefile.txt" dst-path="/backups/test.txt" user="backup-user" password="secure-password"
```

##### 4. Create scheduled task
Go to: `System` -> `Scheduler` and click the `[Add]` button.  
Name: `Backup And Update`  
Start Time: `03:10:00` (the start time has to be different for all your mikrotik devices in a chain)  
Interval: `1d 00:00:00`  
On Event: `/system script run BackupAndUpdate;`  
![](https://github.com/beeyev/Mikrotik-RouterOS-automatic-backup-and-update/raw/master/howto/scheduler-task.png)  
  
Or you can use this command to create the task:
```bash
/system scheduler add name="Firmware Updater" on-event="/system script run BackupAndUpdate;" start-time=03:10:00 interval=1d comment="" disabled=no
```
##### 5. Test the script
Once everything is set up, it's important to verify that the script is functioning properly. 
To do this, open a New Terminal and a Log window in your WinBox, then manually execute the script by typing `/system script run BackupAndUpdate;` in the Terminal.
You will see the script's operation in the log window. If the script completes without any errors:
- **Email transport**: Check your email for a new message with backups from your MikroTik. 🎉
- **FTP transport**: Check your FTP/SFTP server directory for the backup files.
- **Both**: Verify both locations.





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
