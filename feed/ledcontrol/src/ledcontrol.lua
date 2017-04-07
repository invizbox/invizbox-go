#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Deals with the colour and state of the WiFi LED

local uci = require("uci").cursor()

local led = {}
led.config="system"

function led.get_leds()
    local leds = {}
    uci:load(led.config)
    uci:foreach(led.config, "led", function(s)
        table.insert(leds, s['.name'])
    end)
    return leds[1], leds[2]
end

function led.set_solid(self)
    uci:load(led.config)
    uci:set(led.config, self, "default", "1")
    uci:set(led.config, self, "trigger", "defaulton")
    uci:save(led.config)
    uci:commit(led.config)
end

function led.set_flashing(self)
    uci:load(led.config)
    uci:set(led.config, self, "default", "1")
    uci:set(led.config, self, "trigger", "heartbeat")
    uci:save(led.config)
    uci:commit(led.config)
end

function led.set_off(self)
    uci:load(led.config)
    uci:set(led.config, self, "default", "0")
    uci:set(led.config, self, "trigger", "none")
    uci:save(led.config)
    uci:commit(led.config)
end

function led.red_solid()
    local red, green = led.get_leds()
    led.set_solid(red)
    led.set_off(green)
    os.execute("/etc/init.d/led reload")
end

function led.orange_solid()
    local red, green = led.get_leds()
    led.set_solid(red)
    led.set_solid(green)
    os.execute("/etc/init.d/led reload")
end

function led.green_solid()
    local red, green = led.get_leds()
    led.set_off(red)
    led.set_solid(green)
    os.execute("/etc/init.d/led reload")
end

function led.red_flashing()
    local red, green = led.get_leds()
    led.set_flashing(red)
    led.set_off(green)
    os.execute("/etc/init.d/led reload")
end

function led.orange_flashing()
    local red, green = led.get_leds()
    led.set_flashing(red)
    led.set_flashing(green)
    os.execute("/etc/init.d/led reload")
end

function led.green_flashing()
    local red, green = led.get_leds()
    led.set_off(red)
    led.set_flashing(green)
    os.execute("/etc/init.d/led reload")
end

function led.red_green_flashing()
    local red, green = led.get_leds()
    led.set_solid(red)
    led.set_flashing(green)
    os.execute("/etc/init.d/led reload")
end

return led
