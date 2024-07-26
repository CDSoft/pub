#!/bin/bash

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

for target in "${TARGETS[@]}"
do
    OPT=(
        --use-compress-program='xz -6'
        --transform="s#\($DIST_LUAX\|$DIST_FULL\)/$target/##"
    )
    tar -cvf "$PUB/luax-$target.tar.xz"      "${OPT[@]}" "$DIST_LUAX/$target"/* &
    tar -cvf "$PUB/luax-full-$target.tar.xz" "${OPT[@]}" "$DIST_FULL/$target"/* &
done
wait

###############################################################################
# Index
###############################################################################

cat <<\EOF | ypp > "$PUB/index.md"
% LuaX binaries
% @@( os.setlocale "C"; return os.date "%D" )

@@[[
local url = "https://cdelord.fr/pub"

function size(name)
    local s = fs.stat(name).size
    if s >= 1024*1024 then return ("%d&nbsp;MB"):format(s//(1024*1024)) end
    return ("%d&nbsp;KB"):format(s//(1024))
end

function t(name)
    local bins = {
        "| Target        | Installation                                  | Size |",
        "| :------------ | :-------------------------------------------- | ---: |",
    }
    local targets = require "targets"
    targets : foreach(function(target)
        local archive = name.."-"..target.name..".tar.xz"
        local script = name.."-"..target.name..".sh"
        local install = "`curl -s "..url/script.." | sh`"
        bins[#bins+1] = "| "..F{
            "["..target.name.."]("..url/archive..")",
            install,
            size("pub"/archive)
        }:str" | ".." |"
        local i = (F.I % "@()") {
            ARCHIVE_NAME = archive,
            URL = url,
        }
        fs.write("pub"/script, i[===[
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
]===])
    end)
    return bins
end
]]

## Installation from sources

It is highly recommended to build LuaX and friends from sources instead of relying on possibly outdated binaries.
If you still prefer to download archives of prebuild LuaX binaries,
you can jump to [LuaX light](#luax-light) or [LuaX full](#luax-full).

For the bravest, here are instructions to compile and install LuaX.

### Prerequisites

To compile LuaX from scratch, you first need:

- [Ninja](https://ninja-build.org/)

### Installation path

These softwares are installed by default in `~/.local/bin` and `~/.local/lib`.
If the environment variable `PREFIX` is defined, they are installed in `$PREFIX/bin` and `$PREFIX/lib`.

``` sh
$ export PREFIX=install/path
```

### LuaX

``` sh
$ git clone https://github.com/CDSoft/luax
$ cd luax
$ ./bootstrap && ninja install
$ cd ..
```

The next command sets some LuaX variables (`PATH`, `LUA_PATH`, `LUA_CPATH`).
It can also be added to your shell configuration (`.bashrc`, `.zshrc`...).

``` sh
$ eval "$(~/.local/bin/luax env)"
```

or

``` sh
$ eval "$($PREFIX/bin/luax env)"
```

### bang

``` sh
$ git clone https://github.com/CDSoft/bang
$ cd bang
$ ninja install
$ cd ..
```

### Calculadoira

``` sh
$ git clone https://github.com/CDSoft/calculadoira
$ cd calculadoira
$ ninja install
$ cd ..
```

### lsvg

``` sh
$ git clone https://github.com/CDSoft/lsvg
$ cd lsvg
$ ninja install
$ cd ..
```

### tagref

``` sh
$ git clone https://github.com/CDSoft/tagref
$ cd tagref
$ ninja install
$ cd ..
```

### ypp

``` sh
$ git clone https://github.com/CDSoft/ypp
$ cd ypp
$ ninja install
$ cd ..
```

### panda

``` sh
$ git clone https://github.com/CDSoft/panda
$ cd panda
$ ninja install
$ cd ..
```

## LuaX light

The light LuaX archives contain LuaX binaries and some tools written in LuaX:

- [LuaX](https://cdelord.fr/luax): Lua interpreter and REPL based on Lua 5.4, augmented with some useful packages. luax can also produce executable scripts from Lua scripts
- [bang](https://cdelord.fr/bang): Ninja file generator scriptable in LuaX
- [Calculadoira](https://cdelord.fr/calculadoira): simple yet powerful calculator
- [lsvg](https://cdelord.fr/lsvg): Lua interpreter specialized to generate SVG images
- [tagref](https://cdelord.fr/tagref): maintain cross-references in your code.
- [ypp](https://cdelord.fr/ypp): generic text preprocessor with macro implemented in LuaX
- [panda](https://cdelord.fr/panda): Pandoc Lua filter that works on internal Pandoc’s AST

@t("luax")

## LuaX full

The full LuaX archives contain the same softwares than the light archives plus some heavier but super useful programs:

- [lz4](https://lz4.org/): lossless compression algorithm, providing fast compression speed and super fast decompression speed
- [lzip](https://www.nongnu.org/lzip/): lossless data compressor with a user interface similar to the one of gzip or bzip2 and using a simplified form of the *'Lempel-Ziv-Markov chain-Algorithm' (LZMA)*
- [ditaa](https://ditaa.sourceforge.net/): small command-line utility written in Java, that can convert diagrams drawn using ascii art, into proper bitmap graphics
- [PlantUML](https://plantuml.com/): highly versatile tool that facilitates the rapid and straightforward creation of a wide array of diagrams
- [Pandoc](https://pandoc.org/): universal document converter
- [Typst](https://typst.app/): compose papers faster, focus on your text and let Typst take care of layout and formatting

@t("luax-full")

EOF

#pandoc --standalone "$PUB/index.md" -o "$PUB/index.html"
