#!/bin/bash

#
# gnupot.sh
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


# Save the current option settings.
savedEnv="$(set +o)"

# set -m: The same as setsid. It changes the process group so it's not equal to
# the parents' one. This way, even if GNUpot is killed the parent process will
# not be affected (i.e. not killed when GNUpot is killed).
# set -a: Enable automatic export of all variables form now on.
# This avoids putting "export" in front of every variable.
set -ma

# Set paths and constants.
procNum="3"
PATH="$PATH":/usr/bin
CONFIGDIRPATH=""$HOME"/.config/gnupot"
CONFIGFILEPATH=""$CONFIGDIRPATH"/gnupot.config"

##############################################################################
##############################################################################
##############################################################################

# You can edit the following variables (with caution).
# List of installed programs that GNUpot uses. If display variable is
# set notify-send is also required.
PROGRAMS="bash ssh inotifywait flock git getent trickle"
[ -n "$DISPLAY" ] && PROGRAMS="$PROGRAMS notify-send"
# Subset of the commit message.
USERDATA="by "$USER"@"$HOSTNAME"."

# Source functions file.
. ""${0%/gnupot}"/src/functions.sh"

# Update Dbus environment so that notification will be shown.
[ -x "/usr/bin/dbus-update-activation-environment" ] \
&& /usr/bin/dbus-update-activation-environment DISPLAY

parseOpts "$0" "$1"; retval="$?"
# Restore the previous option settings.
$savedEnv

exit "$retval"
