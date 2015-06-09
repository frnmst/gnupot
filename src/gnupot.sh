#!/bin/bash

#
# gnupot.sh
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


# Enable automatic export of all variables form now on.
# This avoids putting "export" in front of every variable.
set -a

# Set path.
PATH="$PATH":/usr/bin

# Macros. Some of these are declared here (but empty) just to have global
# scope.
CONFIGFILEPATH=""$HOME"/.config/gnupot/gnupot.config"
# List of trapped signals.
SIGNALS="SIGABRT SIGCHLD SIGHUP SIGINT SIGQUIT SIGTERM SIGTSTP"
# List of installed programs that GNUpot uses.
PROGRAMS="bash ssh inotifywait flock notify-send git"
USERDATA="by "$USER"@"$HOSTNAME"."
SSHARGS=""
SSHCONNECTCMDARGS=""
SSHMASTERSOCKCMDARGS=""
# inotifywait command macro: recursive, quiet, listen only to certain events.
INOTIFYWAITCMD="inotifywait -r -q -e modify -e attrib \
-e move -e move_self -e create -e delete -e delete_self"
GITCMD="git"
GIT_SSH_COMMAND=""


function setGloblVars
{

	# SSH arguments.
	SSHARGS="-o PasswordAuthentication=no -i "$gnupotSSHKeyPath" -C -S \
"$gnupotSSHMasterSocketPath""

	# Used for general ssh commands
	SSHCONNECTCMDARGS="$SSHARGS "$gnupotServerUsername"@"$gnupotServer""

	# Open master socket so that further connection will result faster
	# (using multiplexing to avoid re-authentication).
	SSHMASTERSOCKCMDARGS="-M -o \
	ControlPersist="$gnupotSSHMasterSocketTime" \
$SSHCONNECTCMDARGS exit"

	# git environment variable for ssh.
	GIT_SSH_COMMAND="ssh $SSHARGS"

	return 0

}

function loadConfig
{

	errMsg="Cannot read configuration file."


	if [ -f "$CONFIGFILEPATH" ]; then
		source "$CONFIGFILEPATH" 2>&-
		if [ "$?" -ne 0 ]; then echo $errMsg 1>&2; exit 1; fi
	else
		echo $errMsg 1>&2; exit 1
	fi

	# Parsing here TODO.

	setGloblVars

	return 0

}

# Modified version of flock's boilterplate. This version is able to run also
# on older versions of flock. See man 1 flock (examples section).
function lockOnFile
{

	prgPath="$1"
	argArray="$2"


	# Lock on configuration file path istead of this file (gnupot.sh).
	[ "${FLOCKER}" != "$prgPath" ] && exec env FLOCKER="$prgPath" \
flock -en "$CONFIGFILEPATH" "$prgPath" "$argArray" || :

	return 0

}

function busyWait
{

	notifyCmd "GNUpot is waiting for available connection." \
"$gnupotDefaultNotificationTime"

	# Do something useful here. TODO.

	sleep 5

	return 0

}

# Function that checks if connection to server is active.
# It tries to execute the input command.
# If it's not connected then it goes into busy waiting and tries it again
# after a period of time.
function execSSHCmd
{

	SSHCommand="$1"

#	echo in0

	while [ $($SSHCommand 2>&-; echo "$?") -eq 255 ]; do
#		echo in1
		busyWait
	done

	return 0
}

# General notification function.
function notifyCmd
{

	msg="$1"
	ms="$2"


	notify-send -t "$ms" "$msg"

	return 0

}

function syncNotify
{

	path="$1"
	dir="$2"
	source="$3"


	notifyCmd "GNUpot syncing $(getRelativePath "$path" \
"$dir") from "$source"" "$gnupotDefaultNotificationTime"

	return 0

}

# Get relative path for local or remote changed files.
function getRelativePath
{

	fullPath="$1"
	srcDir="$2"
	tmp=""


	# Get relative path of file.
	tmp="${fullPath##"$srcDir"}"
	# Remove heading slash and return value.
	echo "${tmp:1}"

	return 0

}

# Resolve conflict function.
# WARING: AT THIS MOMENT THIS FUNCTION WORKS BUT IT'S VERY BASIC.
# CONFLICTING FILES ARE MERGED.
function resolveConflicts
{

	returnedVal="$1"


	if [ "$returnedVal" -eq 1 ]; then
		notifyCmd "Resolving file conflicts." \
"$gnupotDefaultNotificationTime"
		$GITCMD commit -a -m "Commit on $(date "+%s") $USERDATA \
Handled conflicts"
	fi

	return 0

}

# Clean useless files and keep maximum user defined number of backups.
function backupAndClean
{

	currentCommits="$1"
	commitSha=""


	# if <number of commits for current session> mod $KeepMaxBackups -eq 0
	# and $KeepMaxBackups.
	if [ $(expr "$currentCommits" % "$gnupotKeepMaxCommits") \
-eq 0 ] && [ "$gnupotKeepMaxCommits" -ne 0 ]; then
		# Get sha of interest.
		commitSha=$($GITCMD log -n "$gnupotKeepMaxCommits" \
| tail -n 6 | grep commit | awk ' { print $2 } ')
		# From man git-checkout:
		# Create a new orphan branch, named <new_branch>, started from
		# <start_point> and switch to it.
		$GITCMD checkout --orphan tmp "$commitSha"
		# Change old commit.
		$GITCMD commit -m "Truncated history on $(date "+%s") \
$USERDATA"
		# From man git-rebase
		# Forward-port local commits to the updated upstream head.
		$GITCMD rebase --onto tmp "$commitSha" master
		# Delete tmp branch.
		$GITCMD branch -D tmp
		# Garbage collector for stuff older than 1d.
		# TODO better.
		$GITCMD gc --auto --prune=1d

		$GITCMD push -f origin master
	else
		$GITCMD push origin master
	fi

	return 0

}

function getCommitNumber
{

	if [ ! -f "$gnupotCommitNumberFilePath" ]; then
		echo 1 > "$gnupotCommitNumberFilePath"; echo 1
	else
		cat "$gnupotCommitNumberFilePath"
	fi

	return 0

}

function gitSyncOperations
{

	$GITCMD add -A
	$GITCMD commit -a -m "Commit on $(date "+%s") $USERDATA"
	# Always pull from server first then check for conflicts using return
	# value.
	$GITCMD pull origin master
	resolveConflicts "$?"

	return 0

}

# Both client and server threads execute this function.
function sharedSyncActions
{

	# Do all git operations in the correct directory.
	cd "$gnupotLocalDir"

	gitSyncOperations

	currentCommits=$(getCommitNumber)
	# To be able to use this: git config --system \
	# receive.denyNonFastForwards true
	backupAndClean "$currentCommits"
	# Update commit number.
	echo $(($currentCommits+1)) > "$gnupotCommitNumberFilePath"

	# Go back to previous dir.
	cd "$OLDPWD"

	return 0

}

# Main file syncronization function.
# This is executed inside a critical section.
function syncOperation
{

	source="$1"
	path="$2"
	rootDir=""


	sleep "$gnupotTimeToWaitForOtherChanges"

	if [ "$source" == "server" ]; then rootDir="$gnupotRemoteDir"; else \
rootDir="$gnupotLocalDir"; fi
	syncNotify "$path" "$rootDir" "$source"

	# Do the syncing.
	sharedSyncActions

	notifyCmd "Done." "$gnupotDefaultNotificationTime"

	return 0

}

# Kill program if local and/or remote directories do not exist.
function checkDirExistence
{

	input="$1"


	if [ "$input" -ne 0 ]; then
		errMsg="Local and/or remote directory does/do not exist."
		echo -en "$errMsg\n"
		notifyCmd "$errMsg" "$gnupotDefaultNotificationTime"
		kill -s SIGINT 0
	fi

	return 0

}

function checkServerDirExistence
{

	# Check if remote directory exists.
	dirNotExists=$(ssh $SSHCONNECTCMDARGS "if [ ! -d $gnupotRemoteDir ]; \
then echo 1; else echo 0; fi")
	checkDirExistence "$dirNotExists"

	return 0

}

function checkClientDirExistence
{

	# Check if local directory exists.
	dirNotExists=$(if [ ! -d "$gnupotLocalDir" ]; \
then echo 1; else echo 0; fi)
	checkDirExistence "$dirNotExists"

	return 0

}

function callSync
{

	source="$1"


	# Check if the other thread is in the critical section.
	# This avoids a two way file update. Example: if a file is
	# modified on the client, it is sent immediately to the server.
	# However the server thead detects changes and so an unecessary
	# pull is made from the server.
	# So there are two types of locks: one between the round
	# brackets and the other one is made by the if clause.
	if [ $(cat "$gnupotLockFilePath") -eq 0 ]; then
		# Open a subshell for critical section.
		(
			# Acquire lockfile.
			echo 1 > "$gnupotLockFilePath"
			# While not acquire lock:
			# while [ ! flock -n 1024 ]; do :; done
			# is the same as the following line:
			flock -x "$FD"
			syncOperation "$source" "$path"
		# End critical section.
		) {FD}>>"$gnupotLockFilePath"
		# Get first valid file descriptor from a bash builtin.
		# Free lockfile.
		echo 0 > "$gnupotLockFilePath"
	else
		# Wait some time to avoid unecessary loops. This happens if
		# there are lots of files to be transferred
		sleep "$gnupotTimeToWaitForOtherChanges"
	fi

	return 0

}

# Server sync thread.
function syncS
{

	# return/exit when signal{s} is/are received.
	trap "exit" $SIGNALS

	# Open master ssh socket.
#	ssh $SSHMASTERSOCKCMDARGS 2>&-
	execSSHCmd "ssh $SSHMASTERSOCKCMDARGS"

	checkServerDirExistence

	while true; do
		# Listen for changes on server
		path=$(ssh $SSHCONNECTCMDARGS "$INOTIFYWAITCMD" \
"$gnupotRemoteDir" | awk ' { print $1 $3 } ')
		callSync "server"
	done

}

# Client sync thread.
function syncC
{

	trap "exit" $SIGNALS

	checkClientDirExistence

	while true; do
		path=$($INOTIFYWAITCMD --exclude .git "$gnupotLocalDir" \
| awk ' { print $1 $3 } ')
		callSync "client"
	done

}

# Signal handler function.
function sigHandler
{

	echo -en "GNUpot killed\n" 1>&2

	# Kill master ssh socket (this will kill any ssh connection associated
	# with it). Also disable stderr output for this command with "2>&-".
	ssh -O exit -S "$gnupotSSHMasterSocketPath" "$gnupotServer" 2>&- &
	# Kill all the processes of this group.
	kill -s SIGINT 0

	return 0

}

function printHelp
{

	prgPath="$1"


	echo -en "\
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
" 1>&2

	return 0

}

function printStatus
{

	i=0


	echo -en "GNUpot is " 1>&2
	total="$(pgrep gnupot)"
	for proc in $total; do i=$(($i+1)); done
	if [ $i -lt 6 ]; then echo -en "NOT " 1>&2; fi
	echo -en "running correctly.\n" 1>&2

	return 0

}

# Check if all necessary programs are installed.
function checkExecutables
{

	gitVer=""
	gitVer0=""
	gitVer1=""
	# Garbage variable.
	trash=""


	# Check if git supports GIT_SSH_COMMAND environment variaible.
	gitVer="$(git --version | awk ' { print $3 } ')"
	IFS="." read gitVer0 gitVer1 trash <<< "$gitVer"
	if [ "$gitVer0$gitVer1" -le 23 ]; then return 1; fi

	# Redirect which stderr and stdout to /dev/null (see bash
	# redirection).
	which $PROGRAMS &>/dev/null

	return "$?"

}

# Main function that runs in background.
function main
{

	prgPath="$1"
	argArray="$2"


	# Enable signal interpretation to kill all subshells
	trap "sigHandler" $SIGNALS

	lockOnFile "$prgPath" "$argArray"

	notifyCmd "GNUpot starting..." "$gnupotDefaultNotificationTime"

	echo 0 > "$gnupotLockFilePath"

	# First of all, pull from server
	#sharedSyncActions

	# Listen from server and send to client.
	syncS &
	srvPid="$!"
	# Listen from client and send to server.
	syncC &
	cliPid="$!"

	# Wait for server and client threads to exit.
	wait "$srvPid" "$cliPid"

	notifyCmd "GNUpot stopped." "$gnupotDefaultNotificationTime"

	return 0

}

function parseOpts
{

	prgPath="$1"
	argArray="$2"

	# If there are no arguments, start GNUpot as if there was -i flag.
	if [ -z "$argArray" ]; then main "$prgPath" "$argArray" & return 0; fi
	# Get options from special variable $@.
	getopts ":hilkps" opt "$argArray"
	case "$opt" in
		h ) printHelp "$prgPath"; return 1 ;;
		# Call main function as spawned shell (execute and return
	 	# control to the shell).
		i ) main "$prgPath" "$argArray" & ;;
		l ) less "LICENSE" ;;
		k ) killall -s SIGINT -q gnupot ;;
		p ) cat ""$HOME"/.config/gnupot/gnupot.config" ;;
		s ) printStatus ;;
		? ) printHelp "$prgPath"; return 1 ;;
	esac

	return 0

}

# Load configuration.
loadConfig

checkExecutables
if [ "$?" -ne 0 ]; then echo -en "Missing programs or unsupported. Check: \
$PROGRAMS.\n" 1>&2; exit 1; fi

# Call option parser.
parseOpts "$0" "$@"

exit "$?"
