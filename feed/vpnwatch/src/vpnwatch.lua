#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the vpn config file to identify changes in active vpn setting and propagate to openvpn

local utils = require "invizboxutils"
local uci = require("uci").cursor()

local vpnwatch = {}
vpnwatch.running = true

-- here for unit testing the main function by overwriting this function
function vpnwatch.keep_running()
    return true
end

function vpnwatch.do_nothing()
    while vpnwatch.running do
        utils.sleep(10)
        vpnwatch.running = vpnwatch.keep_running()
    end
end

function vpnwatch.setup_vpn()
    local return_value
    local restart = false
    local config_name = "vpn"
    uci:load(config_name)
    local section = "active"
    local active_vpn = uci:get(config_name, section, "name")
    if uci:get(config_name, active_vpn) == "server" then
        local filename = uci:get(config_name, active_vpn, "filename")
        if os.execute("diff "..filename.." /etc/openvpn/openvpn.conf")~=0 and
                os.execute("cp "..filename.." /etc/openvpn/openvpn.conf") == 0 then
            restart = true
            utils.log(active_vpn.." is now the current active VPN config - restarting openvpn")
            return_value = 1
        else
            utils.log("current VPN config is already in use, no change")
            return_value = 2
        end
        local current_username, current_password
        local auth_file = io.open("/etc/openvpn/login.auth", "r")
        if auth_file then
            current_username = auth_file:read()
            current_password = auth_file:read()
            auth_file:close()
        end
        local username = uci:get(config_name, section, "username")
        local password = uci:get(config_name, section, "password")
        if auth_file == nil or password ~= current_password or username ~= current_username then
            auth_file = io.open("/etc/openvpn/login.auth", "w")
            auth_file:write(username.."\n"..password)
            auth_file:close()
            restart = true
            utils.log("Updated the active VPN credentials - restarting openvpn")
            return_value = return_value + 20
        else
            utils.log("current VPN credentials are already in use, no change")
            return_value = return_value + 10
        end
    else
        utils.log("config marked as active is not available in config, no change")
        return_value = 3
    end
    if restart then
        os.execute("/etc/init.d/openvpn restart")
    else
        os.execute("/etc/init.d/openvpn start")
    end
    return return_value
end

function vpnwatch.main()
    vpnwatch.running=true
    local return_value = 0
    utils.log("Starting vpnwatch")
    local config_name = "vpn"
    uci:load(config_name)
    local mode = uci:get(config_name, "active", "mode")
    if mode == "vpn" then
        utils.log("VPN mode - enabling openvpn")
        os.execute("/etc/init.d/openvpn enable")
        return_value = vpnwatch.setup_vpn()
    else
        utils.log(mode.." mode - disabling openvpn")
        os.execute("/etc/init.d/openvpn stop")
        os.execute("/etc/init.d/openvpn disable")
    end
    vpnwatch.do_nothing()
    utils.log("Stopping vpnwatch")
    return return_value
end

if not pcall(getfenv, 4) then
    vpnwatch.main()
end

return vpnwatch
