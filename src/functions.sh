#
# functions.sh
#
# Copyright (C) 2015 frnmst (Franco Masotti) <franco.masotti@live.com>
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


Err() { local msg="$1"; printf "$msg" >&2; return 0; }

printHelp()
{
	local prgPath="$1"

	Err "\
GNUpot help\n\n\
SYNOPSIS\n\
\t"$prgPath" [ -h | -i | -l | -k | -p | -s ]\n\n\
\t\t-h\tHelp.\n\
\t\t-i\tStart GNUpot.\n\
\t\t-l\tShow GNUpot license.\n\
\t\t-k\tKill GNUpot.\n\
\t\t-p\tPrint configuration file.\n\
\t\t-s\tPrint status.\n\n\
CONFIGURATION FILE\n\
\tConfiguration file is found in ~/.config/gnupot/gnupot.config.\n\n\
RETURN VALUES\n\
\t0\tNo error occurred.\n\
\t1\tSome error occurred.\n\n\
CONTACT\n\
\tReport bugs to: franco.masotti@live.com or \
franco.masotti@student.unife.it\n\
\tGNUpot home page: <https://github.com/frnmst/gnupot>\n\n\
COPYRIGHT\n\
\tGNUpot  Copyright (C) 2015  frnmst (Franco Masotti)\n\
\tThis program comes with ABSOLUTELY NO WARRANTY; for details type \
\`"$prgPath" -l'.\n\
\tThis is free software, and you are welcome to redistribute it \n\
\tunder certain conditions; type \`"$prgPath" -l' for details.\n\
"

	return 0
}

setUpdateableGloblVars()
{
	# Used for general ssh commands.
	SSHCONNECTCMDARGS="$SSHARGS "$gnupotServerUsername"@"$gnupotServer""
	# Open master socket so that further connection will result faster
	# (using multiplexing to avoid re-authentication).
	SSHMASTERSOCKCMDARGS="-M -o \
ControlPersist="$gnupotSSHMasterSocketTime" $SSHCONNECTCMDARGS exit"
	# git environment variable for ssh.
	GIT_SSH_COMMAND="ssh $SSHARGS"

	return 0
}

setGloblVars()
{
	gnupotSSHMasterSocketTime=""$gnupotSSHMasterSocketTime"m"
	# List of signals to be trapped.
	SIGNALS="SIGABRT SIGCHLD SIGHUP SIGINT SIGQUIT SIGTERM SIGTSTP"
	# List of installed programs that GNUpot uses. If display variable is
	# set notify-send is also required.
	PROGRAMS="bash ssh inotifywait flock git getent ping"
	[ -n "$DISPLAY" ] && PROGRAMS="$PROGRAMS notify-send"
	USERDATA="by "$USER"@"$HOSTNAME"."
	# inotifywait args: recursive, quiet, listen only to certain events.
	INOTIFYWAITCMD="inotifywait -r -q -e modify -e attrib \
-e move -e move_self -e create -e delete -e delete_self --format %f"
	# SSH arguments.
	SSHARGS="-o PasswordAuthentication=no -i "$gnupotSSHKeyPath" -C -S \
"$gnupotSSHMasterSocketPath" -o UserKnownHostsFile=/dev/null \
-o StrictHostKeyChecking=no"
	setUpdateableGloblVars

	return 0
}

parsingErrMsg() { Err "Configuration or parsing problem.\n"; return 0; }

parseConfig()
{
        local variableList="ServerS ServerUsernameO RemoteDirO LocalDirO \
SSHKeyPathO KeepMaxCommitsN LocalHomeO RemoteHomeO GitCommitterUsernameO \
GitCommitterEmailO TimeToWaitForOtherChangesN BusyWaitTimeN \
SSHMasterSocketPathO SSHMasterSocketTimeN NotificationTimeN \
LockFilePathO" variable="" type=""

	for variable in $variableList; do
		# Get var name and last char of variable to determine type.
		variable="gnupot"$variable""; type="${variable:(-1)}"
		# Get original variable name and reference variable.
		variable="${variable:0:(-1)}"; eval variable=\$"$variable"
		case "$type" in
			N ) # Numbers only.
				case "$variable" in '' | *[!0-9]* )
					parsingErrMsg; return 1 ;; esac
			;;
			S ) # Strings without space char.
				case "$variable" in '' | *[' ']* )
					parsingErrMsg; return 1 ;; esac
			;;
			* ) # All the other variables must be non-empty.
				case "$variable" in '' )
					parsingErrMsg; return 1 ;; esac
			;;
		esac
	done

	return 0
}

# Find server address from hostname. If original variable is an IP
# address, then nothing changes. Doing this avoids making unecessary
# DNS server requests. It works for IPv6 addresses also.
getAddrByName()
{
	local hostErrMsg="Cannot resolve host name.\n"

	[[ "$gnupotServerORIG" =~ [[:alpha:]] ]] \
&& [[ ! "$gnupotServerORIG" =~ ":" ]] \
&& gnupotServer=$(getent hosts "$gnupotServerORIG" | awk ' { print $1 } ') \
&& [ -z "$gnupotServer" ] && { Err "$hostErrMsg"; return 1; }

	return 0
}

loadConfig()
{
	local arg="$1"

	# "." is the same as "source" but it is more portable.
	[ -f "$CONFIGFILEPATH" ] && . "$CONFIGFILEPATH" 2>&- \
|| { parsingErrMsg; exit 1; }

	parseConfig || exit 1

	# Global variable.
	gnupotServerORIG="$gnupotServer"
	# If gnupot is started then find IP address from host name.
	[ -z "$arg" ] || [ "$arg" = "-i" ] && { getAddrByName || exit 1; }

	setGloblVars

	return 0
}

# Modified version of flock's boilterplate. This version is able to run also
# on older versions of flock. See man 1 flock (examples section).
lockOnFile()
{
	local prgPath="$1" argArray="$2" errMsg="GNUpot is already \
running.\n"

	# Lock on configuration file path istead of this file (gnupot.sh).
	[ "${FLOCKER}" != "$prgPath" ] && { FLOCKER="$prgPath" flock -en \
"$CONFIGFILEPATH" "$prgPath" "$argArray" || Err "$errMsg"; \
return 1; } || return 0
}

# General notification function.
notify()
{
	local msg="$1" ms="$2"

	# If you are running GNUpot in a GUI then notify else do nothing.
	[ -n "$DISPLAY" ] && notify-send -t "$ms" "$msg"; return 0
}

syncNotify()
{
	local path="$1" source="$2"

	notify "GNUpot syncing $path from $source" "$gnupotNotificationTime"

	return 0
}

# The new address is only valid for the thread caller, i.e. Only the client
# thread OR the server thread is updated here. The update is done only when SSH
# commands fail.
updateDNSRecord() { { getAddrByName && setUpdateableGloblVars; }; return 0; }

busyWait()
{
	notify "GNUpot connection or auth problem. Retrying..." \
"$gnupotNotificationTime"
	updateDNSRecord
	sleep "$gnupotBusyWaitTime"

	return 0
}

# Function that checks if connection to server is active.
# It tries to execute the input command.
# If it's not connected then it goes into busy waiting and tries it again
# after a certain period of time.
execSSHCmd()
{
	local SSHCommand="$1"

	# Check if remote server is reachable.
	while [ $(ping -c 1 -s 0 -W 30 "$gnupotServer" 1>&- 2>&-; \
printf "$?") -ne 0 ]; do
		busyWait
	done

	# Poll input command until it finishes correctly.
	$SSHCommand 1>&- 2>&-
	while [ "$?" -eq 255 ]; do
		busyWait
		# If command is not create msock then recreate msock.
		[ "$SSHCommand" != "crtSSHSock" ] && crtSSHSock 1>&- 2>&-
		$SSHCommand 1>&- 2>&-
	done

	return 0
}

getCommitNumber() { printf "$(git rev-list HEAD --count)"; return 0; }

# Resolve conflict function.
# THIS FUNCTION WORKS BUT IT'S VERY BASIC. CONFLICTING FILES ARE MERGED.
resolveConflicts()
{
	local returnedVal="$1"

	[ "$returnedVal" -eq 1 ] \
&& { notify "Resolving file conflicts." "$gnupotNotificationTime"; \
git commit -a -m "Commit on $(date "+%F %T") $USERDATA \
Handled conflicts"; }

	return 0
}

# Clean useless files and keep maximum user defined number of backups.
backupAndClean()
{
	local commitSha=""

	# if Max backups is set to 0 it means always to do a simple commit.
	# Otherwise use mod operator to find out when to truncate history (if
	# result is 0 it means that history must be truncated.
	if [ "$gnupotKeepMaxCommits" -ne 0 ] \
&& [ $(expr "$(getCommitNumber)" % "$gnupotKeepMaxCommits") -eq 0 ]; then
		# Get sha of interest.
		commitSha=$(git rev-list --max-count="$gnupotKeepMaxCommits" \
HEAD | tail -n 1)
		# From man git-checkout:
		# Create a new orphan branch, named <new_branch>, started from
		# <start_point> and switch to it.
		git checkout --orphan tmp "$commitSha" 1>&- 2>&-
		# Change old commit.
		git commit -m "Truncated history on \
$(date "+%F %T") $USERDATA" 1>&- 2>&-
		# From man git-rebase
		# Forward-port local commits to the updated upstream head.
		git rebase --onto tmp "$commitSha" master 1>&- 2>&-
		# Delete tmp branch.
		git branch -D tmp 1>&- 2>&-
		# Garbage collector for stuff older than 1d.
		# TODO better.
		git gc --auto --prune=1d 1>&- 2>&-
		# ?git rebase --continue #??
		execSSHCmd "git push -f origin master"
	else
		execSSHCmd "git push origin master"
	fi

	return 0
}

gitSyncOperations()
{
	git add -A 1>&- 2>&-
	git commit -m "Commit on $(date "+%F %T") \
$USERDATA" 1>&- 2>&-
	# Always pull from server first then check for conflicts using return
	# value.
	execSSHCmd "git pull origin master"
	resolveConflicts "$?"

	return 0
}

# Main file syncronization function.
# This is executed inside a critical section.
syncOperation()
{
	local source="$1" path="$2"

	sleep "$gnupotTimeToWaitForOtherChanges"

	syncNotify "$path" "$source"

	# Do all git operations in the correct directory.
	cd "$gnupotLocalDir"
	# Do the syncing. To be able to clean: git config --system \
	# receive.denyNonFastForwards true
	gitSyncOperations; backupAndClean
	# Go back to previous dir.
	cd "$OLDPWD"

	notify "GNUpot $path done." "$gnupotNotificationTime"

	return 0
}

# Kill program if local and/or remote directories do not exist.
DirErr()
{
	local errMsg="Local and/or remote directory does/do not \
exist, or no git repository."

	Err "$errMsg\n"
	notify "$errMsg" "$gnupotNotificationTime"
	kill -s SIGINT 0

	return 0
}

# Check if remote directory exists.
chkSrvDirEx()
{
	ssh $SSHCONNECTCMDARGS "cd $gnupotRemoteDir 2>&- && git show \
1>&- 2>&- || exit 1" || DirErr

return 0
}

# Check if local directory exists.
chkCliDirEx()
{
	cd "$gnupotLocalDir" 2>&- && { git status -s 1>&- 2>&- || DirErr; } \
|| DirErr; cd "$OLDPWD"

	return 0
}

acquireLockFile() { printf 1 > "$gnupotLockFilePath"; return 0; }

freeLockFile() { printf 0 > "$gnupotLockFilePath"; return 0; }

callSync()
{
	local source="$1" path="$2"

	# Check if the other thread is in the critical section.
	# This avoids a two way file update. Example: if a file is
	# modified on the client, it is sent immediately to the server.
	# However the server thead detects changes and so an unecessary
	# pull is made from the server.
	# So there are two types of locks: one between the round
	# brackets and the other one is made by the if clause.
	if [ $(cat "$gnupotLockFilePath") -eq 0 ]; then
		(	# Open a subshell for critical section.
			acquireLockFile
			# While not acquire lock:
			# while [ ! flock -n 1024 ]; do :; done is same as:
			flock -x "$FD"
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

	return 0
}

# If SSH socket exists delete it. Start a new socket anyway.
# Open a new master SSH socket after.
crtSSHSock()
{
	rm -rf "$gnupotSSHMasterSocketPath"
	ssh $SSHMASTERSOCKCMDARGS

	return "$?"
}

# Server sync thread.
syncS()
{
	local pathCmd="ssh $SSHCONNECTCMDARGS \
$INOTIFYWAITCMD "$gnupotRemoteDir""

	# return/exit when signal{,s} is/are received.
	trap "exit 0" $SIGNALS

	# Open/create master SSH socket.
	execSSHCmd crtSSHSock

	execSSHCmd chkSrvDirEx

	# First of all, pull or push changes while gnupot was not running.
	callSync "server" "<ALL FILES>"

	while true; do
		# Listen for changes on server.
		execSSHCmd "$pathCmd"
		callSync "server" ""
	done
}

# Client sync thread.
syncC()
{
	local path=""

	trap "exit 0" $SIGNALS

	chkCliDirEx

	while true; do
		path=$($INOTIFYWAITCMD --exclude .git "$gnupotLocalDir")
		callSync "client" "$path"
	done
}

assignGitInfo()
{
	cd "$gnupotLocalDir" && { { git config user.name \
"$gnupotGitCommitterUsername" && git config user.email \
"$gnupotGitCommitterEmail"; }; cd "$OLDPWD"; }

	return 0
}

printStatus()
{
	Err "GNUpot is "
	[ "$(pgrep -c gnupot)" -lt "$procNum" ] && Err "NOT "
	Err "running correctly.\n"

	return 0
}

checkGitVersion()
{
	# trash is a garbage variable.
	local gitVer="" gitVer0="" gitVer1="" trash=""

	# Check if git supports GIT_SSH_COMMAND environment variaible.
	gitVer="$(git --version | awk ' { print $3 } ')"
	IFS="." read gitVer0 gitVer1 trash <<< "$gitVer"
	[ "$gitVer0$gitVer1" -le 23 ] && return 1

	return 0
}

# Check if all necessary programs are installed.
checkExecutables()
{
	# Redirect which stderr and stdout to /dev/null (see bash
	# redirection).
	checkGitVersion && which $PROGRAMS 1>/dev/null 2>/dev/null
	[ "$?" -ne 0 ] && { Err "Missing programs or unsupported. \
Check: $PROGRAMS. Also check package versions.\n"; exit 1; }

	return 0
}

# Signal handler function.
sigHandler()
{
	Err "GNUpot killed\n"
	# Kill master ssh socket (this will kill any ssh connection associated
	# with it). Also disable stderr output for this command with "2>&-".
	ssh -O exit -S "$gnupotSSHMasterSocketPath" "$gnupotServer" 2>&- &
	kill -s SIGINT 0

	return 0
}

callThreads()
{
	local srvPid="" cliPid=""

	# Listen from server and send to client.
	syncS & srvPid="$!"
	# Listen from client and send to server.
	syncC & cliPid="$!"
	# Lowest process priority for the threads.
	renice 20 "$srvPid" "$cliPid" 1>&- 2>&-
	wait "$srvPid" "$cliPid"

	return 0
}

# Main function that runs in background.
main()
{
	# Enable signal interpretation to kill all subshells
	trap "sigHandler" $SIGNALS

	notify "GNUpot starting..." "$gnupotNotificationTime"

	freeLockFile
	# Assign git repo configuration.
	assignGitInfo
	# Call threads and wait for them to exit before continuing.
	callThreads

	notify "GNUpot stopped." "$gnupotNotificationTime"

	exit 0
}

# Check if another istance of GNUpot is running. If that is the case exit with
# error message.
callMain()
{
	local prgPath="$1" argArray="$2"

	# The following set makes the script faster.
	lockOnFile "$prgPath" "$argArray"
	[ "$?" -eq 0 ] && { set +m; main & set -m; } || exit 1

	return 0
}

parseOpts()
{
	local prgPath="$1" argArray="$2"

	# Get options from special variable $@. Treat no arguments as -i.
	getopts ":hilkps" opt "$argArray"
	case "$opt" in
		h ) printHelp "$prgPath"; return 1 ;;
		# Call main function as spawned shell (execute and return
	 	# control to the shell).
		i ) callMain "$prgPath" "$argArray" & ;;
		l ) less "LICENSE" ;;
		k ) killall -s SIGINT -q gnupot ;;
		p ) cat ""$HOME"/.config/gnupot/gnupot.config" ;;
		s ) printStatus ;;
		? ) [ -z "$argArray" ] && callMain "$prgPath" "$argArray" \
|| { printHelp "$prgPath"; return 1; } ;;
	esac

	return 0
}
