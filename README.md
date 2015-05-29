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
- These program are also heavy (in terms of disk,  memory and processor usage).
- What are you going to do if those *owners* close the services?

The aim of this project is to have a completely free (as in freedom) 
replacement for Dropbox (and also similar services) that runs exclusively in 
our computers. All of this is done following the *K-I-S-S* (Keep It Simple, 
Stupid) principal.

###Why the name GNUpot

- **GNU** beause of the freedom associated to this program.
- **pot** because it gives the idea of some type of container.

##Ideas behind the project

- Simple.
  - Use of `bash` as scripting language makes the program overall very 
    integrated with a GNU/Linux system (as well as other UNIX-like systems). 
  - Programming and manteinance should also be trivial this way.
- When some kind of change is made, this is sent automatically to the server 
  (or to the client).
  - This is possible with `inotify` which looks for changes inside the watch 
    directories both on client and server.
- Encrypted and passord-less communication between client and server.
  - `ssh` is very suitable and malleable for this job. **WORK IN PROGRESS**
- Minimal bandwidth usage.
  - If we are setting up a server at home it is unlikely to have fast upload 
    speed. We have to avoid to use all available upload (and even download 
    bandwidth) on server side (especially). ?This is achieved using `trickle`?
    **TODO**
- Desktop notifications.
  - When an event is originated (either on client or on server) user must be 
    notified. The command `notify-send` is perfect for this because of its 
    simplicity.
- Solid syncing agent.
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
    User configuration is also written. **BASIC FUNCTIONALITY**

###WARNING

**THIS IS A WORK IN PROGESS. DON'T EXPECT THAT IT WORKS OUT OF THE BOX.**

##Howto

```
$ git clone https://github.com/frnmst/gnupot.git
$ cd gnupot
```
You have **two possibilities** for the setup of GNUpot:
- run the setup: `./setup`
- **OR** copy `srv/gnupot.config.example` to `~/.config/gnupot/gnupot.config` 
  and edit it to your needs. Manually initialize a shared repository on the 
  server and clone it on the client.

After that you must:
- be sure to have an SSH server up and running.
- be able to connect to that server with private/public keys (these must be
  passwordless).
- install the packages described below.

Once you have completed **all** the previous points you can actually run the 
program:
```
$ ./gnupot
```

###Packages to install (dependencies)

- bash 4.3.033-1
  - Server and client.
- openssh 6.8p1-2
  - Server and client.
- inotify-tools 3.14-4 (inotifywait) [Tells the script that some changes have 
  been made to a certain file.]
  - Server and client.
- util-linux 2.26.1-3 (flock) [Locks script and avoids contemporary local and
  remote sync.]
  - Client only.
- libnotify 0.7.6-1 (notify-send) [Sends notifications to notification server.]
  - Client only.
- #Be sure to have 1 and only 1 notify server installed. It should be already 
  installed on your system.
  #dunst () [Lightweight notification server; it displays notifications.]
  - Client only.
- git 2.4.1-1 (git) [Program that syncs file and does versioning control.]
  - Server and client.
- ?trickle?
- dialog 1:1.2_20150513-1 (dialog) [Display user friendly dialog messages 
  during the setup.]

##Help

**TODO**
```
./gnupot -h
```
  
##Tests

Tested on [Parabola GNU/Linux-libre](https://www.parabola.nu/), [Arch 
Linux](https://www.archlinux.org/) and [Manjaro 
Linux](https://manjaro.github.io/).

**ANY HELP IN CONTRIBUTING TO THIS PROJECT IS WARMLY WELCOMED.**

##Contact

franco.masotti@live.com or franco.masotti@student.unife.it
