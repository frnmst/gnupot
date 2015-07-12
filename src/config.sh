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

# This avoid problems with git ssh variable.
set -a

# Macros.
HELPFILE="README.md"
BACKTITLE="GNUpot_setup._F1_for_help."
DIALOG="dialog --stdout --hfile $HELPFILE --backtitle $BACKTITLE"
CHKCMD="which git && which inotifywait"
CONFIGDIR="$HOME/.config/gnupot"
VARIABLESOURCEFILEPATH="src/configVariables.conf"
GIT_SSH_COMMAND=""

[ -f "$VARIABLESOURCEFILEPATH" ] && source "$VARIABLESOURCEFILEPATH" \
|| echo -en "Cannot start setup. No variables file found.\n"

# Flock so that script is not executed more than once.
# See man 1 flock (examples section).
[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en \
"$VARIABLESOURCEFILEPATH" "$0" "$@" || :

# Variables.
optNum="16"
options=""
winX="100"
winY="25"

infoMsg()
{
	# --msgbox or --infobox
	local type="$1" msg="$2"

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
"Server address or hostname:"		1 1 "$Server"		1 35 $action \
0 \
"Remote user name:"			2 1 "$ServerUsername"	2 35 $action \
0 \
"Remote directory path:"		3 1 "$RemoteDir"  	3 35 $action \
0 \
"Local directory full path:"		4 1 "$LocalDir"		4 35 $action \
0 \
"Local public key full path:"		5 1 "$SSHKeyPath"	5 35 $action \
0 \
"Backups to keep (0 = keep all):"	6 1 "$KeepMaxCommits" 	6 35 $action \
0 \
"Local home full path:"			7 1 "$LocalHome"	7 35 $action \
0 \
"Remote home full path:"		8 1 "$RemoteHome"	8 35 $action \
0 \
"git committer user name:"		9 1 "$GitCommitterUsername" \
9 35 $action 0 \
"git committer email:"			10 1 "$GitCommitterEmail" \
10 35 $action 0 \
"Time to wait for changes (s):"		11 1 "$TimeToWaitForOtherChanges" \
11 35 $action 0 \
"Time to wait on problem (s):"		12 1 "$BusyWaitTime" \
12 35 $action 0 \
"SSH Master Socket Path:"		13 1 "$SSHMasterSocketPath" \
13 35 $action 0 \
"SSH socket keepalive time (min):"	14 1 "$SSHMasterSocketTime" \
14 35 $action 0 \
"Event notification time (ms):"		15 1 "$NotificationTime" \
15 35 $action 0 \
"Lock file full path:"			16 1 "$LockFilePath" \
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
	local FORMVARIABLES="Server ServerUsername RemoteDir LocalDir \
SSHKeyPath KeepMaxCommits LocalHome RemoteHome GitCommitterUsername \
GitCommitterEmail TimeToWaitForOtherChanges BusyWaitTime \
SSHMasterSocketPath SSHMasterSocketTime NotificationTime \
LockFilePath"

	# Control bash version to avoid IFS bug. bash 4.2 (and lower?) has this
	# bug. If bash is <=4.2 spaces must be avoided in form fields.
	local bashVersion="${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}"
	if [ "$bashVersion" -le 42 ];then
		options="$(echo $options | tr " " ";")"
		IFS=";" read $FORMVARIABLES <<< "$options"
	else
		IFS=' ' read $FORMVARIABLES <<< $options
	fi

	return 0
}

verifyConfig()
{
	local i=0

	for option in $options; do i=$(($i+1)); done
	if [ $i -lt $optNum ]; then return 1; fi

	return 0
}

summary()
{
	displayForm "GNUpot setup summary" "Are the displayed values \
correct?" "0"

	return "$?"
}

genSSHKey()
{
	if [ ! -f "$SSHKeyPath" ]; then
		infoMsg "infobox" "Generating SSH keys. Please wait."
		ssh-keygen -t rsa -b "$RSAKeyBits" -C \
"gnupot:$USER@$HOSTNAME:$(date -I)" -f "$SSHKeyPath" -N "" -q
	fi
	infoMsg "infobox" "You will now be prompted for "$ServerUsername"'s \
password..."
	sleep 5
	ssh-copy-id -i ""$SSHKeyPath".pub" "$ServerUsername"@"$Server"

	# Check if ssh works and if remote programs exist.
	ssh -o PasswordAuthentication=no -i "$SSHKeyPath" \
"$ServerUsername"@"$Server" "$CHKCMD" 1>&- 2>&-

	return "$?"
}

testInfo()
{
	# Check if ssh and remote programs already work.
	{ ping -c 1 -s 0 -w 30 "$Server" 1>&- 2>&- \
&& ssh -o PasswordAuthentication=no -i "$SSHKeyPath" \
"$ServerUsername"@"$Server" "$CHKCMD" 1>&- 2>&- \
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
	ssh -i "$SSHKeyPath" "$ServerUsername"@"$Server" \
"if [ ! -d "$RemoteDir" ]; then mkdir -p "$RemoteDir" && cd "$RemoteDir" \
&& git init --bare --shared; fi \
&& git config --system receive.denyNonFastForwards true" 1>&- 2>&-

	return 0
}

# Make a fake commit to avoid problems at the first pull of a new repository.
makeFirstCommit()
{
	cd "$LocalDir"
	[ ! -f ".firstCommit" ] && { touch .firstCommit; git add -A 1>&- \
2>&-; git commit -a -m "First commit." 1>&- 2>&-; git push origin master \
1>&- 2>&-; }
	cd "$OLDPWD"

	return 0
}

# Set committer information.
setGitCommitterInfo()
{
	cd "$LocalDir"
	git config user.name "$GitCommitterUsername"
	git config user.email "$GitCommitterEmail"
	cd "$OLDPWD"

	return 0
}

cloneRepo()
{
	GIT_SSH_COMMAND="ssh -i $SSHKeyPath"

	if [ ! -d "$LocalDir" ]; then
		infoMsg "infobox" "Cloning remote repository. This may take \
a while."
		git clone "$ServerUsername"@"$Server":"$RemoteDir" \
"$LocalDir" 1>&- 2>&- || { infoMsg "msgbox" "Cannot clone remote \
repository."; return 1; }
		setGitCommitterInfo
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
gnupotServer=\""$Server"\"\n\
gnupotServerUsername=\""$ServerUsername"\"\n\
gnupotRemoteDir=\""$RemoteDir"\"\n\
gnupotLocalDir=\""$LocalDir"\"\n\
gnupotSSHKeyPath=\""$SSHKeyPath"\"\n\
gnupotKeepMaxCommits=\""$KeepMaxCommits"\"\n\
gnupotLocalHome=\""$LocalHome"\"\n\
gnupotRemoteHome=\""$RemoteHome"\"\n\
gnupotGitCommitterUsername=\""$GitCommitterUsername"\"\n\
gnupotGitCommitterEmail=\""$GitCommitterEmail"\"\n\
gnupotTimeToWaitForOtherChanges=\""$TimeToWaitForOtherChanges"\"\n\
gnupotBusyWaitTime=\""$BusyWaitTime"\"\n\
gnupotSSHMasterSocketPath=\""$SSHMasterSocketPath"\"\n\
gnupotSSHMasterSocketTime=\""$SSHMasterSocketTime"\"\n\
gnupotNotificationTime=\""$NotificationTime"\"\n\
gnupotLockFilePath=\""$LockFilePath"\"\n\
" > ""$CONFIGDIR"/gnupot.config"

	return 0
}

main()
{
	while true; do
		getConfig
		verifyConfig
		[ ! "$?" -eq 0 ] && { main; return 0; }
		strTok
		summary
		[ ! "$?" -eq 0 ] && { main; return 0; }
		initConfigDir
		[ ! "$?" -eq 0 ] && { main; return 0; }
		testInfo
		[ ! "$?" -eq 0 ] && { main; return 0; }
		initRepo
		cloneRepo
		[ ! "$?" -eq 0 ] && { main; return 0; }
		writeConfigFile
		[ -n "$DISPLAY" ] && bash -c "notify-send -t 10000 \
GNUpot\ setup\ completed."
		infoMsg "msgbox" "Setup completed."
		return 0
	done
}

main

exit 0
