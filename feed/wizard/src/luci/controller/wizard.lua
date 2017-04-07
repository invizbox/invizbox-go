-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- controller entry point for the configuration wizard
local wizard = {}

-- luacheck: globals entry cbi _ alias call luci action_logout
function wizard.index()
    entry({"admin", "invizbox"}, alias("admin","invizbox","hotspot"), _("InvizBox Go"), 30).index = true
    entry({"admin","invizbox", "vpn_location"}, cbi("vpn_location", {autoapply=true, hideapplybtn=true, hideresetbtn=true, noheader=true, nofooter=true}), _("VPN Location"), 31)
    entry({"admin","invizbox", "choose_network"}, cbi("choose_network", {autoapply=true, hideapplybtn=true,hideresetbtn=true, noheader=true, nofooter=true}), _("Choose Network"), 32)
    entry({"admin","invizbox", "privacy_mode"}, cbi("privacy_mode", {autoapply=true, hideapplybtn=true, hideresetbtn=true, noheader=true,nofooter=true}), _("Privacy Mode"), 33)
    entry({"admin","invizbox", "hotspot"}, cbi("hotspot", {autoapply=true, hideapplybtn=true, hideresetbtn=true, noheader=true, nofooter=true}), _("Hotspot"), 34)
    entry({"admin","invizbox", "account_details"}, cbi("account_details", {autoapply=true, hideapplybtn=true, hideresetbtn=true, noheader=true, nofooter=true}), _("Account Details"), 35)
    entry({"admin", "logout"}, call("action_logout"), _("Logout"), 90)
    entry({"admin", "mode"}, alias("basic","basic"), _("Basic Mode"), 91)
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

return wizard
