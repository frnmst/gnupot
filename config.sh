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


# SETUP TODO WITH dialog/Xdialog.

