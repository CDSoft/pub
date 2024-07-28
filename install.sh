#!/bin/sh
######################################################################
# This file is part of luax.
#
# luax is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# luax is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with luax.  If not, see <https://www.gnu.org/licenses/>.
#
# For further information about luax you can visit
# http://cdelord.fr/luax and http://cdelord.fr/pub
######################################################################


ARCHIVE_NAME="@(ARCHIVE_NAME)"
ARCHIVE_URL="@(URL)/$ARCHIVE_NAME"

set -e

[ -z "$PREFIX" ] && PREFIX=~/.local
if ! [ -d $PREFIX ]
then
    echo "$PREFIX: not a directory"
    exit 1
fi

tmp="$(mktemp --directory --tmpdir luax.XXXXXX)"
archive="$tmp/$ARCHIVE_NAME"
trap 'rm -rf "$tmp"' EXIT
echo "Download $ARCHIVE_URL"
curl --progress-bar --fail --output "$archive" "$ARCHIVE_URL"
echo "Install LuaX in $PREFIX"
tar xJvf "$archive" -C "$PREFIX" --preserve-order
