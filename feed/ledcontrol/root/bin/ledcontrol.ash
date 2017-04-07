#!/bin/sh

# /lib/led_funcs.sh bash
#-- Copyright 2016 InvizBox Ltd
#-- https://www.invizbox.com/lic/license.txt
#-- Controll LED states for easy config using UCI 

RedLed="@led[0]"
YellowLed="@led[1]"

#function to set the WiFi led green and solid

led_wifi_green_solid() {
    led_set_off $RedLed 
    led_set_solid $YellowLed
}

#function to set the WiFi led green and flashing
led_wifi_green_flashing() {
    led_set_off $RedLed 
    led_set_flashing $YellowLed
}


#function to set the WiFi led orange and solif
led_wifi_orange_solid() {
    led_set_solid $RedLed 
    led_set_solid $YellowLed
}

#function to set the WiFi led orange and flashing
led_wifi_orange_flashing() {
    led_set_flashing $RedLed 
    led_set_flashing $YellowLed
}

#function to set the WiFi led red and solif
led_wifi_red_solid() {
    led_set_solid $RedLed 
    led_set_off $YellowLed
}

#function to set the WiFi led red and flashing
led_wifi_red_flashing() {
    led_set_flashing $RedLed 
    led_set_off $YellowLed
}

led_wifi_off() {
    led_set_off $YellowLed                
    led_set_off $RedLed                
}

#function to set leds off
led_set_off() {
    /sbin/uci set system.$1.default='0'
    /sbin/uci set system.$1.trigger='none'
    uci_commit_reload
}

#function to set leds flashing
led_set_flashing() {
    /sbin/uci set system.$1.default='1'
    /sbin/uci set system.$1.trigger='heartbeat'
    uci_commit_reload
}

#function to set leds solid
led_set_solid() {
    /sbin/uci set system.$1.default='1'
    /sbin/uci set system.$1.trigger='defaulton'
    uci_commit_reload
}

uci_commit_reload() {
    /sbin/uci commit
    /etc/init.d/led reload
}

