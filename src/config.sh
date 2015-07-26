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


set -x

# Set path.
PATH="$PATH":/usr/bin

# This avoid problems with git ssh variable.
set -a

# Macros.
HELPFILE="README.md"
BACKTITLE="GNUpot_setup._F1_for_help."
DIALOG="dialog --stdout --hfile $HELPFILE --backtitle $BACKTITLE"
REMOTECHKCMD="which git && which inotifywait"
CONFIGDIR="$HOME/.config/gnupot"
PROGRAMS="bash ssh inotifywait flock git getent"
CONFIGFILEPATH="src/configVariables.conf"

options=""
optNum="16"

# Source function file.
. "src/functions.sh"

infoMsg()
{
	# --msgbox or --infobox
	local type="$1" msg="$2" winX="100" winY="25"

	if [ "$type" = "msgbox" ]; then
		$DIALOG --clear --title "INFO" --"$type" \
"$msg" "$winY" "$winX"
	else
		$DIALOG --title "INFO" --"$type" \
"$msg" "$winY" "$winX"
	fi

	return 0
}

displayForm()
{
	local title="$1" arg="$2" action="$3" opts="" retval=""

	opts=$($DIALOG --title "$title" \
--form "$arg" \
"$winY" "$winX" 0 \
"Server address or hostname:"		1 1 "$gnupotServer"	1 35 $action \
0 \
"Remote user name:"			2 1 "$gnupotServerUsername" \
2 35 $action 0 \
"Remote directory path:"		3 1 "$gnupotRemoteDir"	3 35 $action \
0 \
"Local directory full path:"		4 1 "$gnupotLocalDir"	4 35 $action \
0 \
"Local public key full path:"		5 1 "$gnupotSSHKeyPath"	5 35 $action \
0 \
"Backups to keep (0 = keep all):"	6 1 "$gnupotKeepMaxCommits" \
6 35 $action 0 \
"Local home full path:"			7 1 "$gnupotLocalHome"	7 35 $action \
0 \
"Remote home full path:"		8 1 "$gnupotRemoteHome"	8 35 $action \
0 \
"git committer user name:"		9 1 "$gnupotGitCommitterUsername" \
9 35 $action 0 \
"git committer email:"			10 1 "$gnupotGitCommitterEmail" \
10 35 $action 0 \
"Time to wait for changes (s):"		11 1 \
"$gnupotTimeToWaitForOtherChanges" 11 35 $action 0 \
"Time to wait on problem (s):"		12 1 "$gnupotBusyWaitTime" \
12 35 $action 0 \
"SSH Master Socket Path:"		13 1 "$gnupotSSHMasterSocketPath" \
13 35 $action 0 \
"SSH socket keepalive time (min):"	14 1 "$gnupotSSHMasterSocketTime" \
14 35 $action 0 \
"Event notification time (ms):"		15 1 "$gnupotNotificationTime" \
15 35 $action 0 \
"Lock file full path:"			16 1 "$gnupotLockFilePath" \
16 35 $action 0 \
)
	retval="$?"
	echo "$opts"

	return "$retval"
}

getConfig()
{
	options=$(displayForm "GNUpot setup" "Use arrow up and down \
to move between fields" "60")

	return 0
}

strTok()
{
	local FORMVARIABLES="gnupotServer gnupotServerUsername \
gnupotRemoteDir gnupotLocalDir gnupotSSHKeyPath gnupotKeepMaxCommits \
gnupotLocalHome gnupotRemoteHome gnupotGitCommitterUsername \
gnupotGitCommitterEmail gnupotTimeToWaitForOtherChanges gnupotBusyWaitTime \
gnupotSSHMasterSocketPath gnupotSSHMasterSocketTime gnupotNotificationTime \
gnupotLockFilePath"

	# Control bash version to avoid IFS bug. bash 4.2 (and lower) has this
	# bug. If bash is <=4.2 spaces must be avoided in form fields.
	local bashVersion="${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}"
	[ "$bashVersion" -le 42 ] && options="$(echo $options | tr " " ";")" \
&& IFS=";" read $FORMVARIABLES <<< "$options" || IFS=' ' read $FORMVARIABLES \
<<< $options

	return 0
}

verifyConfig()
{
	local i=0 option=""

	for option in $options; do i=$(($i+1)); done
	[ $i -lt $optNum ] && return 1 || return 0
}

genSSHKey()
{
	if [ ! -f "$SSHKeyPath" ]; then
		infoMsg "infobox" "Generating SSH keys. Please wait."
		ssh-keygen -t rsa -b "$gnupotRSAKeyBits" -C \
"gnupot:$USER@$HOSTNAME:$(date -I)" -f "$gnupotSSHKeyPath" -N "" -q
	fi
	infoMsg "msgbox" "You will now be prompted for \
"$gnupotServerUsername"'s password..."
	ssh-copy-id -i ""$gnupotSSHKeyPath".pub" \
"$gnupotServerUsername"@"$gnupotServer"

	# Check if ssh works and if remote programs exist.
	ssh -o PasswordAuthentication=no -i "$gnupotSSHKeyPath" \
"$gnupotServerUsername"@"$gnupotServer" "$REMOTECHKCMD" 1>&- 2>&-

	return "$?"
}

testInfo()
{
	# Check if ssh and remote programs already work.
	{ ssh "$gnupotServerUsername"@"$gnupotServer" \
-o PasswordAuthentication=no 2>&1 | grep denied &>/dev/null \
&& ssh -o PasswordAuthentication=no -i "$gnupotSSHKeyPath" \
"$gnupotServerUsername"@"$gnupotServer" "$REMOTECHKCMD" 1>&- 2>&- \
|| genSSHKey; } \
|| { infoMsg "msgbox" "SSH problem or git and/or \
inotifywait missing on server."; return 1; }

	return 0
}

initConfigDir()
{
	mkdir -p ""$HOME"/.config/gnupot" || { infoMsg "msgbox" "Cannot \
create configuration directory."; return 1; }

	return 0
}

initRepo()
{
	ssh -i "$gnupotSSHKeyPath" "$gnupotServerUsername"@"$gnupotServer" \
"if [ ! -d "$gnupotRemoteDir" ]; then mkdir -p "$gnupotRemoteDir" \
&& cd "$gnupotRemoteDir" && git init --bare --shared; fi \
&& git config --system receive.denyNonFastForwards true" 1>&- 2>&-

	return 0
}

# Make a fake commit to avoid problems at the first pull of a new repository.
makeFirstCommit()
{
	cd "$gnupotLocalDir"
	git commit -m "Added user "$USER"." --allow-empty 1>&- 2>&-
	git push origin master 1>&- 2>&-
	cd "$OLDPWD"

	return 0
}

cloneRepo()
{
	GIT_SSH_COMMAND="ssh -i $gnupotSSHKeyPath"

	if [ ! -d "$gnupotLocalDir" ]; then
		infoMsg "infobox" "Cloning remote repository. This may take \
a while."
		git clone \
"$gnupotServerUsername"@"$gnupotServer":"$gnupotRemoteDir" \
"$gnupotLocalDir" 1>&- 2>&- || { infoMsg "msgbox" "Cannot clone remote \
repository."; return 1; }
		assignGitInfo
		makeFirstCommit
	else
		infoMsg "msgbox" "Local destination directory already exists. \
Delete it first then restart the setup."
		return 1
	fi

	return 0
}

writeConfigFile()
{
	echo -en "\
gnupotServer=\""$gnupotServer"\"\n\
gnupotServerUsername=\""$gnupotServerUsername"\"\n\
gnupotRemoteDir=\""$gnupotRemoteDir"\"\n\
gnupotLocalDir=\""$gnupotLocalDir"\"\n\
gnupotSSHKeyPath=\""$gnupotSSHKeyPath"\"\n\
gnupotKeepMaxCommits=\""$gnupotKeepMaxCommits"\"\n\
gnupotLocalHome=\""$gnupotLocalHome"\"\n\
gnupotRemoteHome=\""$gnupotRemoteHome"\"\n\
gnupotGitCommitterUsername=\""$gnupotGitCommitterUsername"\"\n\
gnupotGitCommitterEmail=\""$gnupotGitCommitterEmail"\"\n\
gnupotTimeToWaitForOtherChanges=\""$gnupotTimeToWaitForOtherChanges"\"\n\
gnupotBusyWaitTime=\""$gnupotBusyWaitTime"\"\n\
gnupotSSHMasterSocketPath=\""$gnupotSSHMasterSocketPath"\"\n\
gnupotSSHMasterSocketTime=\""$gnupotSSHMasterSocketTime"\"\n\
gnupotNotificationTime=\""$gnupotNotificationTime"\"\n\
gnupotLockFilePath=\""$gnupotLockFilePath"\"\n\
" > ""$CONFIGDIR"/gnupot.config"

	return 0
}

main()
{
	while true; do
		getConfig
		verifyConfig
		[ "$?" -ne 0 ] && { main; return 0; }
		strTok
		parseConfig || { infoMsg "msgbox" "Value/s type invalid."; \
$(return 1); }
		[ "$?" -ne 0 ] && { main; return 0; }
		displayForm "GNUpot setup summary" "Are the displayed values \
correct?" "0"
		[ "$?" -ne 0 ] && { main; return 0; }
		initConfigDir
		[ "$?" -ne 0 ] && { main; return 0; }
		testInfo
		[ "$?" -ne 0 ] && { main; return 0; }
		initRepo
		cloneRepo
		[ "$?" -ne 0 ] && { main; return 0; }
		writeConfigFile
		[ -n "$DISPLAY" ] && bash -c "notify-send -t 10000 \
GNUpot\ setup\ completed."
		infoMsg "msgbox" "Setup completed."
		return 0
	done
}

# Flock so that script is not executed more than once.
lockOnFile "$0" "" || exit 1

# Load default variables.
. "src/configVariables.conf" \
|| { echo -en "Cannot start setup. No variables file found.\n"; exit 1; }

checkExecutables
main

exit 0
