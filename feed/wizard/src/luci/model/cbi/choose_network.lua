-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local http = require "luci.http"
local translate = require "luci.i18n"
local uci = require("uci").cursor()
local utils = require("invizboxutils")


local map, station, ssid, pass, encryptionstring, cipherstring, channelstring, dummyencryption, wifi_channel, encryption, cipher, disabled

------------------------------
--  MAP SECTION TO CONFIG FILE
------------------------------

map = cbi.Map("wireless", translate.translate("Choose Network"))
map.template = "cbi/wizardmap"
map.anonymous = true
map.redirect = "account_details"

station = map:section(cbi.NamedSection, "wan", "wifi-iface", "", translate.translate("Select the Wifi hotspot to connect to:"))
station.addremove = false

ssid = station:option(cbi.ListValue, "ssid", translate.translate("Choose Network") )
ssid.required = true
ssid.maxlength = 63
ssid.id = "ssid"
ssid.template = "cbi/invizboxlvalue"
ssid:reset_values()

encryptionstring = ""
cipherstring = ""
channelstring = ""
local index, networks = utils.wifi_networks()
for _, scanssid in ipairs(index) do
    if networks[scanssid].encryption ~= "none" then
        ssid:value(scanssid, networks[scanssid].quality.."% - "..scanssid.." (Secure)")
    else
        ssid:value(scanssid, networks[scanssid].quality.."% - "..scanssid.." (Open)")
    end
    encryptionstring = encryptionstring.."<input type=\"hidden\" id=\""..scanssid..".encryption\" name=\""..scanssid..".encryption\" value=\""..networks[scanssid].encryption.."\"/>"
    cipherstring = cipherstring.."<input type=\"hidden\" id=\""..scanssid..".cipher\" name=\""..scanssid..".cipher\" value=\""..networks[scanssid].cipher.."\"/>"
    channelstring = channelstring.."<input type=\"hidden\" id=\""..scanssid..".channel\" name=\""..scanssid..".channel\" value=\""..networks[scanssid].channel.."\"/>"
end

pass = station:option(cbi.Value, "key", translate.translate("Enter Password"))
pass.template = "cbi/invizboxvalue"
pass.id = "ssidpassword"
pass.password = true
pass.validator_minlength = 8
pass.maxlength = 63

dummyencryption = station:option(cbi.DummyValue, "_dummy")
dummyencryption.template = "cbi/rawhtml"
dummyencryption.rawhtml  = true
dummyencryption.value = encryptionstring

encryption = station:option(cbi.Value, "encryption")
encryption.template = "cbi/invizboxhidden"

cipher = station:option(cbi.DummyValue, "_dummy")
cipher.template = "cbi/rawhtml"
cipher.rawhtml  = true
cipher.value = cipherstring

wifi_channel = station:option(cbi.DummyValue, "_dummy")
wifi_channel.template = "cbi/rawhtml"
wifi_channel.rawhtml  = true
wifi_channel.value = channelstring

local selected_ssid = http.formvalue("cbid.wireless.wan.ssid") or ""

disabled = station:option(cbi.Value, "disabled")
disabled.template = "cbi/invizboxhidden"

function map.on_before_save(self)
    self:set("wan", "encryption", http.formvalue(selected_ssid .. ".encryption"))
    self:set("wan", "cipher", http.formvalue(selected_ssid .. ".cipher"))
    self:del("wan", "disabled", http.formvalue(selected_ssid .. ".encryption"))
    self:set("mt7603e", "channel", http.formvalue(selected_ssid .. ".channel"))
    local config_name = "known_networks"
    local section_name = utils.uci_characters(ssid:formvalue("wan"))
    uci:load(config_name)
    uci:set(config_name, section_name, "network")
    uci:set(config_name, section_name, "ssid", ssid:formvalue("wan"))
    uci:set(config_name, section_name, "key", pass:formvalue("wan"))
    uci:save(config_name)
    uci:commit(config_name)
end

return map
