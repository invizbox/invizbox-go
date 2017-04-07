-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

------------------------------
--  MAP SECTION TO CONFIG FILE
------------------------------
local cbi = require "luci.cbi"
local uci = require "uci".cursor()
local translate = require "luci.i18n"
local sys = require "luci.sys"
local dispatcher = require "luci.dispatcher"

local map, access_point, ssid, pass, dummyvalue
local wizard_complete = uci:load("wizard") and uci:get("wizard", "main", "complete") ~= "false"

if wizard_complete then
    map = cbi.Map("wireless", translate.translate("Hotspot"))
else
    map = cbi.Map("wireless", translate.translate("Create Hotspot"))
end
map.template = "cbi/wizardmap"
map.anonymous = true
map.redirect = "choose_network"

access_point = map:section(cbi.NamedSection, "ap", "wifi-iface", "", translate.translate("Name the InvizBox Go Wifi Hotspot"))
access_point.addremove = false

ssid = access_point:option(cbi.Value, "ssid", translate.translate("Hotspot Name") )
ssid.required = true
ssid.maxlength = 63
ssid.template = "cbi/invizboxvalue"

pass = access_point:option(cbi.Value, "key", translate.translate("Hotspot Password"))
pass.template = "cbi/invizboxpassword"
pass.password = true
pass.required = true
pass.id = "hotspot_password"
pass.validator_equals = "#hotspot_password"
pass.validator_minlength = 8
pass.maxlength = 63
pass.validator_equals_error = "Passwords do not match"
--adminpass = access_point:option(Flag, "usesamepass", "", "Use same password for Administration Interface")

dummyvalue = access_point:option(cbi.DummyValue, "_adminpassword")
dummyvalue.template = "cbi/rawhtml"
dummyvalue.rawhtml  = true
dummyvalue.value = '<p class="note">' .. translate.translate("Same password will be used for admin UI. Please change it later under System/Administration") .. '</p>'

if not wizard_complete then
    dummyvalue = access_point:option(cbi.DummyValue, "_aupaccept")
    dummyvalue.template = "cbi/rawhtml"
    dummyvalue.rawhtml  = true
    dummyvalue.value = '<br><div class="form-group cbi-value-field"><input class="cbi-input-checkbox" type="checkbox" id="aupaccept" name="aupaccept"  checked="checked" value=""><p class="note" style="padding-top: .6em;">By using the InvizBox Go you accept the conditions in the <a href="https://invizbox.com/aup">Acceptable Use Policy</a></p></div>'
end


--------------------------------
-- 	functions
--------------------------------
function map.on_commit()
    sys.user.setpasswd(dispatcher.context.authuser, pass:formvalue("ap"))
    local config_name = "wireless"
    uci:load(config_name)
    uci:set(config_name, "ap", "encryption", "psk-mixed")
    uci:set(config_name, "ap", "cipher", "ccmp")
    uci:save(config_name)
    uci:commit(config_name)
end

return map
