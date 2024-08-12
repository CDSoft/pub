#!/usr/bin/env luax

----------------------------------------------------------------------
-- This file is part of luax.
--
-- luax is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- luax is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with luax.  If not, see <https://www.gnu.org/licenses/>.
--
-- For further information about luax you can visit
-- http://cdelord.fr/luax and http://cdelord.fr/pub
----------------------------------------------------------------------

local F = require "F"
local fs = require "fs"
local lar = require "lar"
local cbor = require "cbor"

local args = (function()
    local parser = require "argparse"()
    parser : description "lz archive creation for sfx.lua"
    parser : argument "dist" : description "Distribution path" : args "1"
    parser : option "-o" : description "Output file" : argname "output" : target "output"
    return parser:parse(arg)
end)()

local function short(name)
    return name:sub(#args.dist+2)
end

local archive = {
}

print("Read files from "..args.dist)
fs.ls(args.dist/"**")
: filter(fs.is_file)
: foreach(function(name)
    local short_name = short(name)
    local stat = fs.lstat(name)
    local target = stat.type == "link" and fs.readlink(name)
    print(string.format("%-20s %s", short_name, stat.type == "link" and "(symlink to "..target..")" or ""))
    if stat.type == "link" then
        archive[short_name] = {
            link = target
        }
    else
        archive[short_name] = {
            mode = stat.mode,
            time = stat.time,
            data = fs.read_bin(name),
        }
    end
end)

fs.write_bin(args.output, lar.lar(archive, {compress="lzip-0"}))
