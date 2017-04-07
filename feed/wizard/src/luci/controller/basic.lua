-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- controller entry point for the configuration wizard
local basic = {}

-- luacheck: globals entry cbi _ alias node template luci call action_logout
function basic.index()
    local root = node()
    if not root.lock then
        root.target = alias("basic","basic")
        root.index = true
    end

    local page   = node("basic")
-- entry({"basic"}, alias("basic", "basic"), _("Status"), 20)
    page.sysauth = "root"
    page.order = 20
    page.sysauth_authenticator = "htmlauth"
    page.index = true

    entry({"basic", "basic"}, template("admin_status/index"), _("Status"), 20).index = true
    entry({"basic", "invizbox"}, alias("basic","invizbox","vpn_location"), _("InvizBox Go"), 30).index = true
    entry({"basic","invizbox", "vpn_location"}, cbi("vpn_location", {autoapply=true, hideapplybtn=true, hideresetbtn=true , noheader=true,nofooter=true}), _("VPN Location"), 31)
    entry({"basic","invizbox", "choose_network"}, cbi("choose_network", {autoapply=true, hideapplybtn=true, hideresetbtn=true , noheader=true,nofooter=true}), _("Choose Network"), 32)
    entry({"basic","invizbox", "privacy_mode"}, cbi("privacy_mode", {autoapply=true, hideapplybtn=true, hideresetbtn=true , noheader=true,nofooter=true}), _("Privacy Mode"), 33)
    entry({"basic","invizbox", "chotspot"}, cbi("hotspot", {autoapply=true, hideapplybtn=true, hideresetbtn=true , noheader=true,nofooter=true}), _("Hotspot"), 34)
    entry({"basic","invizbox", "account_details"}, cbi("account_details", {autoapply=true, hideapplybtn=true, hideresetbtn=true , noheader=true,nofooter=true}), _("Account Details"), 35)
    entry({"basic", "logout"}, call("action_logout"), _("Logout"), 90)
    entry({"basic", "mode"}, alias("admin","status"), _("Expert Mode"), 91)
    local ent = entry({"wizard", "complete"}, template("wizard_complete"), "Wizard Complete", 99)
    ent.dependent = false
    ent.sysauth = "root"
end

function action_logout()
	local dsp = require "luci.dispatcher"
	local utl = require "luci.util"
	local sid = dsp.context.authsession

	if sid then
		utl.ubus("session", "destroy", { ubus_rpc_session = sid })

		luci.http.header("Set-Cookie", "sysauth=%s; expires=%s; path=%s/" %{
			sid, 'Thu, 01 Jan 1970 01:00:00 GMT', dsp.build_url()
		})
	end

	luci.http.redirect(dsp.build_url())
end

return basic
