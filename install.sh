#!/usr/bin/env sh

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
