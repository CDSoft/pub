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

CACHE=cache
DIST="$CACHE/dist"
DIST_LUAX="$DIST/luax"
DIST_FULL="$DIST/full"
PUB=pub

ROOT="$(realpath "$(dirname "$0")")"

set -e

###############################################################################
# Versions
###############################################################################

tag()
{
    local repo="$1"
    local request="https://api.github.com/repos/$repo/releases/latest"
    local tag_file
    tag_file="$CACHE/tags/$(basename "$repo")"
    mkdir -p "$(dirname "$tag_file")"
    local age=$(( $(date +%s) - $(stat -c %Y -- "$tag_file" 2>/dev/null || echo 0) ))
    if [ "$age" -gt 7200 ]
    then
        curl -sSL "$request" | jq -r .tag_name > "$tag_file"
        touch "$tag_file"
    fi
    cat "$tag_file"
}

ZIG_VERSION=0.13.0
LZ4_VERSION="$(tag lz4/lz4 | sed 's/^v//')"
LZIP_VERSION=1.24.1
LZLIB_VERSION=1.14
TARLZ_VERSION=0.25
PLZIP_VERSION=1.11
DITAA_VERSION="$(tag stathissideris/ditaa | sed 's/^v//')"
PLANTUML_VERSION="$(tag plantuml/plantuml | sed 's/^v//')"
PANDOC_VERSION="$(tag jgm/pandoc | sed 's/^v//')"
TYPST_VERSION="$(tag typst/typst | sed 's/^v//')"

###############################################################################
# Install necessary tools on the host
###############################################################################

CFLAGS=(
    -O2
    -s
)

ext()
{
    case "$1" in
        windows-*) echo ".exe" ;;
    esac
}

zig_target()
{
    case "$1" in
        linux-x86_64)       echo x86_64-linux-gnu ;;
        linux-x86_64-musl)  echo x86_64-linux-musl ;;
        linux-aarch64)      echo aarch64-linux-gnu ;;
        linux-aarch64-musl) echo aarch64-linux-musl ;;
        macos-x86_64)       echo x86_64-macos-none ;;
        macos-aarch64)      echo aarch64-macos-none ;;
        windows-x86_64)     echo x86_64-windows-gnu ;;
        *)                  echo "$1";;
    esac
}

gitclone()
{
    local URL="$1"
    local DIR="$2"
    [ -d "$DIR" ] || git clone "$URL" "$DIR"
    ( cd "$DIR" && git fetch && git rebase )
}

download()
{
    local URL="$1"
    local DIR="$2"
    [ -f "$DIR" ] || curl -fsSL "$URL" -o "$DIR"
}

# LuaX

gitclone https://github.com/CDSoft/luax $CACHE/luax
(   cd $CACHE/luax
    ./bootstrap.sh
    ninja install
)
eval "$(~/.local/bin/luax env)"

# Zig (installed by LuaX)

ZIG="$HOME/.local/opt/zig/$ZIG_VERSION/zig"

# Bang

gitclone https://github.com/CDSoft/bang $CACHE/bang
(   cd $CACHE/bang
    [ -f ext/ninja/README.md ] || ( git submodule sync && git submodule update --init --recursive )
    ninja install
)

# ypp

gitclone https://github.com/CDSoft/ypp $CACHE/ypp
(   cd $CACHE/ypp
    ninja install
)

# lz4

LZ4_ARCHIVE="v$LZ4_VERSION.zip"
LZ4_URL="https://github.com/lz4/lz4/archive/refs/tags/$LZ4_ARCHIVE"
LZ4_PATH="$CACHE/lz4"
LZ4_SRC="$LZ4_PATH/lz4-$LZ4_VERSION"

mkdir -p "$LZ4_PATH"

download "$LZ4_URL" "$LZ4_PATH/lz4-$LZ4_ARCHIVE"
[ -d "$LZ4_SRC" ] || unzip -u "$LZ4_PATH/lz4-$LZ4_ARCHIVE" -d "$LZ4_PATH"
[ -x "$LZ4_SRC/lz4" ] || $ZIG cc "${CFLAGS[@]}" \
    -I"$LZ4_SRC/lib" \
    "$LZ4_SRC"/{programs,lib}/*.c -o "$LZ4_SRC/lz4"
install "$LZ4_SRC/lz4" "$HOME/.local/bin/"

# lzip

LZIP_ARCHIVE="lzip-$LZIP_VERSION.tar.gz"
LZIP_URL="http://download.savannah.gnu.org/releases/lzip/$LZIP_ARCHIVE"
LZIP_PATH="$CACHE/lzip"
LZIP_SRC="$LZIP_PATH/lzip-$LZIP_VERSION"

mkdir -p "$LZIP_PATH"

download "$LZIP_URL" "$LZIP_PATH/$LZIP_ARCHIVE"
[ -d "$LZIP_SRC" ] || tar xzf "$LZIP_PATH/$LZIP_ARCHIVE" -C "$LZIP_PATH"
[ -x "$LZIP_SRC/lzip" ] || $ZIG c++ "${CFLAGS[@]}" \
    -DPROGVERSION="\"$LZIP_VERSION\"" \
    "$LZIP_SRC"/*.cc -o "$LZIP_SRC/lzip"
install "$LZIP_SRC/lzip" "$HOME/.local/bin/"

# lzlib

LZLIB_ARCHIVE="lzlib-$LZLIB_VERSION.tar.lz"
LZLIB_URL="http://download.savannah.gnu.org/releases/lzip/lzlib/$LZLIB_ARCHIVE"
LZLIB_PATH="$CACHE/lzlib"
LZLIB_SRC="$LZLIB_PATH/lzlib-$LZLIB_VERSION"

mkdir -p "$LZLIB_PATH"

download "$LZLIB_URL" "$LZLIB_PATH/$LZLIB_ARCHIVE"
[ -d "$LZLIB_SRC" ] || tar --lzip -xf "$LZLIB_PATH/$LZLIB_ARCHIVE" -C "$LZLIB_PATH"
[ -f "$LZLIB_SRC/lzlib.o" ] || $ZIG cc -c "${CFLAGS[@]}" \
    "$LZLIB_SRC/lzlib.c" -o "$LZLIB_SRC/lzlib.o"

# tarlz

TARLZ_ARCHIVE="tarlz-$TARLZ_VERSION.tar.lz"
TARLZ_URL="http://download.savannah.gnu.org/releases/lzip/tarlz/$TARLZ_ARCHIVE"
TARLZ_PATH="$CACHE/tarlz"
TARLZ_SRC="$TARLZ_PATH/tarlz-$TARLZ_VERSION"

mkdir -p "$TARLZ_PATH"

download "$TARLZ_URL" "$TARLZ_PATH/$TARLZ_ARCHIVE"
[ -d "$TARLZ_SRC" ] || tar --lzip -xf "$TARLZ_PATH/$TARLZ_ARCHIVE" -C "$TARLZ_PATH"
[ -x "$TARLZ_SRC/tarlz" ] || $ZIG c++ "${CFLAGS[@]}" \
    -DPROGVERSION="\"$TARLZ_VERSION\"" \
    -I"$LZLIB_SRC" \
    "$LZLIB_SRC/lzlib.o" \
    "$TARLZ_SRC"/*.cc -o "$TARLZ_SRC/tarlz"
install "$TARLZ_SRC/tarlz" "$HOME/.local/bin/"

# plzip

PLZIP_ARCHIVE="plzip-$PLZIP_VERSION.tar.lz"
PLZIP_URL="http://download.savannah.gnu.org/releases/lzip/plzip/$PLZIP_ARCHIVE"
PLZIP_PATH="$CACHE/plzip"
PLZIP_SRC="$PLZIP_PATH/plzip-$PLZIP_VERSION"

mkdir -p "$PLZIP_PATH"

download "$PLZIP_URL" "$PLZIP_PATH/$PLZIP_ARCHIVE"
[ -d "$PLZIP_SRC" ] || tar --lzip -xf "$PLZIP_PATH/$PLZIP_ARCHIVE" -C "$PLZIP_PATH"
[ -x "$PLZIP_SRC/plzip" ] || $ZIG c++ "${CFLAGS[@]}" \
    -DPROGVERSION="\"$PLZIP_VERSION\"" \
    -I"$LZLIB_SRC" \
    "$LZLIB_SRC/lzlib.o" \
    "$PLZIP_SRC"/*.cc -o "$PLZIP_SRC/plzip"
install "$PLZIP_SRC/plzip" "$HOME/.local/bin/"

###############################################################################
# LuaX
###############################################################################

readarray -t TARGETS < <( luax -e 'require"targets":foreach(function(t) print(t.name) end)' )

for target in "${TARGETS[@]}"
do
    mkdir -p "$DIST_LUAX/$target"/{bin,lib}
    mkdir -p "$DIST_FULL/$target"/{bin,lib}
    cp -f "$CACHE/luax/.build/dist/$target/bin"/* "$DIST_LUAX/$target/bin/"
    cp -f "$CACHE/luax/.build/dist/$target/lib"/* "$DIST_LUAX/$target/lib/"
    cp -f "$CACHE/luax/.build/dist/$target/bin"/* "$DIST_FULL/$target/bin/"
    cp -f "$CACHE/luax/.build/dist/$target/lib"/* "$DIST_FULL/$target/lib/"
done

###############################################################################
# lz4
###############################################################################

for target in "${TARGETS[@]}"
do
    exe=$(ext "$target")
    mkdir -p "$LZ4_SRC/$target"
    [ -x "$LZ4_SRC/$target/lz4$exe" ] || $ZIG cc -target "$(zig_target "$target")" "${CFLAGS[@]}" \
        -I"$LZ4_SRC/lib" \
        "$LZ4_SRC"/{programs,lib}/*.c -o "$LZ4_SRC/$target/lz4$exe"
    cp -f "$LZ4_SRC/$target/lz4$exe" "$DIST_FULL/$target/bin/"
done

###############################################################################
# lzip
###############################################################################

for target in "${TARGETS[@]}"
do
    exe=$(ext "$target")

    mkdir -p "$LZIP_SRC/$target"
    [ -x "$LZIP_SRC/$target/lzip$exe" ] || $ZIG c++ -target "$(zig_target "$target")" "${CFLAGS[@]}" \
        -DPROGVERSION="\"$LZIP_VERSION\"" \
        "$LZIP_SRC"/*.cc -o "$LZIP_SRC/$target/lzip$exe"
    cp -f "$LZIP_SRC/$target/lzip$exe" "$DIST_FULL/$target/bin/"

    case "$target" in
        windows-*)  continue ;; # tarlz and plzip are not compiled for Windows
    esac

    mkdir -p "$LZLIB_SRC/$target"
    [ -f "$LZLIB_SRC/$target/lzlib.o" ] || $ZIG cc -c -target "$(zig_target "$target")" "${CFLAGS[@]}" \
        "$LZLIB_SRC/lzlib.c" -o "$LZLIB_SRC/$target/lzlib.o"

    mkdir -p "$TARLZ_SRC/$target"
    [ -x "$TARLZ_SRC/$target/tarlz$exe" ] || $ZIG c++ -target "$(zig_target "$target")" "${CFLAGS[@]}" \
        -DPROGVERSION="\"$TARLZ_VERSION\"" \
        -I"$LZLIB_SRC" \
        "$LZLIB_SRC/$target/lzlib.o" \
        "$TARLZ_SRC"/*.cc -o "$TARLZ_SRC/$target/tarlz$exe"
    cp -f "$TARLZ_SRC/$target/tarlz$exe" "$DIST_FULL/$target/bin/"

    mkdir -p "$PLZIP_SRC/$target"
    [ -x "$PLZIP_SRC/$target/plzip$exe" ] || $ZIG c++ -target "$(zig_target "$target")" "${CFLAGS[@]}" \
        -DPROGVERSION="\"$PLZIP_VERSION\"" \
        -I"$LZLIB_SRC" \
        "$LZLIB_SRC/$target/lzlib.o" \
        "$PLZIP_SRC"/*.cc -o "$PLZIP_SRC/$target/plzip$exe"
    cp -f "$PLZIP_SRC/$target/plzip$exe" "$DIST_FULL/$target/bin/"

done

###############################################################################
# bang
###############################################################################

for target in "${TARGETS[@]}"
do
    exe=$(ext "$target")
    (   cd $CACHE/bang
        bang -o "build-$target.ninja" -- "$target"
        PREFIX=$ROOT/$DIST_LUAX/$target ninja -f "build-$target.ninja" install
        PREFIX=$ROOT/$DIST_FULL/$target ninja -f "build-$target.ninja" install
    )
done

###############################################################################
# Calculadoira
###############################################################################

gitclone https://github.com/CDSoft/calculadoira $CACHE/calculadoira

for target in "${TARGETS[@]}"
do
    exe=$(ext "$target")
    (   cd $CACHE/calculadoira
        bang -o "build-$target.ninja" -- "$target"
        PREFIX=$ROOT/$DIST_LUAX/$target ninja -f "build-$target.ninja" install
        PREFIX=$ROOT/$DIST_FULL/$target ninja -f "build-$target.ninja" install
    )
done

###############################################################################
# lsvg
###############################################################################

gitclone https://github.com/CDSoft/lsvg $CACHE/lsvg

for target in "${TARGETS[@]}"
do
    exe=$(ext "$target")
    (   cd $CACHE/lsvg
        bang -o "build-$target.ninja" -- "$target"
        PREFIX=$ROOT/$DIST_LUAX/$target ninja -f "build-$target.ninja" install
        PREFIX=$ROOT/$DIST_FULL/$target ninja -f "build-$target.ninja" install
    )
done

###############################################################################
# tagref
###############################################################################

gitclone https://github.com/CDSoft/tagref $CACHE/tagref

for target in "${TARGETS[@]}"
do
    exe=$(ext "$target")
    (   cd $CACHE/tagref
        bang -o "build-$target.ninja" -- "$target"
        PREFIX=$ROOT/$DIST_LUAX/$target ninja -f "build-$target.ninja" install
        PREFIX=$ROOT/$DIST_FULL/$target ninja -f "build-$target.ninja" install
    )
done

###############################################################################
# ypp
###############################################################################

gitclone https://github.com/CDSoft/ypp $CACHE/ypp

for target in "${TARGETS[@]}"
do
    exe=$(ext "$target")
    (   cd $CACHE/ypp
        bang -o "build-$target.ninja" -- "$target"
        PREFIX=$ROOT/$DIST_LUAX/$target ninja -f "build-$target.ninja" install
        PREFIX=$ROOT/$DIST_FULL/$target ninja -f "build-$target.ninja" install
    )
done

###############################################################################
# panda
###############################################################################

gitclone https://github.com/CDSoft/panda $CACHE/panda

for target in "${TARGETS[@]}"
do
    exe=$(ext "$target")
    (   cd $CACHE/panda
        bang -o "build-$target.ninja" -- "$target"
        PREFIX=$ROOT/$DIST_LUAX/$target ninja -f "build-$target.ninja" install
        PREFIX=$ROOT/$DIST_FULL/$target ninja -f "build-$target.ninja" install
    )
done

###############################################################################
# Ditaa
###############################################################################

DITAA_ARCHIVE="ditaa-${DITAA_VERSION}-standalone.jar"
DITAA_URL="https://github.com/stathissideris/ditaa/releases/download/v${DITAA_VERSION}/$DITAA_ARCHIVE"

download "$DITAA_URL" "$CACHE/$DITAA_ARCHIVE"

for target in "${TARGETS[@]}"
do
    ln -f "$CACHE/$DITAA_ARCHIVE" "$DIST_FULL/$target/bin/ditaa.jar"
done

###############################################################################
# PlantUML
###############################################################################

PLANTUML_ARCHIVE="plantuml-pdf-${PLANTUML_VERSION}.jar"
PLANTUML_URL="https://github.com/plantuml/plantuml/releases/download/v${PLANTUML_VERSION}/$PLANTUML_ARCHIVE"

download "$PLANTUML_URL" "$CACHE/$PLANTUML_ARCHIVE"

for target in "${TARGETS[@]}"
do
    ln -f "$CACHE/$PLANTUML_ARCHIVE" "$DIST_FULL/$target/bin/plantuml.jar"
done

###############################################################################
# Pandoc
###############################################################################

for target in "${TARGETS[@]}"
do
    mkdir -p "$CACHE/pandoc/$target"
    case "$target" in
        (linux-x86_64*)
            PANDOC_URL=https://github.com/jgm/pandoc/releases/download/$PANDOC_VERSION/pandoc-$PANDOC_VERSION-linux-amd64.tar.gz
            download "$PANDOC_URL" "$CACHE/pandoc/$(basename "$PANDOC_URL")"
            [ -d "$CACHE/pandoc/$target/pandoc-$PANDOC_VERSION" ] || tar -C "$CACHE/pandoc/$target/" -xzf "$CACHE/pandoc/$(basename "$PANDOC_URL")" --preserve-order
            ln -f "$CACHE/pandoc/$target/pandoc-$PANDOC_VERSION/bin"/* "$DIST_FULL/$target/bin/"
            ;;
        (linux-aarch64*)
            PANDOC_URL=https://github.com/jgm/pandoc/releases/download/$PANDOC_VERSION/pandoc-$PANDOC_VERSION-linux-arm64.tar.gz
            download "$PANDOC_URL" "$CACHE/pandoc/$(basename "$PANDOC_URL")"
            [ -d "$CACHE/pandoc/$target/pandoc-$PANDOC_VERSION" ] || tar -C "$CACHE/pandoc/$target/" -xzf "$CACHE/pandoc/$(basename "$PANDOC_URL")" --preserve-order
            ln -f "$CACHE/pandoc/$target/pandoc-$PANDOC_VERSION/bin"/* "$DIST_FULL/$target/bin/"
            ;;
        (windows-x86_64*)
            PANDOC_URL=https://github.com/jgm/pandoc/releases/download/$PANDOC_VERSION/pandoc-$PANDOC_VERSION-windows-x86_64.zip
            download "$PANDOC_URL" "$CACHE/pandoc/$(basename "$PANDOC_URL")"
            [ -d "$CACHE/pandoc/$target/pandoc-$PANDOC_VERSION" ] || unzip -o -q "$CACHE/pandoc/$(basename "$PANDOC_URL")" -d "$CACHE/pandoc/$target/"
            ln -f "$CACHE/pandoc/$target/pandoc-$PANDOC_VERSION"/*.exe "$DIST_FULL/$target/bin/"
            ;;
        (macos-x86_64*)
            PANDOC_URL=https://github.com/jgm/pandoc/releases/download/$PANDOC_VERSION/pandoc-$PANDOC_VERSION-x86_64-macOS.zip
            download "$PANDOC_URL" "$CACHE/pandoc/$(basename "$PANDOC_URL")"
            [ -d "$CACHE/pandoc/$target/pandoc-$PANDOC_VERSION" ] || unzip -o -q "$CACHE/pandoc/$(basename "$PANDOC_URL")" -d "$CACHE/pandoc/$target/"
            ln -f "$CACHE/pandoc/$target/pandoc-$PANDOC_VERSION-x86_64/bin"/* "$DIST_FULL/$target/bin/"
            ;;
        (macos-aarch64*)
            PANDOC_URL=https://github.com/jgm/pandoc/releases/download/$PANDOC_VERSION/pandoc-$PANDOC_VERSION-arm64-macOS.zip
            download "$PANDOC_URL" "$CACHE/pandoc/$(basename "$PANDOC_URL")"
            [ -d "$CACHE/pandoc/$target/pandoc-$PANDOC_VERSION" ] || unzip -o -q "$CACHE/pandoc/$(basename "$PANDOC_URL")" -d "$CACHE/pandoc/$target/"
            ln -f "$CACHE/pandoc/$target/pandoc-$PANDOC_VERSION-arm64/bin"/* "$DIST_FULL/$target/bin/"
            ;;
        (*) echo "$target: unsupported platform for Pandoc"; exit 1 ;;
    esac
done

###############################################################################
# Typst
###############################################################################

for target in "${TARGETS[@]}"
do
    mkdir -p "$CACHE/typst/$TYPST_VERSION/$target"
    case "$target" in
        (linux-x86_64*)
            TYPST_URL=https://github.com/typst/typst/releases/download/v$TYPST_VERSION/typst-x86_64-unknown-linux-musl.tar.xz
            download "$TYPST_URL" "$CACHE/typst/$TYPST_VERSION/$(basename "$TYPST_URL")"
            [ -d "$CACHE/typst/$TYPST_VERSION/$target/typst-x86_64-unknown-linux-musl" ] || tar -C "$CACHE/typst/$TYPST_VERSION/$target" -xJf "$CACHE/typst/$TYPST_VERSION/$(basename "$TYPST_URL")" --preserve-order
            ln -f "$CACHE/typst/$TYPST_VERSION/$target/typst-x86_64-unknown-linux-musl/typst" "$DIST_FULL/$target/bin/"
            ;;
        (linux-aarch64*)
            TYPST_URL=https://github.com/typst/typst/releases/download/v$TYPST_VERSION/typst-aarch64-unknown-linux-musl.tar.xz
            download "$TYPST_URL" "$CACHE/typst/$TYPST_VERSION/$(basename "$TYPST_URL")"
            [ -d "$CACHE/typst/$TYPST_VERSION/$target/typst-aarch64-unknown-linux-musl" ] || tar -C "$CACHE/typst/$TYPST_VERSION/$target" -xJf "$CACHE/typst/$TYPST_VERSION/$(basename "$TYPST_URL")" --preserve-order
            ln -f "$CACHE/typst/$TYPST_VERSION/$target/typst-aarch64-unknown-linux-musl/typst" "$DIST_FULL/$target/bin/"
            ;;
        (windows-x86_64*)
            TYPST_URL=https://github.com/typst/typst/releases/download/v$TYPST_VERSION/typst-x86_64-pc-windows-msvc.zip
            download "$TYPST_URL" "$CACHE/typst/$TYPST_VERSION/$(basename "$TYPST_URL")"
            [ -d "$CACHE/typst/$TYPST_VERSION/$target/typst-x86_64-pc-windows-msvc" ] || unzip -o -q "$CACHE/typst/$TYPST_VERSION/$(basename "$TYPST_URL")" -d "$CACHE/typst/$TYPST_VERSION/$target/"
            ln -f "$CACHE/typst/$TYPST_VERSION/$target/typst-x86_64-pc-windows-msvc/typst.exe" "$DIST_FULL/$target/bin/"
            ;;
        (macos-x86_64*)
            TYPST_URL=https://github.com/typst/typst/releases/download/v$TYPST_VERSION/typst-x86_64-apple-darwin.tar.xz
            download "$TYPST_URL" "$CACHE/typst/$TYPST_VERSION/$(basename "$TYPST_URL")"
            [ -d "$CACHE/typst/$TYPST_VERSION/$target/typst-x86_64-apple-darwin" ] || tar -C "$CACHE/typst/$TYPST_VERSION/$target" -xJf "$CACHE/typst/$TYPST_VERSION/$(basename "$TYPST_URL")" --preserve-order
            ln -f "$CACHE/typst/$TYPST_VERSION/$target/typst-x86_64-apple-darwin/typst" "$DIST_FULL/$target/bin/"
            ;;
        (macos-aarch64*)
            TYPST_URL=https://github.com/typst/typst/releases/download/v$TYPST_VERSION/typst-aarch64-apple-darwin.tar.xz
            download "$TYPST_URL" "$CACHE/typst/$TYPST_VERSION/$(basename "$TYPST_URL")"
            [ -d "$CACHE/typst/$TYPST_VERSION/$target/typst-aarch64-apple-darwin" ] || tar -C "$CACHE/typst/$TYPST_VERSION/$target" -xJf "$CACHE/typst/$TYPST_VERSION/$(basename "$TYPST_URL")" --preserve-order
            ln -f "$CACHE/typst/$TYPST_VERSION/$target/typst-aarch64-apple-darwin/typst" "$DIST_FULL/$target/bin/"
            ;;
        (*) echo "$target: unsupported platform for Typst"; exit 1 ;;
    esac
done

###############################################################################
# Archives
###############################################################################

mkdir -p "$PUB"

OPT_XZ=(
    --use-compress-program='xz -6'
    --sort=name
)
OPT_GZ=(
    --use-compress-program='gzip -9'
    --sort=name
)
OPT_ZIP=(
    -9
)

for target in "${TARGETS[@]}"
do
    ( cd "$DIST_LUAX/$target" && tar -cvf "$ROOT/$PUB/luax-$target.tar.xz"      "${OPT_XZ[@]}" bin lib ) &
    ( cd "$DIST_FULL/$target" && tar -cvf "$ROOT/$PUB/luax-full-$target.tar.xz" "${OPT_XZ[@]}" bin lib ) &

    #( cd "$DIST_LUAX/$target" && tar -cvf "$ROOT/$PUB/luax-$target.tar.gz"      "${OPT_GZ[@]}" bin lib ) &
    #( cd "$DIST_FULL/$target" && tar -cvf "$ROOT/$PUB/luax-full-$target.tar.gz" "${OPT_GZ[@]}" bin lib ) &

    case "$target" in
        windows-*)
            rm -f "$ROOT/$PUB/luax-$target.zip"
            rm -f "$ROOT/$PUB/luax-full-$target.zip"
            ( cd "$DIST_LUAX/$target" &&  zip -r "${OPT_ZIP[@]}" "$ROOT/$PUB/luax-$target.zip" bin lib ) &
            ( cd "$DIST_FULL/$target" &&  zip -r "${OPT_ZIP[@]}" "$ROOT/$PUB/luax-full-$target.zip" bin lib ) &
            ;;
    esac
done
wait

###############################################################################
# Index
###############################################################################

ypp -l index.lua index.md -o "$PUB/index.md"

#pandoc --standalone "$PUB/index.md" -o "$PUB/index.html"
