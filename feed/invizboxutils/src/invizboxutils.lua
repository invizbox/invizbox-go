#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Useful functions that can be imported by other Lua scripts
-- don't forget to add +invizboxutils to your DEPENDS

local io = require "io"
local http = require "socket.http"
local https = require "ssl.https"
local socket = require "socket"
local ltn12 = require "ltn12"
local sys = require "luci.sys"
local translate = require "luci.i18n"

local invizboxutils ={}

function invizboxutils.success(http_code)
    return http_code >= 200 and http_code < 300
end

function invizboxutils.redirect(http_code)
    return http_code >= 300 and http_code < 400
end

function invizboxutils.download(url, file, ssl)
    ssl = ssl or false
    local code = 0
    local resp
    for _ = 1,3 do
        local sink = ltn12.sink.file(io.open(file, 'w'))
        if ssl then
            resp, code, _, _ = https.request{url = url, sink = sink }
        else
            resp, code, _, _ = http.request{url = url, sink = sink }
        end
        if resp and (invizboxutils.success(code) or invizboxutils.redirect(code)) then
            break
        else
            invizboxutils.log("failed to download url "..url.." with code ["..code.."]")
        end
    end
    if resp == nil or (not invizboxutils.success(code) and not invizboxutils.redirect(code)) then
        invizboxutils.log('unable to retrieve:['..url..']')
        return 0
    end
    return code
end

function invizboxutils.get_first_line(file)
    local file_handle = assert(io.open(file, "r"))
    local line = file_handle:read("*line")
    file_handle:close()
    return line
end

function invizboxutils.file_exists(file)
    local file_handle = io.open(file, "r")
    if file_handle then
        file_handle:close()
        return true
    end
    return false
end

function invizboxutils.sleep(sec)
    socket.select(nil, nil, sec)
end

function invizboxutils.run_and_log(command)
	local handle = io.popen(command)
	local output = handle:read("*a")
	handle:close()
	return output
end

function invizboxutils.log(string)
    io.stdout:write(string.."\n")
    io.stdout:flush()
end

function invizboxutils.table_print(data)
    if type(data) == "table" then
        for key, value in pairs(data) do
            print(key)
            invizboxutils.table_print(value)
        end
    else
        print(data)
    end
end

function invizboxutils.table_size(table)
    local size = 0
    for _, _ in pairs(table) do
         size = size +1
    end
    return size
end

function invizboxutils.uci_characters(identifier)
    return string.gsub(identifier, '[^a-zA-Z0-9_]', '')
end

function invizboxutils.wifi_networks()
    local radio = sys.wifi.getiwinfo("ra0")
    local networks = {}
    for _ = 1, 2 do
        for _, network in ipairs(radio.scanlist or {} ) do
            if network.ssid ~= nil and network.quality ~= nil and network.quality_max ~= nil
                     and network.quality_max ~= 0 and network.encryption ~= nil then
                local quality = math.floor(network.quality * 100 / network.quality_max)
                local encryption = "none"
                local cipher = "none"
                if network.encryption.wep then
                    encryption = "wep"
                    cipher = "wep"
                elseif network.encryption.wpa > 0 then
                    encryption = "wpa"
                    if network.encryption.wpa > 1 then
                        encryption = "wpa2"
                    end
                    cipher = "tkip"
                    for _, supported_cipher in ipairs(network.encryption.pair_ciphers) do
                        if supported_cipher == "CCMP" then
                            cipher = "ccmp"
                            break
                        end
                    end
                end
                if networks[network.ssid] == nil or quality > networks[network.ssid].quality then
                    networks[network.ssid] = {quality = quality, encryption = encryption, cipher = cipher, channel = network.channel}
                end
            end
        end
    end
    local ordered_index = {}
    for key in pairs(networks) do
        table.insert(ordered_index, key)
    end
    table.sort(ordered_index, function(a,b) return networks[a].quality > networks[b].quality end)
    return ordered_index, networks
end

function invizboxutils.tor_request(sock, command)
    if not sock:send(command) then
        return false, translate.translate("Cannot send the command to Tor")
    end
    local reply_table = {}
    local resp = sock:recv(1000)
    while resp do
        table.insert(reply_table, resp)
        if string.len(resp) < 1000 then break end
        resp = sock:recv(1000)
    end
    local reply = table.concat(reply_table)

    if not resp then
        return false, translate.translate("Cannot read the response from Tor")
    end
    local i, j = string.find(reply, "^%d%d%d")
    if j ~= 3 then
        return false, "Malformed response from Tor"
    end
    local code = string.sub(reply, i, j)
    if code ~= "250" and (code ~= "650" or command ~= "") then
        return false, "Tor responded with an error: "..reply
    end

    return true, reply
end

return invizboxutils
