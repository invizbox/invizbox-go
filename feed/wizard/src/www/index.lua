#!/usr/bin/lua
local uci = require("uci").cursor()
local util = require "luci.util"
local sys = require "luci.sys"

print([[Content-Type: text/html

<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
<meta http-equiv="Pragma" content="no-cache" />
<meta http-equiv="Expires" content="0" />]])

local wizard_complete = uci:load("wizard") and uci:get("wizard", "main", "complete") ~= "false"
if not wizard_complete then
    local token, sess
    uci:load("luci")
    local timeout = tonumber(uci:get("luci.sauth.sessiontime"))
    local sdat = util.ubus("session", "create", { timeout = timeout })
    if sdat then
        token = sys.uniqueid(16)
        util.ubus("session", "set", {
            ubus_rpc_session = sdat.ubus_rpc_session,
            values = {
                user = "root",
                token = token,
                section = sys.uniqueid(16)
            }
        })
        sess = sdat.ubus_rpc_session
    end

    if sess and token then
        local cookie_header = 'sysauth=%s; path=/cgi-bin/luci/' % { sess }
        print('<meta http-equiv="Set-Cookie" content="' .. cookie_header .. '" />')
    end
end

if wizard_complete then
    print('<meta http-equiv="refresh" content="0; URL=/cgi-bin/luci" />')
else
    print('<meta http-equiv="refresh" content="0; URL=/wizard.html" />')
end

print([[</head>
<body style="background-color: white">
<a style="color: black; font-family: arial, helvetica, sans-serif;" href="/cgi-bin/luci">LuCI - Lua Configuration Interface</a>
</body>
</html>]])
