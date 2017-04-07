-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"
local fs = require "nixio.fs"
local sys = require("luci.sys")
local nixio = require("nixio")
local utils = require "invizboxutils"

local bNewIdentity = 0  -- to only reset new identity
local map = cbi.Map("system", translate.translate("Tor Status and Configuration"), translate.translate(""))

map:chain("luci")

local section = map:section(cbi.TypedSection, "system", translate.translate(""))
section.anonymous = true
section.addremove = false

section:tab("torstatus",  translate.translate("Tor Status"))
section:tab("bridge",  translate.translate("Bridge Configuration"))
section:tab("proxy", translate.translate("Proxy Configuration"))
section:tab("geoip", translate.translate("Country Options"))

--[[=======================TOR STATUS===============]]--
local tor_restart_button = section:taboption("torstatus", cbi.Button, "_list", translate.translate(""))
tor_restart_button.inputtitle = translate.translate("Restart Tor")
tor_restart_button.inputstyle = "apply"
tor_restart_button.rmempty = true

function section.on_apply(_, _)
    sys.call('/etc/init.d/tor restart')
end

local tor_new_identity = section:taboption("torstatus", cbi.Button, "_link", "")
tor_new_identity.inputtitle = translate.translate("New Identity")
tor_new_identity.rmempty = true
tor_new_identity.inputstyle = "link"
tor_new_identity.template = "torcheck/newidentity"

local tor_refresh = section:taboption("torstatus", cbi.Button, "_list", "")
tor_new_identity.inputstyle = "link"
tor_refresh.template = "torcheck/refresh"

local tor_status = section:taboption("torstatus", cbi.Value, "_data", "")
tor_status.legend = translate.translate("Tor Connection Status")
tor_status.template = "torcheck/label"

local tor_rec = section:taboption("torstatus", cbi.Value, "_data","" )
tor_rec.legend = "Tor Version"
tor_rec.template = "torcheck/label"

local tor_circ = section:taboption("torstatus", cbi.Value, "_data", "")
tor_circ.legend = "Tor Circuit Status"
tor_circ.template = "torcheck/labelpure"

function tor_new_identity.write()
    local return_string = ""
    local sock = nixio.socket("inet", "stream")
    if sock and sock:connect("127.0.0.1", 9051) then
        local res, data = utils.tor_request(sock, "AUTHENTICATE \"\"\r\n")
        if not res then
           return_string = return_string..data
        end
        -- current version
        res, data = utils.tor_request(sock, "SIGNAL NEWNYM\r\n")
        if not res then
            return_string = return_string..data
        end
    else
        return_string = "Tor Not running"
    end
    bNewIdentity = 1
    sock:close()
    return return_string
end

function tor_restart_button.write(_, _)
    sys.call('/etc/init.d/tor restart')
end

local function lines(str)
  local t = {}
  local function helper(line)
      table.insert(t, line)
      return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

function tor_status.cfgvalue()
    local return_string = ""
    local sock = nixio.socket("inet", "stream")
    if sock and sock:connect("127.0.0.1", 9051) then
        local res, data = utils.tor_request(sock, "AUTHENTICATE \"\"\r\n")
        if not res then
            return_string = return_string..data
        end
        -- Is tor connected and circuits established
        res, data = utils.tor_request(sock, "GETINFO network-liveness\r\n")
        if not res then
            return_string = return_string..data
        end
        local start_position, end_position = string.find(data, "=%w*")
        local status = "=down"
        if start_position then
            status = string.sub(data, start_position, end_position)
        end
        if status == "=up" then
            return_string = return_string.."Connected to the Tor network"
        else
            return_string = "Not connected to the Tor network (please allow up to 60 seconds if you have just applied changes, then click 'Refresh')"
        end
    else
        return_string = "Tor Not running"
    end
    sock:close()
    return translate.translate(return_string)
end

function tor_rec.cfgvalue()
    local return_string = ""
    local sock = nixio.socket("inet", "stream")
    if sock and sock:connect("127.0.0.1", 9051) then
        local res, data = utils.tor_request(sock, "AUTHENTICATE \"\"\r\n")
        if not res then
           return_string = return_string..data
        end
        -- current verion
        res, data = utils.tor_request(sock, "GETINFO version\r\n")
        if not res then
            return_string = return_string..data
            return return_string
        else
            return_string = return_string..string.match(data, "%d.%d.%d.%d+").." : "
        end
        -- current verion recomended
        res, data = utils.tor_request(sock, "GETINFO status/version/current\r\n")
        if not res then
            return_string = return_string..data
            return return_string
        else
            return_string = return_string..string.match(data, "%w+", string.find(data, "="))
        end
    else
        return_string = "Tor Not running"
    end
    sock:close()
    return return_string
end

function tor_circ.cfgvalue()
    local return_string
    local sock = nixio.socket("inet", "stream")
    if sock and sock:connect("127.0.0.1", 9051) then
        local data
        local res, _ = utils.tor_request(sock, "AUTHENTICATE \"\"\r\n")
        if not res then
           return
        end

        res, data = utils.tor_request(sock, "GETINFO circuit-status\r\n")
        if not res then
            return
        else
            local clean_data = string.gsub(string.gsub(data, "\r\n250 .+$", ""), "^250+[^\n]*", "")
            local data_lines = lines(clean_data)
            local return_table = {}
            for _, circstat in pairs(data_lines) do
                if circstat ~= "" then
                   local tmp = string.gsub(circstat, "BUILD.*", "")
                   table.insert(return_table, tmp)
                end
            end
            return_string = table.concat(return_table, "<br>")
        end
        utils.tor_request(sock, "QUIT\r\n")
    else
        return_string = "Tor not running"
    end
    sock:close()
    return return_string
end

function section.cfgsections()
  return { "_pass" }
end

--[[======================= BRIDGE CONFIG ===============]]--
local bridge_config = section:taboption("bridge", cbi.TextValue, "_data", translate.translate("Bridge Configuration"),
    translate.translate("Please enter in the bridges you want Tor to use, one per line.<br>The format is : \"ip:port [fingerprint]\" where fingerprint is optional. e.g. 121.101.27.4:443 4352e58420e68f5e40ade74faddccd9d1349413.<br> To get bridge information, see <a href=\"https://bridges.torproject.org/bridges\">the Tor bridges page</a>.<br><br>InvizBox also has pluggable transport support. We support  <a href=\"https://bridges.torproject.org/bridges?transport=obfs2\">obfs2</a>,  <a href=\"https://bridges.torproject.org/bridges?transport=obfs3\">obfs3</a> and <a href=\"https://bridges.torproject.org/bridges?transport=scramblesuit\">scramblesuit</a> bridges. Only use these bridge types if normal bridges are blocked for you."))
bridge_config.wrap = "off"
bridge_config.rows = 3
bridge_config.rmempty = true

function bridge_config.cfgvalue()
    local return_table = {}
    local file = io.open("/etc/tor/bridges", "r")
    while true do
        local line = file:read()
        if line == nil then
            break
        end
        if line ~= "UseBridges 1" then
            local tmp = line:gsub("Bridge ", "")
            table.insert(return_table, tmp)
        end
    end
    file:close()
    return table.concat(return_table, "\n")
end

function bridge_config.write(_, _, value)
    if value and #value > 0 then
        local formatted = "UseBridges 1\n"..value:gsub("\r\n", "\n")
        formatted = formatted:gsub("\n\n", "")
        formatted = formatted:gsub("\n", "\nBridge ")
        formatted = formatted:gsub("Bridge \n", "")
        fs.writefile("/etc/tor/bridges", formatted )
    end
end

function bridge_config.remove(_, _)
    local file = io.open("/etc/tor/bridges", "w")
    file:close()
end

--[[======================= PROXY CONFIG ===============]]--
local proxy_config = section:taboption("proxy", cbi.ListValue, "proxy_config", translate.translate("Proxy Type"))
proxy_config:value("None")
proxy_config:value("HTTP/HTTPS")
proxy_config:value("SOCKS4")
proxy_config:value("SOCKS5")

local proxy_address = section:taboption("proxy", cbi.Value, "proxy_address", translate.translate("Proxy IP Address"))
proxy_address.placeholder = "192.168.1.5"
proxy_address.datatype = "ip4addr"

local ip_from_file, port_from_file, username_from_file, password_from_file

function proxy_config.cfgvalue()
    local file = io.open("/etc/tor/proxy", "r")
    proxy_config.default = "None"
    proxy_address.default = ""
    while true do
        if (file) then
            local line = file:read()
            if line == nil then
                break
            end

            local colonpos, _
            if line:find("HTTPSProxy ") then
                proxy_config.default = "HTTP/HTTPS"
                colonpos, _ = line:find(":")
                ip_from_file = line:sub(12, colonpos - 1)
                port_from_file = line:sub(colonpos + 1)
            elseif line:find("Socks4Proxy ") then
                proxy_config.default = "SOCKS4"
                colonpos, _ = line:find(":")
                ip_from_file = line:sub(13, colonpos - 1)
                port_from_file = line:sub(colonpos + 1)
            elseif line:find("Socks5Proxy ") then
                proxy_config.default = "SOCKS5"
                colonpos, _ = line:find(":")
                ip_from_file = line:sub(13, colonpos - 1)
                port_from_file = line:sub(colonpos + 1)
            elseif line:find("Socks5ProxyUsername ") then
                username_from_file = line:sub(21)
            elseif line:find("Socks5ProxyPassword ") then
                password_from_file = line:sub(21)
            elseif line:find("HTTPSProxyAuthenticator ") then
                colonpos, _ = line:find(":")
                username_from_file = line:sub(25, colonpos-1)
                password_from_file = line:sub(colonpos + 1)
            end
        else
            --create it
            file = io.open("/etc/tor/proxy", "w")
            file:close()
        end
    end
end

local proxy_file_string
function proxy_config.write(_, _, value)
    if (value == "None") then
        fs.unlink('/etc/tor/proxy')
        os.execute('touch /etc/tor/proxy')
    elseif (value == "HTTP/HTTPS") then
        proxy_file_string = "HTTPSProxy "
    elseif (value == "SOCKS4") then
        proxy_file_string = "Socks4Proxy "
    elseif (value == "SOCKS5") then
        proxy_file_string = "Socks5Proxy "
    end
end

function proxy_address.cfgvalue()
    if (ip_from_file ~= nil) then
        proxy_address.default = ip_from_file
    else
        proxy_address.default = ""
    end
end

function proxy_address.write(_, _, value)
    if proxy_file_string ~= nil then
        proxy_file_string = proxy_file_string..value..":"
    end
end

local proxy_port = section:taboption("proxy", cbi.Value, "proxy_port", translate.translate("Port"))
proxy_port.placeholder = "80"
proxy_port.datatype = "port"
proxy_port.rmempty = true

function proxy_port.cfgvalue()
end

function proxy_port.write(_, _, value)
    proxy_port.default = port_from_file
    if proxy_file_string ~= nil then
        proxy_file_string = proxy_file_string..value.."\n"
        --proxy_file_string = proxy_file_string.."ReachableAddresses *:80,*:443\nReachableAddresses reject *:*\n"
        fs.writefile("/etc/tor/proxy", proxy_file_string)
    end
end

local proxy_username = section:taboption("proxy", cbi.Value, "proxy_username", translate.translate("Username"))
proxy_username.placeholder = "optional"
proxy_username.optional = true

function proxy_username.cfgvalue()
    proxy_username.default = username_from_file
end

function proxy_username.write(_, _, value)
    if (proxy_file_string ~= nil and value ~= nil) then
        if (proxy_file_string:find("HTTP")) then
            proxy_file_string = proxy_file_string.."HTTPSProxyAuthenticator "..value..":"
        elseif (proxy_file_string:find("Socks5")) then
            proxy_file_string = proxy_file_string.."Socks5ProxyUsername "..value.."\n"
        end
    end
end

local proxy_password = section:taboption("proxy", cbi.Value, "proxy_password", translate.translate("Password"))
proxy_password.placeholder = "optional"
proxy_password.password = true
proxy_password.optional = true

function proxy_password.cfgvalue()
    proxy_password.default = password_from_file
end

function proxy_password.write(_, _, value)
    if (proxy_file_string ~= nil and value ~= nil) then
        if (proxy_file_string:find("HTTPSProxyAuthenticator")) then
            proxy_file_string = proxy_file_string..value.."\n"
        elseif (proxy_file_string:find("Socks5ProxyUsername")) then
            proxy_file_string = proxy_file_string.."Socks5ProxyPassword "..value.."\n"
        end
        fs.writefile("/etc/tor/proxy", proxy_file_string)
    end
end

--[[======================= GEOIP CONFIG ===============]]--
local geoip_file_string = ""
local geoip_config = section:taboption("geoip", cbi.ListValue, "geoip_config", translate.translate("Country Config"))
geoip_config:value("Use any exit node (default)")
geoip_config:value("Exclude \"Five Eyes\" countries")
geoip_config:value("Allow only countries selected below")
geoip_config:value("Do not use countries selected below")

function geoip_config.cfgvalue()
    local file = io.open("/etc/tor/geoip_dropdown", "r")
    geoip_config.default = "Use any exit node (default)"
    if (file) then
        local line = file:read()
        if line ~= nil then
            geoip_config.default = line
        end
    else
        --something went wrong, create it
        file = io.open("/etc/tor/geoip_dropdown", "w")
    end
    file:close()
end

function geoip_config.write(_, _, value)
    fs.writefile("/etc/tor/geoip_dropdown", value)
    if (value == "Use any exit node (default)") then
        fs.unlink("/etc/tor/geoip")
    elseif (value == "Exclude \"Five Eyes\" countries") then
        geoip_file_string = "\nExcludeExitNodes {AU},{CA},{NZ},{UK},{US}\n"
        fs.writefile("/etc/tor/geoip", geoip_file_string)
    elseif (value == "Allow only countries selected below") then
        geoip_file_string = "\nExitNodes "
        fs.unlink("/etc/tor/geoip")
    elseif (value == "Do not use countries selected below") then
        geoip_file_string = "\nExcludeExitNodes "
        fs.unlink("/etc/tor/geoip")
    end
end

local country_list = section:taboption("geoip", cbi.MultiValue, "country_list",
    translate.translate("Countries:    (hold ctrl to select multiple)"))
country_list.widget = "select"
country_list.default = ""
country_list.size = 15
country_list:value("A1", "Anonymous Proxies")
country_list:value("AR", "Argentina")
country_list:value("AP", "Asia/Pacific Region")
country_list:value("AU", "Australia")
country_list:value("AT", "Austria")
country_list:value("BY", "Belarus")
country_list:value("BE", "Belgium")
country_list:value("BR", "Brazil")
country_list:value("BG", "Bulgaria")
country_list:value("KH", "Cambodia")
country_list:value("CA", "Canada")
country_list:value("CL", "Chile")
country_list:value("CO", "Colombia")
country_list:value("CR", "Costa Rica")
country_list:value("HR", "Croatia")
country_list:value("CY", "Cyprus")
country_list:value("CZ", "Czech Republic")
country_list:value("DK", "Denmark")
country_list:value("EG", "Egypt")
country_list:value("EE", "Estonia")
country_list:value("EU", "Europe")
country_list:value("FI", "Finland")
country_list:value("FR", "France")
country_list:value("GE", "Georgia")
country_list:value("DE", "Germany")
country_list:value("GR", "Greece")
country_list:value("GT", "Guatemala")
country_list:value("GG", "Guernsey")
country_list:value("HK", "Hong Kong")
country_list:value("HU", "Hungary")
country_list:value("IS", "Iceland")
country_list:value("IN", "India")
country_list:value("ID", "Indonesia")
country_list:value("IE", "Ireland")
country_list:value("IL", "Israel")
country_list:value("IT", "Italy")
country_list:value("JP", "Japan")
country_list:value("KZ", "Kazakhstan")
country_list:value("KE", "Kenya")
country_list:value("KR", "Korea","Republic of")
country_list:value("LV", "Latvia")
country_list:value("LI", "Liechtenstein")
country_list:value("LT", "Lithuania")
country_list:value("LU", "Luxembourg")
country_list:value("MK", "Macedonia")
country_list:value("MY", "Malaysia")
country_list:value("MT", "Malta")
country_list:value("MX", "Mexico")
country_list:value("MD", "Moldova","Republic of")
country_list:value("MA", "Morocco")
country_list:value("NA", "Namibia")
country_list:value("NL", "Netherlands")
country_list:value("NZ", "New Zealand")
country_list:value("NG", "Nigeria")
country_list:value("NO", "Norway")
country_list:value("PK", "Pakistan")
country_list:value("PA", "Panama")
country_list:value("PL", "Poland")
country_list:value("PT", "Portugal")
country_list:value("QA", "Qatar")
country_list:value("RO", "Romania")
country_list:value("RU", "Russian Federation")
country_list:value("A2", "Satellite Provider")
country_list:value("SA", "Saudi Arabia")
country_list:value("RS", "Serbia")
country_list:value("SC", "Seychelles")
country_list:value("SG", "Singapore")
country_list:value("SK", "Slovakia")
country_list:value("SI", "Slovenia")
country_list:value("ZA", "South Africa")
country_list:value("ES", "Spain")
country_list:value("SE", "Sweden")
country_list:value("CH", "Switzerland")
country_list:value("TW", "Taiwan")
country_list:value("TH", "Thailand")
country_list:value("TR", "Turkey")
country_list:value("UA", "Ukraine")
country_list:value("GB", "United Kingdom")
country_list:value("US", "United States")
country_list:value("VE", "Venezuela")
country_list:value("VN", "Vietnam")

function country_list.cfgvalue()
--add selection parameters here
    country_list.default = ""
    local file = io.open("/etc/tor/geoip", "r")
    if (file) then
        local line = file:read("*all")
        local countries = line:gsub(".* {", "")
        countries = countries:gsub("},{", " ")
        countries = countries:gsub("}", "")
        country_list.default = countries
    end
end

function country_list.write(_, _, value)
    local line_length = geoip_file_string:len()
    if (line_length > 0) and (line_length < 20) then --not empty or five eyes
        local countries = value:gsub(" ", "},{")
        countries = "{"..countries.."}"
        geoip_file_string = geoip_file_string..countries
    end
    fs.writefile("/etc/tor/geoip", geoip_file_string)
end

function map.on_commit()
    if bNewIdentity == 0 then
        os.execute("cat /rom/etc/tor/torrc /etc/tor/proxy /etc/tor/bridges /etc/tor/geoip > /etc/tor/torrc ; /etc/init.d/tor restart")
    end
end

return map
