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

# Other global variables.
options=""
optNum="21"

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
	local opts="" retval=""

	# Create the form.
	. "src/form.sh"

	retval="$?"
	echo "$opts"

	return "$retval"
}

getConfig()
{
	options=$(displayForm "GNUpot setup" "Use arrow up and down \
to move between fields" "80")
}

strTok()
{
	local FORMVARIABLES="gnupotServer gnupotServerPort \
gnupotServerUsername gnupotRemoteDir gnupotLocalDir gnupotSSHKeyPath \
gnupotRSAKeyBits gnupotKeepMaxCommits gnupotInotifyFileExclude \
gnupotGitFileExclude gnupotGitCommitterUsername gnupotGitCommitterEmail \
gnupotTimeToWaitForOtherChanges gnupotBusyWaitTime \
gnupotSSHServerAliveInterval gnupotSSHServerAliveCountMax \
gnupotSSHMasterSocketPath gnupotNotificationTime gnupotLockFilePath \
gnupotDownloadSpeed gnupotUploadSpeed"

	# Control bash version to avoid IFS bug. bash <=4.2 has this bug. If
	# bash is <=4.2 spaces must be avoided in form fields.
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
	[ $i -eq $optNum ] && return 0 || return 1
}

genSSHKey()
{
	if [ ! -r "$SSHKeyPath" ]; then
		infoMsg "infobox" "Generating SSH keys. Please wait."
		ssh-keygen -t rsa -b "$gnupotRSAKeyBits" -C \
"gnupot:$USER@$HOSTNAME:$(date -I)" -f "$gnupotSSHKeyPath" -N "" -q
	fi
	infoMsg "msgbox" "You will now be prompted for \
"$gnupotServerUsername"'s password..."
	ssh-copy-id -p "$gnupotServerPort" -i ""$gnupotSSHKeyPath".pub" \
"$gnupotServerUsername"@"$gnupotServer"

	# Check if SSH works and if remote programs exist.
	ssh -p "$gnupotServerPort" -o PasswordAuthentication=no \
-i "$gnupotSSHKeyPath" \
"$gnupotServerUsername"@"$gnupotServer" "$REMOTECHKCMD" 1>&- 2>&-

	return "$?"
}

testInfo()
{
	# Check if SSH and remote programs already works.
	{ ssh -p "$gnupotServerPort" \
"$gnupotServerUsername"@"$gnupotServer" \
-o PasswordAuthentication=no 2>&1 | grep denied &>/dev/null \
&& ssh -p "$gnupotServerPort" -o PasswordAuthentication=no \
-i "$gnupotSSHKeyPath" \
"$gnupotServerUsername"@"$gnupotServer" "$REMOTECHKCMD" 1>&- 2>&- \
|| genSSHKey; } \
|| { infoMsg "msgbox" "SSH problem or git and/or \
inotifywait missing on server. Please read the wiki at \
https://github.com/frnmst/gnupot/wiki/"; return 1; }

	return 0
}

# Local configuration directory.
initConfigDir()
{
	mkdir -p "$CONFIGDIRPATH" && chmod 600 "$CONFIGDIRPATH" \
|| { infoMsg "msgbox" "Cannot create configuration directory."; return 1; }
}

# Initialize remote repository, which is bare and allows fast forwards (useful
# for deleting old history.
initRepo()
{
	ssh -p "$gnupotServerPort" -i "$gnupotSSHKeyPath" \
"$gnupotServerUsername"@"$gnupotServer" \
"if [ ! -d "$gnupotRemoteDir" ]; then mkdir -p "$gnupotRemoteDir" \
&& git -C "$gnupotRemoteDir" init --bare --shared; fi \
&& git -C "$gnupotRemoteDir" config --system receive.denyNonFastForwards \
false" 1>&- 2>&-
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
}

updateRepo()
{
	# Check if repo path coincides with the one written in the conf file.
	# Push and pull so that history is even.
	[ "$(git -C "$gnupotLocalDir" config --get remote.origin.url)" = \
"$gnupotServerUsername"@"$gnupotServer":"$gnupotRemoteDir" ] || return 1

	[ "$(git -C "$gnupotLocalDir" status --porcelain | wc -m)" -gt 0 ] \
&& { git -C "$gnupotLocalDir" add -A 1>&- 2>&-; \
git -C "$gnupotLocalDir" commit -am "Update merge by "$USER"." 1>&- 2>&-; }

	{ git -C "$gnupotLocalDir" pull origin master 1>&- 2>&- \
&& git -C "$gnupotLocalDir" push origin master 1>&- 2>&-; } \
|| return 1

	return 0
}

cloneRepo()
{
	# The following is a global variable.
	GIT_SSH_COMMAND="ssh -p $gnupotServerPort -i $gnupotSSHKeyPath"

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
gnupotServerPort=\""$gnupotServerPort"\"\n\
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
" > "$CONFIGFILEPATH"

	chmod 600 "$CONFIGFILEPATH"

	return 0
}

mainSetup()
{
	# Trap signals so that CTRL+C aborts setup.
	trap "infoMsg "infobox" 'Exited from setup.'; exit 1" SIGINT SIGTERM

	while true; do
		getConfig || return 1
		verifyConfig || { mainSetup; return 0; }
		strTok
		parseConfig || { infoMsg "msgbox" "Value/s type invalid."; \
$(return 1); }
		[ "$?" -ne 0 ] && { mainSetup; return 0; }
		displayForm "GNUpot setup summary" "Are the displayed values \
correct?" "0" || { mainSetup; return 0; }
		initConfigDir || { mainSetup; return 0; }
		testInfo || { mainSetup; return 0; }
		initRepo
		cloneRepo || { mainSetup; return 0; }
		writeConfigFile
		[ -n "$DISPLAY" ] && bash -c "notify-send -t 2000 \
'GNUpot setup completed.'"
		infoMsg "msgbox" "Setup completed."
		return 0
	done
}

initConfigDir && lockOnFile "$CONFIGFILEPATH" || exit 1

# Load default variables.
. "src/configVariables.conf" \
|| { Err "Cannot start setup. No variables file found.\n"; exit 1; }

# Load variables file if gnupot.config already exists.
[ -r "$CONFIGFILEPATH" ] && . "$CONFIGFILEPATH"

mainSetup

exit "$?"
