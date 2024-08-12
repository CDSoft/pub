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
local sys = require "sys"
local lar = require "lar"

local args = (function()
    local parser = require "argparse"()
    parser : description(F.unlines {
        "This self-extracting archive installs",
        "the "..sys.name.." LuaX binaries",
        "in <prefix>/bin and <prefix>/lib.",
        "",
        "If the <prefix> argument is not given",
        "the installation prefix is the PREFIX environment variable.",
        "",
        "The default prefix is $HOME/.local"
    })
    parser : argument "prefix" : description "Installation prefix" : args "?"
    return parser:parse(arg)
end)()

local prefix
if args.prefix then
    prefix = args.prefix
else
    local PREFIX = os.getenv "PREFIX"
    if PREFIX then
        prefix = PREFIX
    else
        local HOME = os.getenv "HOME"
        if HOME then
            prefix = HOME/".local"
        else
            err "installation prefix not defined"
        end
    end
end

--for k,v in pairs(package.preload) do print(k, v) end

print(string.format("Extracting the %s LuaX archive in %s", sys.name, prefix))
F.foreachk(lar.unlar(require(sys.name..".lar")), function(name, file)
    local full_name = prefix/name
    if fs.is_file(full_name) then assert(fs.remove(full_name)) end
    if file.target then
        print(string.format("%s -> %s", name, target))
        assert(fs.symlink(target, full_name))
    else
        print(string.format("%s", name))
        assert(fs.write_bin(full_name, file.data))
        assert(fs.touch(full_name, file.time))
        assert(fs.chmod(full_name, file.mode))
    end
end)
print("Done")
