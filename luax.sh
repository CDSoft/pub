#!/bin/bash
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

set -e

######################################################################
# OS detection
######################################################################

ARCH="$(uname -m)"
case "$ARCH" in
    (arm64) ARCH=aarch64 ;;
esac
case "$(uname -s)" in
    (Linux)  OS=linux ;;
    (Darwin) OS=macos ;;
    (MINGW*) OS=windows ;;
    (*)      OS=unknown ;;
esac

case "$OS-$ARCH" in
    (linux-x86_64|linux-aarch64|macos-x86_64|macos-aarch64|windows-x86_64) TARGET="$OS-$ARCH" ;;
    (*) echo "Unknown target: $OS-$ARCH"; exit 1 ;;
esac

######################################################################
# Installation prefix
######################################################################

[ -z "$PREFIX" ] && PREFIX=~/.local
if ! [ -d "$PREFIX" ]
then
    echo "$PREFIX: not a directory"
    exit 1
fi

######################################################################
# LuaX installation
######################################################################

ARCHIVE_NAME="@(SCHEME)-$TARGET.tar.xz"
ARCHIVE_URL="@(URL)/$ARCHIVE_NAME"

tmp="$(mktemp --directory --tmpdir luax.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/$ARCHIVE_NAME"
echo "Download $ARCHIVE_URL"
curl --progress-bar --fail --output "$archive" "$ARCHIVE_URL"
echo "Install LuaX in $PREFIX"
tar xJvf "$archive" -C "$PREFIX" --preserve-order
