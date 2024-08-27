% LuaX binaries
% @DATE

@@comment[===[
This file is part of luax.

luax is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

luax is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with luax.  If not, see <https://www.gnu.org/licenses/>.

For further information about luax you can visit
http://cdelord.fr/luax and http://cdelord.fr/pub
]===]

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
$ ./bootstrap.sh && ninja install
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

This command detects the OS and installs LuaX in `$PREFIX/bin` and `$PREFIX/lib` (the default prefix is `~/.local/bin` and `~/.local/lib`):

``` sh
curl https://cdelord.fr/pub/luax.sh | sh
```

If you want to install a specific version (e.g. binaries statically linked with musl or if you are on Windows),
just pick the right command or archive here:

@archives "luax"

## LuaX full

The full LuaX archives contain the same softwares than the light archives plus some heavier but super useful programs:

- [lz4](https://lz4.org/): lossless compression algorithm, providing fast compression speed and super fast decompression speed
- [lzip](https://www.nongnu.org/lzip/): lossless data compressor with a user interface similar to the one of gzip or bzip2 and using a simplified form of the *'Lempel-Ziv-Markov chain-Algorithm' (LZMA)*
@(when(RELEASE_DITAA) "- [ditaa](https://ditaa.sourceforge.net/): small command-line utility written in Java, that can convert diagrams drawn using ascii art, into proper bitmap graphics"
)@(when(RELEASE_PLANTUML) "- [PlantUML](https://plantuml.com/): highly versatile tool that facilitates the rapid and straightforward creation of a wide array of diagrams"
)- [Pandoc](https://pandoc.org/): universal document converter
- [Typst](https://typst.app/): compose papers faster, focus on your text and let Typst take care of layout and formatting

This command detects the OS and installs LuaX in `$PREFIX/bin` and `$PREFIX/lib` (the default prefix is `~/.local/bin` and `~/.local/lib`):

``` sh
curl https://cdelord.fr/pub/luax-full.sh | sh
```

If you want to install a specific version (e.g. binaries statically linked with musl or if you are on Windows),
just pick the right command or archive here:

@archives "luax-full"
