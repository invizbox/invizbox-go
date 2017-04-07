-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"
local fs = require "nixio.fs"

local map = cbi.Map("system", translate.translate("Tor Advanced Configuration"), translate.translate(""))
map:chain("luci")

local section = map:section(cbi.TypedSection, "system", translate.translate(""))
section.anonymous = true
section.addremove = false

--[[======================= TORRC CONFIG ===============]]--
local torrc_config = section:option(cbi.TextValue, "_data", translate.translate("Torrc Configuration"),
    translate.translate("Advanced configuration of the Tor configuration. Be very careful, here be dragons. Touch at your own peril"))
torrc_config.wrap    = "off"
torrc_config.rows    = 30
torrc_config.cleanempty = true
torrc_config.optional = true

function torrc_config.cfgvalue()
    local return_table = {}
    local file = io.open("/etc/tor/torrc", "r")
    while true do
        local line = file:read()
        if line == nil then
            break
        end
        table.insert(return_table, line)
    end
    file:close()
    return table.concat(return_table, "\n")
end

function torrc_config.write(_, _, value)
    os.execute("echo -n > /etc/tor/torrc")
    if value and #value > 0 then
        fs.writefile("/etc/tor/torrc", value )
    end
    os.execute("/etc/init.d/tor restart")
end

return map
