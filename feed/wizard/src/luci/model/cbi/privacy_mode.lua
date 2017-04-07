-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"

----------------------------
--  MAP SECTION TO CONFIG FILE
------------------------------

local map = cbi.Map("vpn",translate.translate("Privacy Mode"))
map.template = "cbi/wizardmap"
map.anonymous = true

local mode_details = map:section(cbi.TypedSection, "active", "", translate.translate("Select your privacy mode:"))
mode_details.addremove = false
mode_details.anonymous = true
mode_details.isempty = true
mode_details.loop = true
mode_details.template = "cbi/invizboxtsection"

local mode = mode_details:option(cbi.ListValue, "mode", translate.translate("Choose Privacy Mode") .. " :" )
mode.id = "mode"
mode.widget = "radio"
mode.template = "cbi/invizboxlvalue"
mode:value("vpn", "VPN")
mode:value("tor", "Tor")
mode:value("extend", "Wifi Extender")

return map
