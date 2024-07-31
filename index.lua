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

os.setlocale "C"
DATE = os.date "%D"

local url = "https://cdelord.fr/pub"

local function size(name)
    local s = fs.stat(name).size
    if s >= 1024*1024 then return ("%d MB"):format(s//(1024*1024)) end
    return ("%d KB"):format(s//(1024))
end

function archives(name)
    local bins = {
        "| Target        | Installation                                  | Size |",
        "| :------------ | :-------------------------------------------- | ---: |",
    }
    local i = (F.I % "@()") { URL = url }
    local targets = require "targets"
    targets : foreach(function(target)
        local archive_xz  = name.."-"..target.name..".tar.xz"
        local archive_zip = name.."-"..target.name..".zip"
        local script      = name.."-"..target.name..".sh"
        local install = "`curl "..url/script.." | sh`"

        local function row(...) return "| "..F.str({...}, " | ").." |" end

        bins[#bins+1] = row(target.name:gsub("%-", " "), install, "")
        bins[#bins+1] = row("", ":floppy_disk: ["..archive_xz.."]("..archive_xz..")", size("pub"/archive_xz))
        if target.os == "windows" then
            bins[#bins+1] = row("", ":window: ["..archive_zip.."]("..archive_zip..")", size("pub"/archive_zip))
        end

        fs.write("pub"/script, i{ARCHIVE_NAME=archive_xz}(fs.read "install.sh"))
    end)

    fs.write("pub"/name..".sh", i{SCHEME=name}(fs.read "luax.sh"))

    return bins
end
