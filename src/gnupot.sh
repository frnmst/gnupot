#!/bin/bash

#
# gnupot
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

# Flock so that script is not executed more than once.
# See man 1 flock (examples section).
[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@" || :

# Load configuration.
if [ -f "gnupot.config" ]; then
	source gnupot.config
fi

# Macros.

# SSH arguments.
# TODO: Add -i <public key> as explicit parameter.
SSHARGS="-C -S "$gnupotSSHMasterSocketPath""

# Used for general ssh commands
SSHCONNECTCMDARGS="$SSHARGS "$gnupotServerUsername"@"$gnupotServer""

# Open master socket so that further connection will result faster
# (using multiplexing to avoid re-authentication).
SSHMASTERSOCKCMDARGS="-M -o \
ControlPersist="$gnupotSSHMasterSocketTime" \
$SSHCONNECTCMDARGS exit"

# inotifywait command macro: recursive, quiet, listen only to certain events.
INOTIFYWAITCMD="inotifywait -r -q -e modify -e attrib \
-e move -e move_self -e create -e delete -e delete_self"

GITCMD="git"

# git environment variable for ssh.
GIT_SSH_COMMAND="ssh $SSHARGS"


# General notification function.
function notifyCmd ()
{

	msg="$1"
	ms="$2"


	notify-send -t "$ms" "$msg"

	return 0

}

function syncNotify ()
{

	path="$1"
	dir="$2"
	source="$3"


	notifyCmd "GNUpot syncing $(getRelativePath "$path" \
"$dir") from "$source"" "$gnupotDefaultNotificationTime"

	return 0

}

# Get relative path for local or remote changed files.
function getRelativePath ()
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
function resolveConflicts ()
{

	returnedVal="$1"
	action="$2"


	if [ "$returnedVal" -eq 1 ]; then
		notifyCmd "Resolving file conflicts." \
"$gnupotDefaultNotificationTime"
		$GITCMD commit -a -m "Commit on $(date "+%s"). Handled \
conflicts"
	fi

	return 0

}

# Clean useless files and keep maximum user defined number of backups.
function backupAndClean ()
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
		$GITCMD commit -m "Truncated history on $(date "+%s")"
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

function getCommitNumber ()
{

	if [ ! -f "$gnupotCommitNumberFilePath" ]; then
		echo 1 > "$gnupotCommitNumberFilePath"
		echo 1
	else
		cat "$gnupotCommitNumberFilePath"
	fi

	return 0

}

# Both client and server threads execute this function.
function sharedSyncActions ()
{

	# Do all git operations in the correct directory.
	cd "$gnupotLocalDir"

	$GITCMD add -A
	$GITCMD commit -a -m "Commit on $(date "+%s")"
	# Always pull from server first then check for conflicts using return
	# value.
	$GITCMD pull origin master

	resolveConflicts "$?" "<smt>"

	currentCommits=$(getCommitNumber)

	# To be able to use this: git config --system
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
function syncOperation ()
{

	source="$1"
	path="$2"


	sleep "$gnupotTimeToWaitForOtherChanges"

	if [ "$source" == "server" ]; then
		syncNotify "$path" "$gnupotRemoteDir" "server"
	else
		syncNotify "$path" "$gnupotLocalDir" "client"
	fi

	# Do the syncing.
	sharedSyncActions

	# OK.
	notifyCmd "Done." "$gnupotDefaultNotificationTime"

	return 0

}

# Kill program if local and/or remote directories do not exist.
function checkDirExistence ()
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

function checkServerDirExistence ()
{

	# Check if remote directory exists.
	dirNotExists=$(ssh $SSHCONNECTCMDARGS "if [ ! -d $gnupotRemoteDir ]; \
then echo 1; else echo 0; fi")
	checkDirExistence "$dirNotExists"

	return 0

}

function checkClientDirExistence ()
{

	# Check if local directory exists.
	dirNotExists=$(if [ ! -d "$gnupotLocalDir" ]; \
then echo 1; else echo 0; fi)
	checkDirExistence "$dirNotExists"

	return 0

}

function callSync ()
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
function syncS ()
{

	# return/exit when signal{s} is/are received.
	trap "return 0" SIGINT SIGTERM

	# Open master ssh socket.
	ssh $SSHMASTERSOCKCMDARGS 2>&-

	checkServerDirExistence

	while true; do

		# Listen for changes on server
		path=$(ssh $SSHCONNECTCMDARGS "$INOTIFYWAITCMD" \
"$gnupotRemoteDir" | awk ' { print $1 $3 } ')
		callSync "server"

	done

}

# Client sync thread.
function syncC ()
{

	trap "return 0" SIGINT SIGTERM

	checkClientDirExistence

	while true; do

		path=$($INOTIFYWAITCMD --exclude .git "$gnupotLocalDir" \
| awk ' { print $1 $3 } ')
		callSync "client"

	done

}

# Signal handler function.
function sigHandler ()
{

	echo -en "GNUpot killed\n" 1>&2

	# Kill master ssh socket (this will kill any ssh connection associated
	# with it). Also disable stderr output for this command with "2>&-".
	ssh -O exit -S "$gnupotSSHMasterSocketPath" "$gnupotServer" 2>&- &
	# Kill all the processes of this group.
	kill -s SIGINT 0

	return 0

}

# Clean before exiting.
function clean ()
{

	# Wait for client and server threads before exiting.
	wait "$srvPid" "$cliPid"

	return 0

}

# Main function that runs in background.
function main ()
{

	# Enable signal interpretation to kill all subshells
	trap "sigHandler" SIGINT SIGTERM

	notifyCmd "GNUpot starting..." "$gnupotDefaultNotificationTime"

	echo 0 > "$gnupotLockFilePath"

	# Listen from server and send to client.
	syncS &
	srvPid="$!"
	# Listen from client and send to server.
	syncC &
	cliPid="$!"

	clean

	notifyCmd "GNUpot stopped..." "$gnupotDefaultNotificationTime"

	return 0

}

# Call main function as spawned shell (execute and return control to the
# shell).
main &

exit 0


# SOME IDEAS FOR A BETTER FILE CONFLICT RESOLVER FUNCTION.
#
#	if [ "$returnedVal" -eq 1 ]; then
#		notifyCmd "Resolving file conflicts." \
#"$gnupotDefaultNotificationTime"

		# SOME IDEAS.
		# Server and clients have master and tmp branches.
		# If there is no problems, branches are equal.
		# Otherwise:
		#
		# git pull origin tmp
		# <compare master & tmp branches: get conflicting files list>
		# <move master files>
		# git checkout ??-b?? tmp # change to tmp branch
		# <move tmp files>
		# <merge branches in master branch without deleting tmp branch>
		# git push origin master
		# git push origin tmp
		# END OF SOME IDEAS.

		# IT DOES NOT WORK BUT THIS IS THE previous IDEA:
		# get file conflict list
		#conflictList=$(git diff --name-only --diff-filter=U)
		# Create locally tmp branch if it doen not exist.
		#git checkout -b tmp
		#for conflict in $conflictList; do
			# move conflicting files to new names
		#	mv "$conflict" "$conflict"."$REMOTE_USR"."$DATE"
		#done
		#git commit -a -m "??resolved??"
		# change to master branch
		#git checkout master
		#for conflict in $conflictList; do
			# move conflicting files to new names
		#	mv "$conflict" "$conflict"."$REMOTE_USR"."$DATE"
		#done
		# tmp U master
		#git merge tmp

		#if [ "$action" == "push" ]; then
			#git push origin master
		#else
		#	:
		#fi

		#notifyCmd "File conflicts resolved." \
#"$gnupotDefaultNotificationTime"

#		echo 1
#	fi

#	echo 0
