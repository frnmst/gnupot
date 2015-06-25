GNUpot
======
Yet another libre Dropbox clone (only for the right aspects) written in bash. 

##Purpose of this project

Lots of us using Dropbox (or similar) like its functionalities. However 
these services have some defects:
- Your data could be anywhere in the world.
  - This means you don't have full control over your own files.
- Size limits
  - Usually of a few Gigabytes.
- Clients used to access these servces are usually proprietary.
- These programs are also heavy (in terms of disk, memory and processor usage).
- What are you going to do if those *owners* close the services?

The aim of this project is to have a completely free (as in freedom) 
replacement for Dropbox (and also similar services) that runs exclusively in 
our computers. All of this is done following the *K-I-S-S* (Keep It Simple, 
Stupid) principal.

###Why the name GNUpot

- **GNU** beause of the freedom associated to this program.
- **pot** because it gives the idea of some type of container.

##WARNING AND DISCLAMER

**THIS IS A WORK IN PROGESS. IT IS NOT YET READY FOR PRODUCTION USE.**

**AS THE LICENSE STATES, THIS PROGRAM COMES WITH ABSOLUTELY NO WARRANY. THE 
  DEVELOPER(S) CANNOT BE HELD RESPONSABLE OR LIABLE FOR ANY DATA LOSS OR OTHER
  DAMAGES CAUSED BY THE USE OF THIS SOFTWARE.**

##Ideas behind the project

- Simple.
  - Use of `bash` as scripting language makes the program overall very 
    integrated with a GNU/Linux system (as well as other UNIX-like systems).  
    Programming and manteinance should also be trivial this way.
  - No root privileges required.
  - Runs in background.
- When some kind of change is made, this is sent automatically to the server 
  (or to the client).
  - This is possible with `inotify` which looks for changes inside the watch 
    directories both on client and server.
- Encrypted and passord-less communication between client and server.
  - `ssh` is very suitable and malleable for this job.
- Minimal bandwidth usage.
  - If we are setting up a server at home it is unlikely to have fast upload 
    speed. We have to avoid to use all available upload (and even download 
    bandwidth) on server side (especially). ?This is achieved using `trickle`?
    **TODO**
- Desktop notifications.
  - When an event is originated (either on client or on server) user must be 
    notified. The command `notify-send` is perfect for this because of its 
    simplicity.
- Solid file and syncing agent.
  - `git` is designed for collaboration and has an excellent SSH support. 
- Automatic file conflict detection and resolution. **BASIC FUNCTIONALITY**
- Automatic backup to a maximum user defined number of backups.
- Easily shareable directories.
  - User and groups are managed by simple text files on the server. **TODO**
- No server-side program running.
  - Only programs like `inotify` and `git` needs to be installed on the 
    server.
- Very simple setup.
  - Stupid setup, using `dialog`, which initializes local and remote repositories.
    User configuration file is also written locally.
- Not (yet?) cross platform (intended as OS not architecture), but (nearly) 
  cross distro (see [below](#tests)).
  - It works both on system with a GUI as well as headless ones (servers, 
    embedded, etc...). In the second case notifications are (obviously) not 
    shown.

##Howto

###Setup

To install GNUpot you must download it first of all:
```shell
$ git clone https://github.com/frnmst/gnupot.git
$ cd gnupot
```

To download program updates (without cloning every time):
```shell
$ git pull origin master
```

Install **all** the [packages](#packages-to-install) described at the end of the readme.

There are various ways to proceed.

####The easy way (recommended)

On the server (as **root** user or with **sudo**):
  - add a new user (`gnupot` in the example) and set its password. I advise you 
    to select a strong password:
```
# useradd -m -G wheel -s /bin/bash gnupot
# passwd gnupot
```
On the server you should have `OpenSSH` up and running.
Add the following entry at the end of `/etc/ssh/sshd_config`. This will 
enable password authentication so that you can easily add new clients:
```
Match User gnupot
	PasswordAuthentication yes
```
Restart ssh daemon (if you don't have **Systemd** check your manuals):
```
# systemctl restart sshd
```
You should now be able to login in your server with your password:
```shell
$ ssh gnupot@<yourServerAddressOrHostname>
```

On the client:
  - run `./setup` and answer to *all* the questions.

####The difficult way

1. If you can't login to the server **or** you want to use a different user 
   instead of your usual one, go to [the first step](#the-easy-way-recommended).

2. copy `src/gnupot.config.example` to `~/.config/gnupot/gnupot.config` 
   and edit it to your needs.

3. Manually initialize a shared repository on the server and clone it on the 
   client.
 
##Start GNUpot

Once you have completed the previous points you can actually run the 
program manually:
```shell
$ ./gnupot
```
To stop it:
```shell
$ ./gnupot -k
```

###Autostart

If you have Openbox, you can put GNUpot in `~/.config/openbox/autostart` by 
adding the following lines:
```shell
# GNUpot
(setsid bash -c "sleep 10 && DISPLAY=:0 && ~/gnupot/gnupot") &
```
GNUpot will autostart 10 seconds after Openbox starts running in a separate 
environment, thanks to `setsid`. Without adding this you may encounter 
serious problems when killing GNUpot. Remember to set the display variable 
correctly, otherwise the notifications will not be shown.

##Interesting facts about GNUpot

- GNUpot is based on git so you can use the usual. For example 
  to see all the commit history you can use `git log`. To see the 
  differences from the last commit: `git show`.

##Packages to install

**All** the following packages must be installed in order to use GNUpot:

| Package name | Working version | Executable | Comment | Install on client | Install on Server |
|--------------|-----------------|------------|---------|-------------------|-------------------|
| `bash` | 4.3.033-1 | `bash` | | **YES** | **YES** |
| `openssh` | 6.8p1-2 | `ssh` | | **YES** | **YES** |
| `inotify-tools` | 3.14-4 | `inotifywait` | Tells the script that some changes have been made to a certain file. | **YES** | **YES** |
| `util-linux` | 2.26.1-3 | `flock` | Locks script and avoids contemporary local and remote sync. | **YES** | no |
| `libnotify` **or** `libnotify-bin` | 0.7.6-1 | `notify-send` | Sends notifications to notification server. If you are in a headless configuration (servers, embedded, etc...) you don't need this package. | **YES** | no |
| `git` | 2.4.1-1 | `git` | Program that syncs file and does versioning control. **It must be version >= 2.3 because of GIT_SSH_COMMAND variable which is absent in previous releases.** | **YES** | **YES** |
| `dialog` | 1:1.2_20150513-1 | `dialog` | Display user friendly dialog messages during the setup. | **YES** | no |
| `glibc` | 2.21-4 | `getent` | Get IP address from hostname. | **YES** | no |
| `iputils` | 20140519.fad11dc-1 | `ping` | ping IP address. | **YES** | no |
| | | | Be sure to have 1 and only 1 notify server installed. It should be already installed on your system. | **YES** | no |

Working versions >= than the ones written here should work without problems.

##Help

```
$ ./gnupot -h
GNUpot help

SYNOPSIS
        ./gnupot [ -h | -i | -l | -k | -p | -s ]

                -h      Help.
                -i      Start GNUpot.
                -l      Show GNUpot license.
                -k      Kill GNUpot.
                -p      Print configuration file.
                -s      Print status.

CONFIGURATION FILE
        Configuration file is found in ~/.config/gnupot/gnupot.config.

RETURN VALUES
        0       No error occurred.
        1       Some error occurred.

CONTACT
        Report bugs to: franco.masotti@live.com or franco.masotti@student.unife.it
        GNUpot home page: <https://github.com/frnmst/gnupot>

COPYRIGHT
        GNUpot  Copyright (C) 2015  frnmst (Franco Masotti)
        This program comes with ABSOLUTELY NO WARRANTY; for details type `./gnupot -l'.
        This is free software, and you are welcome to redistribute it 
        under certain conditions; type `./gnupot -l' for details.
```
  
##Tests

Successful tests on:
- [Parabola GNU/Linux-libre](https://www.parabola.nu/)
  - Client.
- [Arch Linux](https://www.archlinux.org/)
  - Server.
- [Manjaro Linux](https://manjaro.github.io/)
  - Client.

Still unsuccessful:
- Lubuntu 12.04. I have an HD with that system that i didn't use in a 
  while (some years). Unfortunately GNUpot's setup didn't even start. At this 
  moment however not all problems have been solved. These include:
  - ~~when quitting GNUpot `inotifywait` hangs untill another event occurs.~~ **SHOULD 
    BE SOLVED BUT IT'S UNTESTED.**
  - GNUpot doesen't recognize `SIGINT` for an unknown reason.

By isolating those problems you can safely run GNUpot on Lubuntu, and by time 
these problems should be solved.

Unknown:
- All other distros.

##Contact

franco.masotti@live.com or franco.masotti@student.unife.it

**ANY HELP IN CONTRIBUTING TO THIS PROJECT IS WARMLY WELCOMED.**
