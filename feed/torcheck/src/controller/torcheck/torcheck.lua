-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- controller entry point for the configuration wizard
local torcheck = {}

-- luacheck: globals entry cbi luci call template _ fork_exec restart_tor
function torcheck.index()
    entry({"admin", "invizbox", "tor_configuration"}, cbi("torcheck/tor_configuration"), _("Tor Configuration"), 35).leaf = true
    entry({"admin", "invizbox", "tor_advanced"}, cbi("torcheck/tor_advanced"), _("Tor Advanced"), 36).leaf = true

    entry({"admin", "invizbox", "tor_configuration2"}, template("torcheck/tor_configuration"), nil)
    entry({"admin", "invizbox", "tor_restart"}, call("restart_tor"), nil)
end

function restart_tor()
    local reboot = luci.http.formvalue("reboot")
    fork_exec("/etc/init.d/tor restart;sleep 5")
    luci.template.render("torcheck/tor_configuration", {reboot=reboot})
end

return torcheck
