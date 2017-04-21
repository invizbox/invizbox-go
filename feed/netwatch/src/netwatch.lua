#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly

local network = require "luci.model.network"
local nixio = require "nixio"
local utils = require "invizboxutils"
local led = require "ledcontrol"
local uci = require("uci").cursor()

local netwatch = {}
netwatch.running = true
netwatch.access_point = "br-ap"
netwatch.station = "apcli0"
netwatch.vpn = "tun0"
netwatch.tor = "eth0.3"
netwatch.vpn_mode = "vpn"
netwatch.tor_mode = "tor"

function netwatch.check_captive_portal()
    -- make sure dnsmasq is up and running to avoid DNS timeouts
    local dnsmasq_up = false
    for _ = 1,5 do
        dnsmasq_up = os.execute("test -e /tmp/run/dnsmasq/dnsmasq*.pid") == 0
        if dnsmasq_up then
            break
        else
            utils.log("Waiting another second for dnsmasq to be up!")
        end
        utils.sleep(1)
    end
    if not dnsmasq_up then
        utils.log("dnsmasq failed to come up within 5s!")
    end

    -- captive portal URL check
    local http_code = utils.download("http://clients3.google.com/generate_204", "/tmp/204.txt")
    if http_code == 0 then
        utils.log("Error - unable to connect to a web server during the captive portal test")
        return nil
    end
    -- 204 and size 0 file means not a capture portal
    local script = 'eval "if [ -s /tmp/204.txt ] ; then exit 1 ; fi"'
    if http_code == 204 and os.execute("sh -c '"..script.."'") == 0 then
        return false
    else
        return true
    end
end

-- here for unit testing the main function by overwriting this function
function netwatch.keep_running()
    return true
end

function netwatch.reset_iptables()
    -- use iptables-restore for all iptables changes once identified (atomic and faster
    -- http://inai.de/documents/Perfect_Ruleset.pdf)
    -- also consider scripting the changes as in the document for readability and manual testability)
    os.execute("sysctl -w net.ipv4.ip_forward=0")
    os.execute("/bin/remove_forward_rules.ash")
end

function netwatch.set_status(option, status)
    local config_name = "status"
    uci:load(config_name)
    uci:set(config_name, "current", option, status)
    uci:save(config_name)
    uci:commit(config_name)
    return true
end

function netwatch.set_dnsmasq(connected)
    if connected then
        os.execute("ln -s -f /etc/dnsmasq.conf.connected /etc/dnsmasq.conf")
        utils.log("set dnsmasq to connected")
    else
        os.execute("ln -s -f /etc/dnsmasq.conf.captive /etc/dnsmasq.conf")
        utils.log("set dnsmasq to captive")
    end
end

function netwatch.set_dnsmasq_rebind_protection(on)
    local config_name = "dhcp"
    uci:load(config_name)
    local name
    uci:foreach(config_name, "dnsmasq", function(s)
        name = s['.name']
    end)
    if on then
        uci:set(config_name, name, "rebind_protection", "1")
        utils.log("set dnsmasq rebind_protection to 1 (on)")
    else
        uci:set(config_name, name, "rebind_protection", "0")
        utils.log("set dnsmasq rebind_protection to 0 (off)")
    end
    uci:save(config_name)
    uci:commit(config_name)
end

function netwatch.set_dnsmasq_resolv(on)
    local config_name = "dhcp"
    uci:load(config_name)
    local name
    uci:foreach(config_name, "dnsmasq", function(s)
        name = s['.name']
    end)
    if on then
        uci:set(config_name, name, "resolvfile", "/etc/resolv.conf.vpn")
        utils.log("set dnsmasq resolv.conf to vpn")
    else
        uci:set(config_name, name, "resolvfile", "/tmp/resolv.conf.auto")
        utils.log("set dnsmasq resolv.conf to auto")
    end
    uci:save(config_name)
    uci:commit(config_name)
    os.execute("/etc/init.d/dnsmasq restart")
end

function netwatch.set_local_resolv(auto)
    if auto then
        os.execute("ln -sf /tmp/resolv.conf.auto /tmp/resolv.conf")
        utils.log("set local resolv.conf to auto")
    else
        os.execute("ln -sf /etc/resolv.conf.normal /tmp/resolv.conf")
        utils.log("set local resolv.conf to normal (dnsmasq)")
    end
end

function netwatch.set_time()
    -- first check for a big time discrepancy over http (enough to enable login for openvpn - main issue)
    os.execute("date +%s > /tmp/current_time.txt")
    local device_time = utils.get_first_line("/tmp/current_time.txt")
    if utils.success(utils.download("https://invizbox.com/cgi-bin/unixtime", "/tmp/web_time.txt", true)) then
        local web_time = utils.get_first_line("/tmp/web_time.txt")
        if math.abs(device_time - web_time) > 300 then
            utils.log("resolving a big time discrepancy between local time and web time")
            os.execute("date +%s -s @"..web_time)
        end
    else
        utils.log("unable to get web time to validate local time")
    end
    -- then rely on ntp (if network allows - otherwise above will have to suffice)
    os.execute("/etc/init.d/sysntpd restart")
end

function netwatch.tor_is_up()
    local sock = nixio.socket("inet", "stream")
    if sock and sock:connect("127.0.0.1", 9051) then
        local res, data
        res = utils.tor_request(sock, "AUTHENTICATE \"\"\r\n")
        if not res then
            return false
        end
        -- Is tor connected and circuits established
        res, data = utils.tor_request(sock, "GETINFO network-liveness\r\n")
        if not res then
            return false
        end
        local status = string.sub(data, string.find(data, "=%w*"))
        if status == "=up" then
            sock:close()
            return true
        else
            sock:close()
            return false
        end
    else
        sock:close()
        return false
    end
end

function netwatch.no_network()
    -- status and LED
    netwatch.set_status("wan", "Down")
    netwatch.set_status("vpn", "Down")
    netwatch.set_status("status", "No Internet Connection")
    led.red_solid()
    utils.log("going red solid")
    -- DNS - order matters!!!
    netwatch.set_local_resolv(true)
    netwatch.set_dnsmasq(false)
    netwatch.set_dnsmasq_rebind_protection(true)
    netwatch.set_dnsmasq_resolv(false)
    -- routing
    netwatch.reset_iptables()
    os.execute("sysctl -w net.ipv4.ip_forward=1")
    os.execute('iptables -t nat -I PREROUTING -p tcp --dport 80 --jump DNAT --to-destination 10.153.146.1:80 -m comment --comment "invizbox"')
    os.execute('iptables -t nat -I PREROUTING -p tcp --dport 443 --jump DNAT --to-destination 10.153.146.1:80 -m comment --comment "invizbox"')
    os.execute('iptables -I FORWARD -i '..netwatch.access_point..' -o br-lan -d inviz.box -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT -m comment --comment "invizbox"')
    -- waiting
    while netwatch.running do
        utils.sleep(100)
        netwatch.running = netwatch.keep_running()
    end
end

function netwatch.captive_portal()
    -- status and LED
    netwatch.set_status("wan", "Up")
    netwatch.set_status("vpn", "Down")
    netwatch.set_status("status", "Behind Captive Portal")
    led.orange_solid()
    utils.log("going orange solid")
    -- DNS - order matters!!!
    netwatch.set_dnsmasq(true)
    netwatch.set_dnsmasq_rebind_protection(false)
    netwatch.set_dnsmasq_resolv(false)
    netwatch.set_local_resolv(false)
    -- routing
    netwatch.reset_iptables()
    os.execute("sysctl -w net.ipv4.ip_forward=1")
    os.execute('iptables -t nat -I POSTROUTING --out-interface '..netwatch.station..' -j MASQUERADE -m comment --comment "invizbox"')
    os.execute('iptables -I FORWARD -i '..netwatch.access_point..' -o '..netwatch.station..' -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT -m comment --comment "invizbox"')
    os.execute('iptables -I FORWARD -i '..netwatch.station..' -o '..netwatch.access_point..' -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT -m comment --comment "invizbox"')
    os.execute('iptables -I FORWARD -i '..netwatch.access_point..' -o br-lan -d inviz.box -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT -m comment --comment "invizbox"')
    -- waiting
    while netwatch.running do
        local result = netwatch.check_captive_portal()
        if result == false then
            utils.log("we're not behind a captive portal anymore, restarting to deal with it")
            break
        end
        if result == nil then
            utils.log("unable to determine if behind a captive portal or not, restarting to deal with it")
            break
        end
        netwatch.running = netwatch.keep_running()
        utils.sleep(1)
    end
end

function netwatch.network_no_vpn_or_tor(vpn)
    -- status and LED
    netwatch.set_status("wan", "Up")
    netwatch.set_status("vpn", "Down")
    if vpn then
        netwatch.set_status("status", "No VPN Connection")
    else
        netwatch.set_status("status", "No Tor Connection")
    end
    led.orange_flashing()
    utils.log("going orange flashing")
    -- DNS - order matters!!!
    netwatch.set_local_resolv(true)
    netwatch.set_dnsmasq(false)
    netwatch.set_dnsmasq_rebind_protection(true)
    netwatch.set_dnsmasq_resolv(false)
    -- set time
    netwatch.set_time()
    -- routing
    netwatch.reset_iptables()
    os.execute("sysctl -w net.ipv4.ip_forward=1")
    os.execute('iptables -I FORWARD -i '..netwatch.access_point..' -o br-lan -d inviz.box -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT -m comment --comment "invizbox"')
    os.execute('iptables -t nat -I PREROUTING -p tcp --dport 80 --jump DNAT --to-destination 10.153.146.1:80 -m comment --comment "invizbox"')
    os.execute('iptables -t nat -I PREROUTING -p tcp --dport 443 --jump DNAT --to-destination 10.153.146.1:80 -m comment --comment "invizbox"')
    -- waiting
    while netwatch.running do
        if not vpn and netwatch.tor_is_up() then
            utils.log("Tor service successfully connected, restarting to deal with it")
            break
        end
        if netwatch.check_captive_portal() then
            utils.log("we're back behind a captive portal, restarting to deal with it")
            break
        end
        netwatch.running = netwatch.keep_running()
        utils.sleep(5)
    end
end

function netwatch.use_tor()
    -- status and LED
    netwatch.set_status("wan", "Up")
    netwatch.set_status("vpn", "Up")
    netwatch.set_status("status", "Secure Connection - Tor Active")
    led.green_solid()
    utils.log("going green solid")
    -- DNS - order matters!!!
    netwatch.set_dnsmasq(true)
    netwatch.set_dnsmasq_rebind_protection(true)
    netwatch.set_dnsmasq_resolv(false)
    netwatch.set_local_resolv(false)
    -- set time
    netwatch.set_time()
    -- routing
    netwatch.reset_iptables()
    os.execute("sysctl -w net.ipv4.ip_forward=1")
    os.execute('iptables -t nat -I PREROUTING -p udp -m multiport --dport 3478,19302 -j REDIRECT --to-ports 9999 -m comment --comment "invizbox"')
    os.execute('iptables -t nat -I PREROUTING -p udp -m multiport --sport 3478,19302 -j REDIRECT --to-ports 9999 -m comment --comment "invizbox"')
    os.execute('iptables -t nat -I PREROUTING -s 10.153.146.1/24 -p udp --dport 53 -j DNAT --to-destination 172.16.1.1:9053 -m comment --comment "invizbox"')
    os.execute('iptables -t nat -I PREROUTING -s 10.153.146.0/24 \\! -d 10.153.146.1 -p tcp --syn -j DNAT --to-destination 172.16.1.1:9040 -m comment --comment "invizbox"')
    os.execute('iptables -t nat -I OUTPUT -d 10.192.0.0/16 -p tcp --syn -j DNAT --to-destination 172.16.1.1:9040 -m comment --comment "invizbox"')
    -- waiting
    while netwatch.running do
        if netwatch.check_captive_portal() then
            utils.log("we're back behind a captive portal, restarting to deal with it")
            break
        end
        netwatch.running = netwatch.keep_running()
        utils.sleep(20)
    end
end

function netwatch.use_extend()
    -- status and LED
    netwatch.set_status("wan", "Up")
    netwatch.set_status("vpn", "Up")
    netwatch.set_status("status", "Wifi Extender Mode (no VPN or Tor)")
    led.orange_solid()
    utils.log("going orange solid - Wifi extender")
    -- DNS - order matters!!!
    netwatch.set_dnsmasq(true)
    netwatch.set_dnsmasq_rebind_protection(false)
    netwatch.set_dnsmasq_resolv(false)
    netwatch.set_local_resolv(false)
    -- set time
    netwatch.set_time()
    -- routing
    netwatch.reset_iptables()
    os.execute("sysctl -w net.ipv4.ip_forward=1")
    os.execute('iptables -t nat -I POSTROUTING --out-interface '..netwatch.station..' -j MASQUERADE -m comment --comment "invizbox"')
    os.execute('iptables -t nat -I OUTPUT -d 10.192.0.0/16 -p tcp --syn -j DNAT --to-destination 172.16.1.1:9040 -m comment --comment "invizbox"')
    os.execute('iptables -I FORWARD -i '..netwatch.access_point..' -o '..netwatch.station..' -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT -m comment --comment "invizbox"')
    os.execute('iptables -I FORWARD -i '..netwatch.station..' -o '..netwatch.access_point..' -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -m comment --comment "invizbox"')
    os.execute('iptables -I FORWARD -i '..netwatch.access_point..' -o br-lan -d inviz.box -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT -m comment --comment "invizbox"')
    -- waiting
    while netwatch.running do
        netwatch.running = netwatch.keep_running()
        utils.sleep(20)
    end
end

function netwatch.use_vpn()
    -- status and LED
    netwatch.set_status("wan", "Up")
    netwatch.set_status("vpn", "Up")
    netwatch.set_status("status", "Secure Connection - VPN Active")
    led.green_solid()
    utils.log("going green solid")
    -- DNS - order matters!!!
    netwatch.set_dnsmasq(true)
    netwatch.set_dnsmasq_rebind_protection(true)
    netwatch.set_dnsmasq_resolv(true)
    netwatch.set_local_resolv(false)
    -- set time
    netwatch.set_time()
    -- routing
    netwatch.reset_iptables()
    os.execute("sysctl -w net.ipv4.ip_forward=1")
    os.execute('iptables -t nat -I OUTPUT -d 10.192.0.0/16 -p tcp --syn -j DNAT --to-destination 172.16.1.1:9040 -m comment --comment "invizbox"')
    os.execute("iptables -t nat -I POSTROUTING --out-interface "..netwatch.vpn.." -j MASQUERADE")
    os.execute('iptables -I FORWARD -i '..netwatch.access_point..' -o '..netwatch.vpn..' -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT -m comment --comment "invizbox"')
    os.execute('iptables -I FORWARD -i '..netwatch.vpn..' -o '..netwatch.access_point..' -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -m comment --comment "invizbox"')
    os.execute('iptables -I FORWARD -i '..netwatch.access_point..' -o br-lan -d inviz.box -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT -m comment --comment "invizbox"')
    -- waiting
    while netwatch.running do
        if netwatch.check_captive_portal() then
            utils.log("we're back behind a captive portal, restarting to deal with it")
            break
        end
        netwatch.running = netwatch.keep_running()
        utils.sleep(20)
    end
end

function netwatch.cant_determine_portal()
    -- status and LED
    netwatch.set_status("wan", "Up")
    netwatch.set_status("vpn", "Down")
    netwatch.set_status("status", "Error with Internet Connection")
    led.red_green_flashing()
    -- DNS - order matters!!!
    netwatch.set_local_resolv(true)
    netwatch.set_dnsmasq(false)
    netwatch.set_dnsmasq_rebind_protection(true)
    netwatch.set_dnsmasq_resolv(false)
    -- routing
    netwatch.reset_iptables()
    os.execute("sysctl -w net.ipv4.ip_forward=1")
    os.execute('iptables -I FORWARD -i '..netwatch.access_point..' -o br-lan -d inviz.box -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT -m comment --comment "invizbox"')
    os.execute('iptables -t nat -I PREROUTING -p tcp --dport 80 --jump DNAT --to-destination 10.153.146.1:80 -m comment --comment "invizbox"')
    os.execute('iptables -t nat -I PREROUTING -p tcp --dport 443 --jump DNAT --to-destination 10.153.146.1:80 -m comment --comment "invizbox"')
    -- waiting
    while netwatch.running do
        local result = netwatch.check_captive_portal()
        if result == true then
            utils.log("we managed to determine that we are behind a captive portal, restarting to deal with it")
            break
        end
        if result == false then
            utils.log("we managed to determine that we are not behind a captive portal, restarting to deal with it")
            break
        end
        netwatch.running = netwatch.keep_running()
        utils.sleep(3)
    end
end

function netwatch.main()
    netwatch.running=true
    local return_value
    utils.log("Starting netwatch")

    local config_name = "vpn"
    uci:load(config_name)
    local mode = uci:get(config_name, "active", "mode") or "none"
    utils.log("currently in "..mode.." mode")
    network = network.init()
    local interface_up = {}
    for _, interface in pairs(network.get_interfaces()) do
        if interface.dev then
            interface_up[interface.ifname]=interface.dev.flags.up
        else
            interface_up[interface.ifname]=false
        end
    end
    if not interface_up[netwatch.station] then
        utils.log(netwatch.station.." interface is not up - doing nothing until this changes.")
        netwatch.no_network()
        return_value = 2
    else
        utils.log(netwatch.station.." interface is up.")
        if mode == netwatch.vpn_mode and interface_up[netwatch.vpn] then
            utils.log("VPN mode - "..netwatch.vpn.." interface is up - using VPN configuration.")
            netwatch.use_vpn()
            return_value = 6
        elseif mode == netwatch.tor_mode and netwatch.tor_is_up() then
            utils.log("Tor mode - "..netwatch.tor.." interface is up - using Tor configuration.")
            netwatch.use_tor()
            return_value = 7
        elseif mode == "extend" then
            utils.log("Wifi extender mode - using extend configuration.")
            netwatch.use_extend()
            return_value = 8
        else
            if mode == netwatch.vpn_mode then
                utils.log(netwatch.vpn.." interface is not up - checking for captive portal.")
            else
                utils.log("Tor service is not up - checking for captive portal.")
            end
            local captive_portal = netwatch.check_captive_portal()
            if captive_portal == true then
                utils.log("behind captive portal!")
                netwatch.captive_portal()
                return_value = 3
            elseif captive_portal == false then
                utils.log("not behind captive portal")
                netwatch.network_no_vpn_or_tor(mode == netwatch.vpn_mode)
                return_value = 4
            else
                utils.log("unable to determine if behind a captive portal or not - going captive until solved")
                netwatch.cant_determine_portal()
                return_value = 5
            end
        end
    end
    utils.log("Stopping netwatch")
    return return_value
end

if not pcall(getfenv, 4) then
    netwatch.main()
end

return netwatch
