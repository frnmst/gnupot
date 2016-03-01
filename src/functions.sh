#
# functions.sh
#
# Copyright (C) 2015, 2016 frnmst (Franco Masotti) <franco.masotti@live.com>
#                                            <franco.masotti@student.unife.it>
#
# This file is part of GNUpot.
#
# GNUpot is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNUpot is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNUpot.  If not, see <http://www.gnu.org/licenses/>.
#


# From the bash manual:
# The exit status of a function definition is zero unless a syntax error
# occurs  or  a readonly  function with the same name already exists.  When
# executed, the exit status of a function is the exit status  of  the
# last command executed in the body.

gitStatus() { git -C "$gnupotLocalDir" status -vu --long --ignored; }

gitGetCommitNumber() { git rev-list HEAD --count; }

gitSimpleStatus() { git status --porcelain | wc -m; }

gitGetCommitNumDiff() { git diff --name-only HEAD~1 HEAD | wc -l; }

gitChkExLocl() { git -C "$gnupotLocalDir" status -s 1>&- 2>&-; return "$?"; }

gitChkExRem() { git -C "$gnupotLocalDir" ls-remote --exit-code -h 1>&- 2>&-; }

gitGetLoclLastCommitSha() { git rev-list HEAD --max-count=1; }

gitGetRemLastCommitSha() { git ls-remote --heads  2>&- | awk ' { print $1 } '; }

gitRemoteSetHead() { git -C "$gnupotLocalDir" remote set head origin master \
1>&- 2>&-; }

gitRemoveCache() { git -C "$gnupotLocalDir" reflog expire --expire=now \
--all 1>&- 2>&-; git -C "$gnupotLocalDir" gc --prune=now --aggressive \
1>&- 2>&-; }

# User and exclude file settings.
assignGitInfo()
{
	cd "$gnupotLocalDir" && { { git config user.name \
"$gnupotGitCommitterUsername" && git config user.email \
"$gnupotGitCommitterEmail"; } \
&& printf "#Exclude files\n"$gnupotGitFileExclude"\n" > ".git/info/exclude" \
&& cd "$OLDPWD"; }
}

gitGetGnupotVersion() { git describe --long; }

gitGetGitVersion() { git --version | awk ' { print $3 } '; }

acquireLockFile() { printf 1 > "$gnupotLockFilePath"; }

freeLockFile() { printf 0 > "$gnupotLockFilePath"; }

busyWaitAcquireLockFile() { printf 2 > "$gnupotLockFilePath"; }

getLockFileVal() { cat "$gnupotLockFilePath"; }

Err() { local msg="$1"; printf "$msg" 1>&2; }

# General notification function.
notify()
{
	local msg="$1" ms="$2" action="$3"

    [ -z "$action" ] && iconPath=""$gnupotIconsDir"/gnupotIcon.png"

    if [ "$action" = "client" ]; then
iconPath=""$gnupotIconsDir"/gnupotSyncLocal.png"

    elif [ "$action" = "server" ]; then
iconPath=""$gnupotIconsDir"/gnupotSyncRemote.png"

    elif [ "$action" = "warning" ]; then
iconPath=""$gnupotIconsDir"/gnupotWarning.png"

    fi

	# If you are running GNUpot in a GUI then notify else do nothing.
	[ -n "$DISPLAY" ] && notify-send -i "$iconPath" \
-t "$ms" "GNUpot" "$msg" 1>&- 2>&-
}

printHelp()
{
	Err "\
Usage: gnupot [ OPTION ]\n\
A fully free, highly customizable and very efficient shell wrapper for\n\
git and SSH, which imitates Dropbox.\n\n\
Only none or one option is permitted.\n\
\t-d\tStart GNUpot in debug mode.\n\
\t-h\tHelp.\n\
\t-k\tKill GNUpot.\n\
\t-n\tNew GNUpot setup.\n\
\t-p\tPrint configuration file.\n\
\t-s\tPrint status.\n\
\t-v\tShow program version.\n\n\
If no option is given, GNUpot starts normally.\n\n\
Configuration file is found in ~/.config/gnupot/gnupot.config.\n\n\
Exit value:\n\
\t0\tno error occurred,\n\
\t1\tsome error occurred.\n\n\
Report bugs to: franco.masotti@student.unife.it or \
franco.masotti@live.com\n\
Full documentation at: <https://github.com/frnmst/gnupot/wiki>\n\
or available locally via: man man/gnupot.man\n\n\
GNUpot  Copyright © 2015, 2016  frnmst (Franco Masotti)\n\
This program comes with ABSOLUTELY NO WARRANTY; for details see \n\
'LICENSE' file or <https://www.gnu.org/licenses/gpl-3.0.en.html> \n\
This is free software, and you are welcome to redistribute it \n\
under certain conditions; see 'LICENSE' file or \n\
<https://www.gnu.org/licenses/gpl-3.0.en.html> for details.\n\
"
}

setUpdateableGloblVars()
{
	# Used for general ssh commands.
	SSHCONNECTCMDARGS="$SSHARGS "$gnupotServerUsername"@"$gnupotServer""
	# Open master socket so that further connection will result faster
	# (using multiplexing to avoid re-authentication).
	SSHMASTERSOCKCMDARGS="-M -o \
ControlPersist=yes $SSHCONNECTCMDARGS exit"
	# git environment variable for ssh.
	GIT_SSH_COMMAND="ssh $SSHARGS"
}

setGloblVars()
{
	# List of signals to be trapped.
	SIGNALS="SIGABRT SIGCHLD SIGHUP SIGINT SIGQUIT SIGTERM SIGTSTP"
	# List of installed programs that GNUpot uses. If display variable is
	# set notify-send is also required.
	PROGRAMS="bash ssh inotifywait flock git getent trickle"
	[ -n "$DISPLAY" ] && PROGRAMS="$PROGRAMS notify-send"
	# Subset of the commit message.
	USERDATA="by "$USER"@"$HOSTNAME"."
	# inotifywait args: recursive, quiet, listen only to certain events.
	INOTIFYWAITCMD="inotifywait -q -e modify -e attrib \
-e move -e move_self -e create -e delete --format %f"
	# SSH arguments.
	SSHARGS="\
-o PasswordAuthentication=no \
-p "$gnupotServerPort" \
-i "$gnupotSSHKeyPath" \
-C \
-S "$gnupotSSHMasterSocketPath" \
-o UserKnownHostsFile=/dev/null \
-o StrictHostKeyChecking=no \
-o ServerAliveInterval="$gnupotSSHServerAliveInterval" \
-o ServerAliveCountMax="$gnupotSSHServerAliveCountMax""
	setUpdateableGloblVars
}

parsingErrMsg()
{
	local variable="$1" msg="Config or parsing err. Variable "$variable". \
Setup: gnupot -n\n"

	Err "$msg"; notify "${msg%%\\n}" "10000"

	return 1
}

parseConfig()
{
        local variableList="ServerS ServerPortP ServerUsernameO RemoteDirO \
LocalDirO SSHKeyPathO RSAKeyBitsU KeepMaxCommitsU InotifyFileExcludeO \
GitFileExcludeO GitCommitterUsernameO GitCommitterEmailO \
TimeToWaitForOtherChangesU BusyWaitTimeU SSHServerAliveIntervalN \
SSHServerAliveCountMaxN SSHMasterSocketPathO NotificationTimeU LockFilePathO \
DownloadSpeedU UploadSpeedU IconsDirO"
	local variable="" type=""

	for variable in $variableList; do
		# Get var name and last char of variable to determine type.
		variable="gnupot"$variable""; type="${variable:(-1)}"
		# Get original variable name and reference variable.
		variable="${variable:0:(-1)}"; eval variable=\$"$variable"
		case "$type" in
			U ) # Unsigned integers only.
				case "$variable" in '' | *[!0-9]* )
					parsingErrMsg "$variable" ;; esac
			;;
			N ) # Natural numbers only.
				case "$variable" in '' | [!1-9]* | *[!0-9]* )
					parsingErrMsg "$variable" ;; esac
			;;
			P ) # Port numbers only.
				{ [ "$variable" == '' ] \
|| [ "$variable" -lt 1 ] || [ "$variable" -gt 65535 ]; } \
&& parsingErrMsg "$variable"
			;;
			S ) # Strings without space char.
				case "$variable" in '' | *[' ']* )
					parsingErrMsg "$variable" ;; esac
			;;
			* ) # All the other variables must be non-empty.
				case "$variable" in '' )
					parsingErrMsg "$variable" ;; esac
			;;
		esac
	done
}

# Find server address from hostname. If original variable is an IP
# address, then nothing changes. Doing this avoids making unecessary
# DNS server requests. It also works for IPv6 addresses.
getAddrByName()
{
	local hostErrMsg="Cannot resolve host name. Retrying.\n"

	[[ "$gnupotServerORIG" =~ [[:alpha:]] ]] \
&& [[ ! "$gnupotServerORIG" =~ ":" ]] \
&& gnupotServer=$(getent hosts "$gnupotServerORIG" | awk ' { print $1 } ') \
|| { [ -z "$gnupotServer" ] && Err "$hostErrMsg"; }

	return 0
}

loadConfig()
{
	local arg="$1"

	# Check when to setup a new GNUpot configuration. If that is the case
	# ignore loading and parsing configuration file as well as other
	# variables. Just set some global variables.
	if [ "$arg" != "-n" ]; then
		# "." is the same as "source" but it is more portable.
		[ -r "$CONFIGFILEPATH" ] && . "$CONFIGFILEPATH" 2>&- \
|| { parsingErrMsg; exit 1; }
		parseConfig || exit 1
		# Global variable.
		gnupotServerORIG="$gnupotServer"
		# If gnupot is started then find IP address from host name.
		[ -z "$arg" ] || [ "$arg" = "-i" ] && getAddrByName
	fi

	setGloblVars
}

# Kill program if local and/or remote directories do not exist.
DirErr()
{
	local errMsg="Local and/or remote directory does/do not \
exist, or no git repository."

	Err "$errMsg\n"
	notify "$errMsg" "$gnupotNotificationTime" "warning"
	kill -s SIGINT 0
}

# Check if remote directory exists.
chkSrvDirEx() { gitChkExRem || DirErr; }

# Check if local directory exists.
chkCliDirEx() { gitChkExLocl || DirErr; }

lockOnFile()
{
	local lockFile="$1" errMsg="GNUpot already running.\n"

	# Get a dynamic file descriptor.
	exec {FD}>>"$lockFile"
	flock -en "$FD" || { Err "$errMsg"; return 1; }
}

# The new address is only valid for the caller thread (i.e. Only the client
# thread OR the server thread is updated here). The update is done only when
# an SSH command fails.
updateDNSRecord() { { getAddrByName && setUpdateableGloblVars; }; }

busyWait()
{
	local tmp="$(getLockFileVal)"

	busyWaitAcquireLockFile
	notify "Connection or auth problem. Retrying in \
"$gnupotBusyWaitTime" seconds..." "$gnupotNotificationTime" "warning"
	sleep "$gnupotBusyWaitTime"
	updateDNSRecord
	# Restore previous state in lock file.
	printf "$tmp" > "$gnupotLockFilePath"
}

# If SSH socket exists delete it. Start a new socket anyway.
# Open a new master SSH socket after.
# Speeds of 0 = no limits.
crtSSHSock()
{
	local TRICKLECMD="trickle -s"

	rm -rf "$gnupotSSHMasterSocketPath"
	if [ "$gnupotDownloadSpeed" -eq 0 ] \
&& [ "$gnupotUploadSpeed" -eq 0 ]; then
		ssh $SSHMASTERSOCKCMDARGS 1>&- 2>&-
	else
		if [ "$gnupotDownloadSpeed" -eq 0 ]; then
			$TRICKLECMD -u "$gnupotDownloadSpeed" \
ssh $SSHMASTERSOCKCMDARGS 1>&- 2>&-
		elif [ "$gnupotUploadSpeed" -eq 0 ]; then
			$TRICKLECMD -d "$gnupotDownloadSpeed" \
ssh $SSHMASTERSOCKCMDARGS 1>&- 2>&-
		else
			$TRICKLECMD -d "$gnupotDownloadSpeed" \
-u "$gnupotUploadSpeed" ssh $SSHMASTERSOCKCMDARGS 1>&- 2>&-
		fi
	fi

	return "$?"
}

# Function that checks if connection to server is active.
# It tries to execute the input command.
# If it's not connected then it goes into busy waiting and tries it again
# after a certain period of time.
execSSHCmd()
{
	local SSHCommand="$1" retval="0"

	# Check if server is fully working and reachable.
	$SSHCommand 1>&- 2>&-
	retval="$?"
	# Before checking remote directory existence, be sure not to be in the
	# busy wait function. This happens when the computer is disconnected
	# and a file is modified locally. A value of 2 is used so that it's
	# distinguishable from 0 and 1. An event gets ignored if it passes the
	# first if but not the second.
	[ "$retval" -eq 1 ] && [ "$(getLockFileVal)" -ne 2 ] && chkSrvDirEx
	# Poll input command until it finishes correctly.
	while [ "$retval" -eq 255 ]; do
		busyWait
		# If command is not create master sock then recreate msock.
		[ "$SSHCommand" != "crtSSHSock" ] && crtSSHSock
		$SSHCommand 1>&- 2>&-
		retval="$?"
	done
}

# Resolve conflict function.
# THIS FUNCTION WORKS BUT IT'S VERY BASIC. CONFLICTING FILES ARE MERGED.
resolveConflicts()
{
	local returnedVal="$1" path="$2"

	[ "$returnedVal" -eq 1 ] \
&& { notify "Resolving file conflicts." "$gnupotNotificationTime" "warning"; \
git commit -a -m "Committed "$path" $USERDATA Handled conflicts"; }
}

gitSyncOperations()
{
	# Transform path with spaces in dashes to avoid problems.
	local path="$(echo "$1" | tr " " "-")" count=0 rebaseToDo=1

	# This loop is needed for "big" or lots of files.
	while [ "$(gitSimpleStatus)" -gt 0 ]; do
        rebaseToDo=0
		git add -A 1>&- 2>&-
		git commit -m "Committed "$path" $USERDATA" 1>&- 2>&-
		[ "$count" -gt 0 ] && sleep "$count"
		count=$(($count+1))
	done
	# Always pull from server first then check for conflicts using return
	# value. If there are new committed files, rebase is postponed till the
    # next time and a merge is done instead.
    [ "$rebaseToDo" -eq 1 ] && execSSHCmd "git pull --rebase origin master" \
|| execSSHCmd "git pull origin master"
	resolveConflicts "$?" "$path"
}

checkFileChanges()
{
	# If local and remote sha checksum is different then print
	# number; else print 0. If it's a first commit and it is syncing from
	# the server, it cannot go back with HEAD~1 because it would underflow.
	# unkown is used as a fake value instead. To get the real value another
	# connection to the server is required, so it's inefficient. The
	# command would be something like:
	# ssh ... "git -C ... status --porcelain | wc -l"
	# This has been avoided because it's required only once, under certain
	# circumstances.
	[ "$(gitGetRemLastCommitSha)" = "$(gitGetLoclLastCommitSha)" ] \
&& printf 0 \
|| { [ "$(gitGetCommitNumber)" -gt 1 ] && printf "$(gitGetCommitNumDiff)" \
|| printf "unknown"; }
}

# Clean useless files and keep maximum user defined number of backups.
# Do the syncing. To be able to clean: git config --system \
# receive.denyNonFastForwards true
backupAndPush()
{

    # if Max backups is set to 0 it means always to do a simple commit.
    # Otherwise use mod operator to find out when to truncate history (if
    # result is 0 it means that history must be truncated.
    if [ "$gnupotKeepMaxCommits" -ne 0 ] \
&& [ $(expr "$(gitGetCommitNumber)" % "$gnupotKeepMaxCommits") -eq 0 ]; then
        git reset $(git commit-tree HEAD^{tree} -m "Compressed history.")
        execSSHCmd "git push -f origin master"
        # Remove cache of non existing commits.
        gitRemoveCache
    else
        execSSHCmd "git push origin master"
    fi
}

# Main file syncronization function.
# This is executed inside a critical section.
syncOperation()
{
	local source="$1" path="$2"

	sleep "$gnupotTimeToWaitForOtherChanges"
	notify "Syncing $path from $source" "$gnupotNotificationTime" "$source"
	# Do all git operations in the correct directory before returning.
	# The compressed (list) vewrsion of this didn't work. It also made a
	# double, unexplicable call to gitSyncOperations
	cd "$gnupotLocalDir" || return 1
	if [ "$source" = "server" ]; then
		chgFilesNum="$(checkFileChanges)"; gitSyncOperations "$path";
		# The following doesn't work correctly when a merge occurs and
		# the same files have been modified both on client and on
		# server. In that case those files are counted twice. When
		# gnupot starts, local and remote modified file count must be
		# done.
		[ "$path" = "ALL FILES" ] \
&& chgFilesNum=$((chgFilesNum+$(checkFileChanges)))
	else
		gitSyncOperations "$path"; chgFilesNum="$(checkFileChanges)";
	fi
	backupAndPush && cd "$OLDPWD"
	notify "$path done. Changed "$chgFilesNum" file(s)." \
"$gnupotNotificationTime"
}

callSync()
{
	local source="$1" path="$2" lockValue="$3"

	# Check if the other thread is in the critical section.
	# This avoids a two way file update. Example: if a file is
	# modified on the client, it is sent immediately to the server.
	# However the server thead detects changes and so an unecessary
	# pull is made from the server.
	# So there are two types of locks: one between the round
	# brackets and the other one is made by the if clause.
	if [ "$lockValue" -eq 0 ]; then
		(	# Open a subshell for critical section.
			acquireLockFile
			# While not acquire lock:
			# while [ ! flock -n 1024 ]; do :; done is same as:
			flock -e "$FD"
			syncOperation "$source" "$path"
			# End critical section.
		# Get first valid file descriptor from a bash builtin.
		) {FD}>>"$gnupotLockFilePath"
		freeLockFile
	else
		# Wait some time to avoid unecessary loops. This happens if
		# there are lots of files to be transferred.
		sleep "$gnupotTimeToWaitForOtherChanges"
	fi
}

# Server sync thread.
syncS()
{
    # Force pseudo terminal allocation with -t -t swicthes.
	local pathCmd="ssh -t -t $SSHCONNECTCMDARGS \
$INOTIFYWAITCMD ""$gnupotRemoteDir"/refs/heads/master""

	# return/exit when signal{,s} is/are received.
	trap "exit 0" $SIGNALS

	# Open/create master SSH socket.
	execSSHCmd crtSSHSock
	# Check remote dir existence.
	execSSHCmd chkSrvDirEx

	# First of all, pull or push changes while gnupot was not running.
	# Use client as param instead of server to avoid problems.
	callSync "server" "ALL FILES" "$(getLockFileVal)"

	while true; do
		# Listen for changes on server.
		execSSHCmd "$pathCmd"
		# The value of the lock sometimes changes, causing
		# a useless double sync. This way the value is saved before the
		# function call so it can be safely passed to the callSync
		# function. This has been done for the client thread also, for
		# precaution, even if it's not strictly necessary.
		callSync "server" "remote" "$(getLockFileVal)"
	done
}

# Client sync thread.
syncC()
{
	local path="" lockVal=""

	trap "exit 0" $SIGNALS

	chkCliDirEx

	# Assign git repo configuration after checking local dir existence.
	assignGitInfo

	while true; do
		path=$($INOTIFYWAITCMD -r --exclude $gnupotInotifyFileExclude \
"$gnupotLocalDir" || chkCliDirEx)
		callSync "client" "$path" "$(getLockFileVal)"
	done
}

printStatus()
{
	local running="0" diskUsage=""

	Err "GNUpot status: "
	[ "$(pgrep -c gnupot)" -ge "$procNum" ] && running="1" || Err "NOT "
	Err "running "
	[ "$running" -eq 1 ] && Err "with PID: $(pgrep -o gnupot)"
	Err "\n\n"
	Err "$(gitStatus)\n\n"
	diskUsage="$(du -k -d0 "$gnupotLocalDir")"
	Err "Directory disk usage: $(printf "$diskUsage" \
| awk ' { print $1 }') KB\n"
}

checkGitVersion()
{
	# trash is a garbage variable.
	local gitVer0="" gitVer1="" trash=""

	# Check if git supports GIT_SSH_COMMAND environment variaible.
	# In order for gnupot to work, git must be at least version 2.4.
	IFS="." read gitVer0 gitVer1 trash <<< "$(gitGetGitVersion)"
	[ "$gitVer0$gitVer1" -gt 23 ] || return 1
}

# Check if all necessary programs are installed.
checkExecutables()
{
	# Redirect which stderr and stdout to /dev/null (see bash
	# redirection) otherwise which returns error..
	checkGitVersion && which $PROGRAMS 1>/dev/null 2>/dev/null \
|| { Err "Missing programs or unsupported. Check: $PROGRAMS. \
Also check package versions.\n"; exit 1; }
}

# Signal handler function.
# Send a signal to all the other threads so that they exit.
sigHandler() { Err "GNUpot killed\n"; kill -s SIGINT 0; }

# Function that makes a fake commit so that inotifywait process on the client
# is killed (if inotify-tools version in old.
lastFakeCommit()
{
	# Test if inotifywait version needs to detect local changes at exit
	# (version less than 3.14).
	[ $(inotifywait --help | head -n1 | awk ' { print $2 } ' | tr -d '.') \
-lt 314 ] \
&& : > ""$gnupotLocalDir"/lastCommit" 1>&- 2>&- \
&& rm ""$gnupotLocalDir"/lastCommit" 1>&- 2>&-
}

# Function that calls client and server threads as well as removing the SSH
# socket.
callThreads()
{
	local srvPid="" cliPid=""

	# Remove git lock (if exists).
	rm -rf ""$gnupotLocalDir"/.git/refs/heads/master.lock"
	# Set default remote head
	gitRemoteSetHead
	# Listen from server and send to client.
	syncS & srvPid="$!"
	# Listen from client and send to server.
	syncC & cliPid="$!"
	# Lowest process priority for the threads.
	renice 20 "$srvPid" "$cliPid" 1>&- 2>&-
	# Wait for the two threads before continuing.
	wait "$srvPid" "$cliPid"
	# Make the final fake commit (used for systems with old versions of
	# inotify-tools).
	lastFakeCommit
	# Kill master ssh socket (this will kill any ssh connection associated
	# with it).
	ssh -O exit -S "$gnupotSSHMasterSocketPath" "$gnupotServer" 1>&- 2>&-
	# Remove shared socket before exiting. Not doing this means having a
	# security breach because the socket remains opened and anyone could
	# use it.
	rm -rf "$gnupotSSHMasterSocketPath"
}

# Main function that runs in background.
main()
{
	# Enable signal interpretation to kill all subshells
	trap "sigHandler" $SIGNALS

	notify "Starting..." "$gnupotNotificationTime"
	freeLockFile
	callThreads
	notify "Stopped." "$gnupotNotificationTime"

	exit 0
}

# Check if another istance of GNUpot is running. If that is the case exit with
# error message. The following set makes the script faster because the lock is
# checked before the function call. main function is called as a spawned shell.
# This is done so that even if the current shell is killed, GNUpot is not
# killed.
callMain() { lockOnFile "$CONFIGFILEPATH" && { main & : ; } || exit 1; }

printVersion() { Err "GNUpot version "; gitGetGnupotVersion; }

parseOpts()
{
	local prgPath="$1" argArray="$2"

	# Get options from special variable $@. Treat no arguments as -i.
	getopts ":dhknpsv" opt "$argArray"
	case "$opt" in
		d ) set -x; callMain ;;
		h ) printHelp; return 1 ;;
		k ) Err "Killing GNUpot...\n" && killall -s SIGINT -q gnupot ;;
		n ) ""${prgPath%/gnupot}"/src/config.sh" ;;
		p ) cat "$CONFIGFILEPATH" ;;
		s ) printStatus ;;
		v ) printVersion ;;
		? ) [ -z "$argArray" ] && callMain \
|| { printHelp "$prgPath"; return 1; } ;;
	esac
}
