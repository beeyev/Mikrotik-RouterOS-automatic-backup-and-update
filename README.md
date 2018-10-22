# Mikrotik Firmware Auto Updater
Script automatically updates router to the latest firmware.  
When script finds new uptate it sends email notification that upgrade process has started, system backup and config file are in attachment. After firmware and routerboard got updated, it sends second email which tells that upgrade process has been finished.

## How to use
##### 1. Create new script
System -> Scripts [Add]  
**Imprtant! ** Script name has to be **firmware-updater**  
Put script source and **set your email address** to the variable *emailAddress*  
![](https://github.com/beeyev/Mikrotik-Firmware-Auto-Updater/raw/master/howto/script-name.png)  

##### 2. Configure mail server
Tools -> Email  
Set your email server parameters. If you don't have one, i recommend to use [smtp2go.com](https://smtp2go.com "smtp2go.com") service, it allows to send thousand emails per month for free.  
![](https://github.com/beeyev/Mikrotik-Firmware-Auto-Updater/raw/master/howto/email-config.png)  

##### 3. Create scheduled task
System -> Scheduler [Add]  
Name: Firmware Updater 
Start Time: 03:00:00  
Interval: 1d 00:00:00  
On Event: /system script run firmware-updater;  
![](https://github.com/beeyev/Mikrotik-Firmware-Auto-Updater/raw/master/howto/scheduler-task.png)  
  
Or you can use this command to create the task:
```
/system scheduler add name="Firmware Updater" on-event="/system script run firmware-updater;" start-time=03:00:00 interval=1d comment="" disabled=no
```