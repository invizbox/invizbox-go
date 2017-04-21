#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- updates VPN configuration and firmware

local utils = require "invizboxutils"
local uci_mod = require("uci")
local uci = uci_mod.cursor()
local uci_etc = uci_mod.cursor("/etc")

local update = {}
update.config = {}

function update.load_update_config(use_clearnet)
    update.config.use_clearnet = use_clearnet or false
    local config_name = "updateinfo"
    local network = "onion"
    uci_etc:load(config_name)
    if update.config.use_clearnet == true then
        network = "clearnet"
    end
    update.config.vpn_configuration = uci_etc:get(config_name, network, "vpn_configuration")
    update.config.vpn_configuration_sha = uci_etc:get(config_name, network, "vpn_configuration_sha")
    update.config.vpn_configuration_content_sha = uci_etc:get(config_name, network, "vpn_configuration_content_sha")
    update.config.new_firmware_version = uci_etc:get(config_name, network, "new_firmware_version")
    update.config.new_firmware = uci_etc:get(config_name, network, "new_firmware")
    update.config.new_firmware_sha = uci_etc:get(config_name, network, "new_firmware_sha")
    update.config.current_content_sha = uci_etc:get(config_name, "active", "current_content_sha")
end

function update.update_vpn()
    utils.log("Checking if new VPN configuration is available.")
    if utils.success(utils.download(update.config.vpn_configuration_content_sha, "/tmp/latest_vpn_configuration.content.sha")) then
        local content_sha = string.gmatch(utils.get_first_line("/tmp/latest_vpn_configuration.content.sha"), "%S+")()
        if content_sha ~= update.config.current_content_sha then
            utils.log("Downloading new VPN configuration...")
            if utils.success(utils.download(update.config.vpn_configuration, "/tmp/vpn_configuration.zip")) and
                    utils.success(utils.download(update.config.vpn_configuration_sha, "/tmp/vpn_config_download.sha")) then
                os.execute("sha256sum /tmp/vpn_configuration.zip > /tmp/vpn_config_received.sha")
                local initial_sha = string.gmatch(utils.get_first_line("/tmp/vpn_config_download.sha"), "%S+")()
                local download_sha = string.gmatch(utils.get_first_line("/tmp/vpn_config_received.sha"), "%S+")()
                if initial_sha == download_sha and
                        os.execute("unzip -o -d /tmp/potential_configs /tmp/vpn_configuration.zip") == 0 then
                    utils.log("VPN configuration available in /tmp/vpn_configuration.zip")
                    utils.log("Configs available in /tmp/potential_configs")

                    -- move ovpn files and certificate
                    os.execute("mv /tmp/potential_configs/*.ovpn /etc/update/configs")
                    os.execute("mv /tmp/potential_configs/*.crt /etc/openvpn")

                    -- delete previous uci entries
                    local config_name = "vpn"
                    uci:load(config_name)
                    local section = "server"
                    uci:foreach(config_name, section, function(s)
                        uci:delete(config_name, s['.name'])
                    end)

                    -- add new ones from CSV
                    local successful_replacement = false
                    for line in io.lines("/tmp/potential_configs/server_list.csv") do
                        local name, country, city, filename =  line:match("([^,]+),([^,]+),([^,]+),([^,]+)")
                        if name ~= "name" then
                            local uci_name = utils.uci_characters(name)
                            uci:set(config_name, uci_name, "server")
                            uci:set(config_name, uci_name, "country", country)
                            uci:set(config_name, uci_name, "city", city)
                            uci:set(config_name, uci_name, "name", name)
                            uci:set(config_name, uci_name, "filename", filename)
                            successful_replacement = true
                        end
                    end
                    if successful_replacement then
                        uci:save(config_name)
                        uci:commit(config_name)
                    end
                    uci_etc:load("updateinfo")
                    uci_etc:set("updateinfo", "active", "current_content_sha", content_sha)
                    uci_etc:save("updateinfo")
                    uci_etc:commit("updateinfo")
                else
                    utils.log("Invalid sha256 after download, will try again later")
                    return 1
                end
            else
                utils.log("Unable to obtain a more up to date VPN configuration, will try again later")
                return 2
            end
            os.execute("rm -rf /tmp/potential_configs")
            utils.log("All usable configuration files are available in /etc/update/configs")
            return true
        else
            utils.log("We already have the most up to date VPN configuration")
            return 3
        end
    else
        utils.log("Unable to get a content SHA for the latest VPN configuration, will try again later")
        return 4
    end
end

function update.update_firmware()
    utils.log("Checking if new firmware is available.")
    if utils.success(utils.download(update.config.new_firmware_version, "/tmp/latest_firmware_version.txt")) then
        local config_name = "updateinfo"
        uci_etc:load(config_name)
        local current_version = uci_etc:get(config_name, "version", "firmware")
        local new_version = utils.get_first_line("/tmp/latest_firmware_version.txt")
        if new_version ~= current_version then
            if utils.file_exists("/tmp/update/firmware/InvizBox-Go-"..new_version.."-sysupgrade.bin") then
                utils.log("We have already downloaded that update, finished for now.")
                return 1
            else
                utils.log("Downloading new firmware.")
                if utils.success(utils.download(string.format(update.config.new_firmware, new_version), "/tmp/firmware_download.bin")) and
                        utils.success(utils.download(string.format(update.config.new_firmware_sha, new_version), "/tmp/firmware_download.sha")) then
                    os.execute("sha256sum /tmp/firmware_download.bin > /tmp/firmware_received.sha")
                    local initial_sha = string.gmatch(utils.get_first_line("/tmp/firmware_download.sha"), "%S+")()
                    local download_sha = string.gmatch(utils.get_first_line("/tmp/firmware_received.sha"), "%S+")()
                    if initial_sha == download_sha then
                        os.execute("rm -rf /tmp/update/firmware; mkdir -p /tmp/update/firmware && mv /tmp/firmware_download.bin /tmp/update/firmware/InvizBox-Go-"..new_version.."-sysupgrade.bin")
                        utils.log("New firmware now available at /tmp/update/firmware/InvizBox-Go-"..new_version.."-sysupgrade.bin")
                        uci_etc:set(config_name, "version", "new_firmware", new_version)
                        uci_etc:save(config_name)
                        uci_etc:commit(config_name)
                    else
                        utils.log("Downloaded binary doesn't match downloaded hash, will try again later")
                        return 2
                    end
                else
                    utils.log("Unable to download the latest firmware, will try again later.")
                    return 3
                end
            end
        else
            utils.log("The current version is the latest")
            return 4
        end
    else
        utils.log("Unable to check if a new version is available, will try again later.")
        return 5
    end
    return true
end

function update.update_opkg()
    if (update.config.use_clearnet == false) then
        utils.log("Updating opkg via .onion.")
        os.execute("opkg update > /var/log/opkg_update.log 2>&1")
        utils.log(utils.run_and_log("cat /var/log/opkg_update.log"))
        os.execute("eval $(opkg list_installed | sed 's/ - .*/;/' | sed 's/^/opkg upgrade /') > /var/log/opkg_upgrade.log 2>&1")
        utils.log(utils.run_and_log("cat /var/log/opkg_upgrade.log"))
        return 0
    else
        utils.log("Updating opkg via clearnet.")
        os.execute("opkg -f /etc/opkg_clearnet.conf update > /var/log/opkg_update.log  2>&1")
        utils.log(utils.run_and_log("cat /var/log/opkg_update.log"))
        os.execute("eval $(opkg list_installed | sed 's/ - .*/;/' | sed 's/^/opkg upgrade /') > /var/log/opkg_upgrade.log 2>&1")
        utils.log(utils.run_and_log("cat /var/log/opkg_upgrade.log"))
        return 1
    end
end

function update.check_network()
    utils.log("Checking if .onion is accessible.")
    if utils.success(utils.download(update.config.vpn_configuration_content_sha, "/tmp/latest_vpn_configuration.content.sha")) then
        utils.log(".onion is accessible.")
        return 1
    else
        utils.log(".onion is inaccessible, switch to clearnet.")
        update.load_update_config(true)
        return 0
    end
end

function update.update()
    -- prevent multiple executions of script in parallel (if lock is left as update is killed - only a restart or manual
    -- removal of lock file will allow for a successful run of update
    if os.execute("lock -n /var/lock/update.lock") ~= 0 then
        utils.log("Unable to obtain update lock.")
        return false
    end

    -- hacking log function here to be able to use invizboxutils with logging and yet avoid an empty log file when
    -- unable to acquire the lock above - not too clean...
    local log_file = io.open("/var/log/update.log", "w")
    utils.log = function(string)
        log_file:write(string.."\n")
    end
    update.load_update_config()
    update.check_network()
    local success = update.update_vpn() == true
    success = update.update_firmware() == true and success
    success = update.update_opkg() == true and success
    log_file:close()
    if success then
        uci_etc:load("updateinfo")
        uci_etc:set("updateinfo", "active", "last_successful_update", os.time())
        uci_etc:save("updateinfo")
        uci_etc:commit("updateinfo")
        os.execute("lock -u /var/lock/update.lock")
        return true
    end
    os.execute("lock -u /var/lock/update.lock")
    return false
end

if not pcall(getfenv, 4) then
    update.update()
end

return update
