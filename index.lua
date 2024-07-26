os.setlocale "C"
DATE = os.date "%D"

local url = "https://cdelord.fr/pub"

local function size(name)
    local s = fs.stat(name).size
    if s >= 1024*1024 then return ("%d&nbsp;MB"):format(s//(1024*1024)) end
    return ("%d&nbsp;KB"):format(s//(1024))
end

function archives(name)
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
        fs.write("pub"/script, i(fs.read "install.sh"))
    end)
    return bins
end
