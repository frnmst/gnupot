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


# Macros.
BACKTITLE="https://github.com/frnmst/gnupot"
DIALOG="dialog --stdout --backtitle $BACKTITLE"
REMOTECHKCMD="which git && which inotifywait"
CONFIGDIR="$HOME/.config/gnupot"
CONFIGFILEPATH="src/configVariables.conf"

# Other global variables.
options=""
optNum="20"

infoMsg()
{
	# msgbox, infobox, yesno
	local type="$1" msg="$2" winX="110" winY="30"

	if [ "$type" != "infobox" ]; then
		$DIALOG --clear --title "INFO" --"$type" \
"$msg" "$winY" "$winX"
	else
		$DIALOG --title "INFO" --"$type" \
"$msg" "$winY" "$winX"
	fi

	return "$?"
}

displayForm()
{
	local title="$1" arg="$2" action="$3" opts="" retval="" fldChrs="50"

	opts=$($DIALOG --title "$title" \
--form "$arg" \
"$winY" "$winX" 0 \
"Server address or hostname:"		1 1 "$gnupotServer"	1 $fldChrs \
$action 0 \
"Remote user name:"			2 1 "$gnupotServerUsername" \
2 $fldChrs $action 0 \
"Remote directory path:"		3 1 "$gnupotRemoteDir"	3 $fldChrs \
$action 0 \
"Local directory full path:"		4 1 "$gnupotLocalDir"	4 $fldChrs \
$action 0 \
"Local RSA keys full path:"		5 1 "$gnupotSSHKeyPath"	5 $fldChrs \
$action 0 \
"Local RSA keys length (bits):"		6 1 "$gnupotRSAKeyBits"	6 $fldChrs \
$action 0 \
"Backups to keep (#; 0 = keep all):"	7 1 "$gnupotKeepMaxCommits" \
7 $fldChrs $action 0 \
"Exclude file inotify POSIX pattern:"	8 1 "$gnupotInotifyFileExclude" \
8 $fldChrs $action 0 \
"Exclude file git globbing pattern:"	9 1 "$gnupotGitFileExclude" \
9 $fldChrs $action 0 \
"git committer user name:"		10 1 "$gnupotGitCommitterUsername" \
10 $fldChrs $action 0 \
"git committer email:"			11 1 "$gnupotGitCommitterEmail" \
11 $fldChrs $action 0 \
"Time to wait for file changes (s):"	12 1 \
"$gnupotTimeToWaitForOtherChanges" 12 $fldChrs $action 0 \
"Time to wait on problem (s):"		13 1 "$gnupotBusyWaitTime" \
13 $fldChrs $action 0 \
"SSH server alive interval (s; >= 1):"	14 1 "$gnupotSSHServerAliveInterval" \
14 $fldChrs $action 0 \
"SSH server alive count max (>= 1):" \
15 1 "$gnupotSSHServerAliveCountMax" 15 $fldChrs $action 0 \
"SSH master socket full path:"		16 1 "$gnupotSSHMasterSocketPath" \
16 $fldChrs $action 0 \
"Event notification time (ms):"		17 1 "$gnupotNotificationTime" \
17 $fldChrs $action 0 \
"Lock file full path:"			18 1 "$gnupotLockFilePath" \
18 $fldChrs $action 0 \
"Download max speed (KB/s) (0 = no limit):" \
19 1 "$gnupotDownloadSpeed" 19 $fldChrs $action 0 \
"Upload max speed (KB/s) (0 = no limit):" \
20 1 "$gnupotUploadSpeed" 20 $fldChrs $action 0 \

)
	retval="$?"
	echo "$opts"

	return "$retval"
}

getConfig()
{
	options=$(displayForm "GNUpot setup" "Use arrow up and down \
to move between fields" "80")

	return 0
}

strTok()
{
	local FORMVARIABLES="gnupotServer gnupotServerUsername \
gnupotRemoteDir gnupotLocalDir gnupotSSHKeyPath gnupotRSAKeyBits \
gnupotKeepMaxCommits gnupotInotifyFileExclude gnupotGitFileExclude \
gnupotGitCommitterUsername gnupotGitCommitterEmail \
gnupotTimeToWaitForOtherChanges gnupotBusyWaitTime \
gnupotSSHServerAliveInterval gnupotSSHServerAliveCountMax \
gnupotSSHMasterSocketPath gnupotNotificationTime gnupotLockFilePath \
gnupotDownloadSpeed gnupotUploadSpeed"

	# Control bash version to avoid IFS bug. bash 4.2 (and lower) has this
	# bug. If bash is <=4.2 spaces must be avoided in form fields.
	local bashVersion="${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}"
	[ "$bashVersion" -le 42 ] && options="$(echo $options | tr " " ";")" \
&& IFS=";" read -r $FORMVARIABLES <<< "$options" \
|| IFS=' ' read -r $FORMVARIABLES <<< $options

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
&& git -C "$gnupotRemoteDir" init --bare --shared; fi \
&& git -C "$gnupotRemoteDir" config --system receive.denyNonFastForwards \
false" 1>&- 2>&-

	return 0
}

# Make a fake commit to avoid problems at the first push of a new repository.
makeFirstCommit()
{
	cd "$gnupotLocalDir"
	# Check if git's HEAD exists.
	[ -z "$(git show-ref --head)" ] \
&& { git commit -m "First commit by "$USER"." --allow-empty 1>&- 2>&-; \
git push origin master 1>&- 2>&-; }
	cd "$OLDPWD"

	return 0
}

updateRepo()
{
	# Check if repo path coincides with the one written in the conf file.
	# Push and pull so that history is even.
	[ "$(git -C "$gnupotLocalDir" config --get remote.origin.url)" = \
"$gnupotServerUsername"@"$gnupotServer":"$gnupotRemoteDir" ] || return 1

[ "$(git status --porcelain | wc -m)" -gt 0 ] \
&& { git -C "$gnupotLocalDir" add -A 1>&- 2>&-; \
git -C "$gnupotLocalDir" commit -am "Update merge by "$USER"." 1>&- 2>&-; }

	{ git -C "$gnupotLocalDir" pull origin master 1>&- 2>&- \
&& git -C "$gnupotLocalDir" push origin master 1>&- 2>&-; } \
|| return 1

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
		# Check if local and remote commits are equal.
		updateRepo || \
		{ infoMsg "yesno" "Local destination directory already exists \
and commit history differs from the remote server's one (or the selected \
diretory is not a git repository). \
Backup old directory and continue [yes] or Delete it and continue [no] ?"; \
		# 0 = yes; 1 = no. \
		{ [ "$?" -eq 0 ] && mv "$gnupotLocalDir" \
""$gnupotLocalDir"_"$(date +%s)"" || rm -rf "$gnupotLocalDir"; }; \
		cloneRepo; }
	fi

	return 0
}

writeConfigFile()
{
	# Force variable to avoid problems. Waiting for a real solution...
	# Note the triple escape.
	gnupotGitFileExclude="**/*.swp\\\n**/*.save*"

	printf "\
gnupotServer=\""$gnupotServer"\"\n\
gnupotServerUsername=\""$gnupotServerUsername"\"\n\
gnupotRemoteDir=\""$gnupotRemoteDir"\"\n\
gnupotLocalDir=\""$gnupotLocalDir"\"\n\
gnupotSSHKeyPath=\""$gnupotSSHKeyPath"\"\n\
gnupotRSAKeyBits=\""$gnupotRSAKeyBits"\"\n\
gnupotKeepMaxCommits=\""$gnupotKeepMaxCommits"\"\n\
gnupotInotifyFileExclude=\""$gnupotInotifyFileExclude"\"\n\
gnupotGitFileExclude=\""$gnupotGitFileExclude"\"\n\
gnupotGitCommitterUsername=\""$gnupotGitCommitterUsername"\"\n\
gnupotGitCommitterEmail=\""$gnupotGitCommitterEmail"\"\n\
gnupotTimeToWaitForOtherChanges=\""$gnupotTimeToWaitForOtherChanges"\"\n\
gnupotBusyWaitTime=\""$gnupotBusyWaitTime"\"\n\
gnupotSSHServerAliveInterval=\""$gnupotSSHServerAliveInterval"\"\n\
gnupotSSHServerAliveCountMax=\""$gnupotSSHServerAliveCountMax"\"\n\
gnupotSSHMasterSocketPath=\""$gnupotSSHMasterSocketPath"\"\n\
gnupotNotificationTime=\""$gnupotNotificationTime"\"\n\
gnupotLockFilePath=\""$gnupotLockFilePath"\"\n\
gnupotDownloadSpeed=\""$gnupotDownloadSpeed"\"\n\
gnupotUploadSpeed=\""$gnupotUploadSpeed"\"\n\
" > ""$CONFIGDIR"/gnupot.config"

	chmod 600 ""$CONFIGDIR"/gnupot.config"

	return 0
}

mainSetup()
{
	while true; do
		getConfig
		verifyConfig
		[ "$?" -ne 0 ] && { mainSetup; return 0; }
		strTok
		parseConfig || { infoMsg "msgbox" "Value/s type invalid."; \
$(return 1); }
		[ "$?" -ne 0 ] && { mainSetup; return 0; }
		displayForm "GNUpot setup summary" "Are the displayed values \
correct?" "0"
		[ "$?" -ne 0 ] && { mainSetup; return 0; }
		initConfigDir
		[ "$?" -ne 0 ] && { mainSetup; return 0; }
		testInfo
		[ "$?" -ne 0 ] && { mainSetup; return 0; }
		initRepo
		cloneRepo
		[ "$?" -ne 0 ] && { mainSetup; return 0; }
		writeConfigFile
		[ -n "$DISPLAY" ] && bash -c "notify-send -t 2000 \
'GNUpot setup completed.'"
		infoMsg "msgbox" "Setup completed."
		return 0
	done
}

# See funcions.sh for explanation (callMain function).
[ "$(pgrep -c gnupot)" -gt 1 ] && { Err "GNUpot is already running.\n"; \
exit 1; }

# Load default variables.
. "src/configVariables.conf" \
|| { Err "Cannot start setup. No variables file found.\n"; exit 1; }

# Load variables file if gnupot.config already exists.
[ -f ""$CONFIGDIR"/gnupot.config" ] && . ""$CONFIGDIR"/gnupot.config"

mainSetup

exit 0
