#!/bin/bash

#
# config.sh
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


# Set path.
PATH="$PATH":/usr/bin

# Flock so that script is not executed more than once.
# See man 1 flock (examples section).
[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@" || :


# Macros.
HELPFILE="README.md"
BACKTITLE="GNUpot_setup"
DIALOG="dialog --clear --stdout --hfile $HELPFILE --backtitle $BACKTITLE"
CHKCMD="which git && which inotifywait"
CONFIGDIR="$HOME/.config/gnupot"

# Variables.
optNum="11"
options=""

# User variables.
# Required variables.
Server=""
ServerUsername=""
RemoteDir="GNUpot"
LocalDir=""$HOME"/GNUpot"
KeepMaxCommits="128"
LocalHome="$HOME"
RemoteHome=""
# Optional variables.
TimeToWaitForOtherChanges="5"
SSHMasterSocketPath="/tmp/gnupotSSHMasterSocket"
SSHMasterSocketTime="120"
DefaultNotificationTime="2000"
LockFilePath="$CONFIGDIR/.lockfile"
CommitNumberFilePath="$CONFIGDIR/.commitNums"


function infoMsg ()
{

	msg="$1"


	$DIALOG --title "INFO" --msgbox \
"$msg" 25 90

	return 0

}

function displayForm ()
{

	title="$1"
	arg="$2"
	action="$3"
	opts=""
	retval=""


	opts=$($DIALOG --title "$title" \
--form "$arg" \
20 90 0 \
"Server address or hostname:"		1 1 "$Server"		1 35 $action \
0 \
"Remote user name:"			2 1 "$ServerUsername"	2 35 $action \
0 \
"Remote directory path:"		3 1 "$RemoteDir"  	3 35 $action \
0 \
"Local directory full path:"		4 1 "$LocalDir"	4 35 $action 0 \
"Backups to keep (0 = keep all):"	5 1 "$KeepMaxCommits" 	5 35 $action \
0 \
"Local home full path:"			6 1 "$LocalHome"	6 35 $action \
0 \
"Remote home full path:"		7 1 "$RemoteHome"	7 35 $action \
0 \
"Time to wait for changes (s):"		8 1 "$TimeToWaitForOtherChanges" \
8 35 $action 0 \
"SSH Msster Socket Path:"		9 1 "$SSHMasterSocketPath" \
9 35 $action 0 \
"SSH socket keepalive time (min):"	10 1 "$SSHMasterSocketTime" \
10 35 $action 0 \
"Event notification time:"		11 1 "$DefaultNotificationTime" \
11 35 $action 0 \
)
	retval="$?"
	echo "$opts"

	return "$retval"

}

function getConfig ()
{

	options=$(displayForm "GNUpot setup" "Use arrow up and down \
to move between fields" "50")

	return 0

}

function strTok ()
{

	IFS=' ' read \
Server ServerUsername RemoteDir LocalDir KeepMaxCommits LocalHome RemoteHome \
TimeToWaitForOtherChanges SSHMasterSocketPath SSHMasterSocketTime \
DefaultNotificationTime <<< $options

	return 0

}

function verifyConfig ()
{

	i=0


	for option in $options; do i=$(($i+1)); done
	if [ $i -lt $optNum ]; then return 1; fi

	return 0

}

function summary ()
{

	displayForm "GNUpot setup summary" "Are the displayed values \
correct?" "0"

	return "$?"

}

function testInfo ()
{

	# Check if ssh works and if remote programs exist.
	if [ $(ssh "$ServerUsername"@"$Server" \
"$CHKCMD" 1>&- 2>&-; echo "$?") -ne 0 ]; then
		infoMsg "SSH problem or git and/or inotifywait missing on server."
		return 1
	fi

	return 0

}

function initConfigDir ()
{

	mkdir -p ""$HOME"/.config/gnupot"
	if [ "$?" -ne 0 ]; then
		infoMsg "Cannot create configuration directory."
		return 1
	fi

	return 0

}

function initRepo ()
{

	ssh "$ServerUsername"@"$Server" \
"if [ ! -d "$RemoteDir" ]; then mkdir -p "$RemoteDir" && cd "$RemoteDir" \
&& git init --bare --shared; fi \
&& git config --system receive.denyNonFastForwards true" 1>&- 2>&-

	return 0
}

function cloneRepo ()
{

	if [ ! -d "$LocalDir" ]; then
		git clone "$ServerUsername"@"$Server":"$RemoteDir" \
"$LocalDir" 1>&- 2>&-
		if [ "$?" -ne 0 ]; then
			infomsg "Cannot clone remote repository."
			return 1
		fi
	else
		infoMsg "Local destination directory already exists. Delete \
it first then restart the setup."
		return 1
	fi

	return 0

}

function writeConfigFile ()
{

	SSHMasterSocketTime=""$SSHMasterSocketTime"m"

	echo -en "\
gnupotServer=\""$Server"\"\n\
gnupotServerUsername=\""$ServerUsername"\"\n\
gnupotRemoteDir=\""$RemoteDir"\"\n\
gnupotLocalDir=\""$LocalDir"\"\n\
gnupotKeepMaxCommits=\""$KeepMaxCommits"\"\n\
gnupotLocalHome=\""$LocalHome"\"\n\
gnupotRemoteHome=\""$RemoteHome"\"\n\
gnupotTimeToWaitForOtherChanges=\""$TimeToWaitForOtherChanges"\"\n\
gnupotSSHMasterSocketPath=\""$SSHMasterSocketPath"\"\n\
gnupotSSHMasterSocketTime=\""$SSHMasterSocketTime"\"\n\
gnupotDefaultNotificationTime=\""$DefaultNotificationTime"\"\n\
gnupotLockFilePath=\""$LockFilePath"\"\n\
gnupotCommitNumberFilePath=\""$CommitNumberFilePath"\"\n\
" > ""$CONFIGDIR"/gnupot.config"

	return 0

}

function main ()
{

	while true; do
		getConfig
		verifyConfig
		if [ ! "$?" -eq 0 ]; then main return 0; fi
		strTok
		summary
		if [ ! "$?" -eq 0 ]; then main return 0; fi
		testInfo
		if [ ! "$?" -eq 0 ]; then main return 0; fi
		initConfigDir
		if [ ! "$?" -eq 0 ]; then main return 0; fi
		initRepo
		cloneRepo
		if [ ! "$?" -eq 0 ]; then main return 0; fi
		writeConfigFile
		infoMsg "Setup completed."
		return 0
	done

}

main

exit 0
