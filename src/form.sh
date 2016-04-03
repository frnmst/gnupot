#
# form.sh
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


# This file is sourced from config.sh and contains the form for the setup.

local title="$1" arg="$2" action="$3" fldChrs="50"

opts=$($DIALOG --title "$title" \
--form "$arg" \
"$winY" "$winX" 0 \
"Server address or hostname:"           1 1 "$gnupotServer"     1 $fldChrs \
$action 0 \
"Server port:"                          2 1 "$gnupotServerPort" 2 $fldChrs \
$action 0 \
"Remote user name:"                     3 1 "$gnupotServerUsername" \
3 $fldChrs $action 0 \
"Remote directory path:"                4 1 "$gnupotRemoteDir"  4 $fldChrs \
$action 0 \
"Local directory full path:"            5 1 "$gnupotLocalDir"   5 $fldChrs \
$action 0 \
"Local RSA keys full path:"             6 1 "$gnupotSSHKeyPath" 6 $fldChrs \
$action 0 \
"Local RSA keys length (bits):"         7 1 "$gnupotRSAKeyBits" 7 $fldChrs \
$action 0 \
"Backups to keep (#; 0 = keep all):"    8 1 "$gnupotKeepMaxCommits" \
8 $fldChrs $action 0 \
"Exclude file inotify POSIX pattern:"   9 1 "$gnupotInotifyFileExclude" \
9 $fldChrs $action 0 \
"Exclude file git globbing pattern:"    10 1 "$gnupotGitFileExclude" \
10 $fldChrs $action 0 \
"git committer user name:"              11 1 "$gnupotGitCommitterUsername" \
11 $fldChrs $action 0 \
"git committer email:"                  12 1 "$gnupotGitCommitterEmail" \
12 $fldChrs $action 0 \
"Time to wait for file changes (s):"    13 1 \
"$gnupotTimeToWaitForOtherChanges" 13 $fldChrs $action 0 \
"Time to wait on problem (s):"          14 1 "$gnupotBusyWaitTime" \
14 $fldChrs $action 0 \
"SSH server alive interval (s; >= 1):"  15 1 "$gnupotSSHServerAliveInterval" \
15 $fldChrs $action 0 \
"SSH server alive count max (>= 1):" \
16 1 "$gnupotSSHServerAliveCountMax"    16 $fldChrs $action 0 \
"SSH master socket full path:"          17 1 "$gnupotSSHMasterSocketPath" \
17 $fldChrs $action 0 \
"Event notification time (ms):"         18 1 "$gnupotNotificationTime" \
18 $fldChrs $action 0 \
"Lock file full path:"                  19 1 "$gnupotLockFilePath" \
19 $fldChrs $action 0 \
"Download max speed (KB/s) (0 = no limit):" \
20 1 "$gnupotDownloadSpeed" 20 $fldChrs $action 0 \
"Upload max speed (KB/s) (0 = no limit):" \
21 1 "$gnupotUploadSpeed" 21 $fldChrs $action 0 \
"GNUpot icons directory full path:" 22 1 "$gnupotIconsDir" \
22 $fldChrs $action 0 \
)
