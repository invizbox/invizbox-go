# Copyright (C) 2016 Invizbox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=netwatch
PKG_VERSION:=0.2
PKG_RELEASE:=3

PKG_BUILD_DIR:=$(BUILD_DIR)/netwatch

include $(INCLUDE_DIR)/package.mk

define Package/netwatch
	SECTION:=invizbox
	CATEGORY:=Invizbox
	DEPENDS:=+invizboxutils +ledcontrol +wifiwatch +dnsmasq
	TITLE:=Network Watcher
endef

define Package/netwatch/description
	Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/bin
	mkdir -p $(PKG_BUILD_DIR)/src
	mkdir -p $(PKG_BUILD_DIR)/root
	$(CP) ./bin/* $(PKG_BUILD_DIR)/bin/
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
	$(CP) ./root/* $(PKG_BUILD_DIR)/root/
endef

define Build/Compile
endef

define Package/netwatch/conffiles
	/etc/config/status
endef

define Package/netwatch/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/*  $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/* $(1)/bin/
	$(INSTALL_DIR) $(1)/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(RM) $(1)/etc/dnsmasq.conf
	$(LN) /etc/dnsmasq.conf.captive $(1)/etc/dnsmasq.conf
endef

define Package/netwatch/preinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	ln -sf /tmp/resolv.conf /etc/resolv.conf
fi
exit 0
endef

define Package/netwatch/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Enabling rc.d symlink for netwatch"
	/etc/init.d/netwatch enable
fi
exit 0
endef

define Package/netwatch/prerm
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Removing rc.d symlink for netwatch"
	/etc/init.d/netwatch disable
fi
exit 0
endef

$(eval $(call BuildPackage,netwatch))
