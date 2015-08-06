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


# Save the current option settings.
saveEnv="$(set +o)"
set -x
# set -m: The same as setsid. It changes the process group so it's not equal to
# the parents' one. This way, even if GNUpot is killed the parent process will
# not be affected (i.e. not killed when GNUpot is killed).
# set -a: Enable automatic export of all variables form now on.
# This avoids putting "export" in front of every variable.
set -m; set -a

# Set paths and constants.
PATH="$PATH":/usr/bin
CONFIGFILEPATH=""$HOME"/.config/gnupot/gnupot.config"
procNum="3"

# Source functions file.
. ""${0%/gnupot}"/src/functions.sh"

loadConfig "$1"
checkExecutables
parseOpts "$0" "$@"; retval="$?"
# Restore the previous option settings.
$saveEnv

exit "$retval"
