-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local uci = require "uci".cursor()
local translate = require "luci.i18n"
local http = require "luci.http"
local dispatcher = require "luci.dispatcher"
local utils = require "invizboxutils"
local isocountries = require "isocountries"

----------------------------
--  MAP SECTION TO CONFIG FILE
------------------------------

local wizard_complete = uci:load("wizard") and uci:get("wizard", "main", "complete") ~= "false"

local map
if wizard_complete then
    map = cbi.Map("vpn",translate.translate("VPN Location"))
else
    map = cbi.Map("vpn",translate.translate("VPN Details"))
end
map.template = "cbi/wizardmap"
map.anonymous = true
map.redirect = dispatcher.build_url("wizard/complete")

local vpn_details = map:section(cbi.TypedSection, "server", "", translate.translate("Select your VPN location:"))
vpn_details.addremove = false
vpn_details.anonymous = true
vpn_details.isempty = true
vpn_details.loop = true
vpn_details.template = "cbi/invizboxtsection"

local country = vpn_details:option(cbi.ListValue, "_country", translate.translate("Choose Country") .. " :" )
country.id = "vpncountry"
country.template = "cbi/invizboxlvalue"

local city = vpn_details:option(cbi.ListValue, "_name", translate.translate("Choose City") .. " :" )
city.id = "vpncity"
city.override_name = "vpncity"
city.template = "cbi/invizboxlvalue"
city.filtercountry = true

local dummy_value = vpn_details:option(cbi.DummyValue, "_activevpn")
dummy_value.template = "cbi/rawhtml"
dummy_value.rawhtml  = true
dummy_value.value = '<input id="activevpn" style="display:none" name="activevpn" value=\'' ..  map:get("active", "name") ..'\' />'

local country_list, city_list = {}, {}
map.uci:foreach("vpn", "server", function(section)
    table.insert(country_list, section["country"])
    table.insert(city_list, {key=section[".name"],
        value=section["country"] .. " - "  .. section["city"] .. " - " .. section["name"]})
end)
table.sort(country_list, function(x,y) return isocountries.getcountryname(x) < isocountries.getcountryname(y) end)
table.sort(city_list, function(x,y) return x.key < y.key end)

for _, ordered_country in ipairs(country_list) do
    country:value(ordered_country)
end

for _, ordered_city in ipairs(city_list) do
    city:value(ordered_city.key, ordered_city.value)
end

function map.on_before_save(self)
    self:set("active", "name", utils.uci_characters(http.formvalue("vpncity")))
end

return map
