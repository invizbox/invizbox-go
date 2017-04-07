#@IgnoreInspection BashAddShebang
# Copyright (C) 2016 Invizbox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=vpnwatch
PKG_VERSION:=0.0
PKG_RELEASE:=2

PKG_BUILD_DIR:=$(BUILD_DIR)/vpnwatch

include $(INCLUDE_DIR)/package.mk

define Package/vpnwatch
	SECTION:=invizbox
	CATEGORY:=Invizbox
	DEPENDS:=+invizboxutils +openvpn-openssl +diffutils
	TITLE:=Network Watcher
endef

define Package/vpnwatch/description
	Monitors the vpn config file to identify changes in active vpn setting and propagate to openvpn
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/src
	mkdir -p $(PKG_BUILD_DIR)/root
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
	$(CP) ./root/* $(PKG_BUILD_DIR)/root/
endef

define Build/Compile
endef

define Package/vpnwatch/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/* $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
endef

define Package/vpnwatch/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Enabling rc.d symlink for vpnwatch"
	/etc/init.d/vpnwatch enable
fi
exit 0
endef

define Package/vpnwatch/prerm
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Removing rc.d symlink for vpnwatch"
	/etc/init.d/vpnwatch disable
fi
exit 0
endef

$(eval $(call BuildPackage,vpnwatch))
