This repository contains the code to build an InvizBox Go firmware.

## Current Issues

### WiFi Driver (potentially making this build a non runner)

This build is using the open-source driver implementation for the MT7903e chip.  We're working
towards using this driver ourselves for our official releases but are still currently using a driver we build from 
proprietary Mediatek code (with some modifications) for stability and speed.

This build seems to be stable in some WiFi environments but crashes almost instantly in others.
This is something that we would love to see addressed but unfortunately it is taking a lot of resources.

Hopefully, progress on the driver will mean that future versions of this build will work much better.

If you want to help in that area, you are more than welcome to!

The main symptom of a crashed driver is that the speed barely reaches 20kpbs and this renders the device unusable.

## Before building

### VPN Settings
* Edit the files in `src/files/etc/openvpn` so that they contain your own VPN configuration files
The files that are already there contain more information to help you initially.

  * `openvpn.conf` should contain your default config
  * `files/` should contains OVPN files 
  * `templates/` can be create templates if your ovpn files are identical apart from the server IP/hostname

* Edit `src/files/etc/config/vpn` as it should now be modified to define your VPN locations based on what you created 
in the previous point.

Note: If you own an original Go, you can duplicate the /etc/openvpn setup from it to get started.

### Default Password
* If you own an original Go and you want the passwords to be set to the flashed defaults, you can enable the 
`CONFIG_PACKAGE_defaultpassword` setting in the src/.config file
* If you DO NOT own an original Go and are trying to flash on another router, DO NOT enable 
`CONFIG_PACKAGE_defaultpassword` or you will most likely be locked out of your device and require a recovery via 
serial/tftp...

### WiFi Drivers
The firmware you build here will not be identical to the one we deliver as it uses the open-source driver.

It should however be functional and allow you to tweak your Go firmware.

### Updating
If you want to get VPN updates, opkg updates and firmware updates from the Invizbox update server, you can enable the 
`CONFIG_PACKAGE_update` setting in the src/.config file.

### DNS and DNS leaking
If you set up this build to use with an InvizBox VPN account, you can remove `src/files/etc/resolv.conf.vpn`.
Otherwise, it points to the Google DNS servers by default. You may want to change that to a more appropriate set of 
servers to avoid DNS leaking (for example servers provided by your DNS provider)

## Building an InvizBox Go firmware

* Use a build environment in which you can already successfully build OpenWRT
* Run ./build.sh
* Find the sysupgrade file in 
  `lede/bin/targets/ramips/mt7621/invizbox-lede-ramips-mt7621-invizboxgo-squashfs-sysupgrade.bin`

The build.sh script will create a `lede` directory and build your firmware there using the `src/.config` and 
`src/feeds.conf` files.

Enjoy!

The Invizbox Team.