# Copyright (C) 2016 Invizbox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=update
PKG_VERSION:=1.2
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/update

include $(INCLUDE_DIR)/package.mk

define Package/update
	SECTION:=invizbox
	CATEGORY:=Invizbox
	DEPENDS:=+unzip +invizboxutils +coreutils +coreutils-sha256sum +tor
	TITLE:=VPN Config Downloader
endef

define Package/update/description
	Provides the functionality required to download up to date VPN configuration are regular interval
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

define Package/update/preinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "Saving vpn.active"
    echo "#!/bin/ash" > /tmp/vpn_backup.ash
    uci show vpn.active | sed 's/^/uci set /' >> /tmp/vpn_backup.ash
    echo "uci commit vpn" >> /tmp/vpn_backup.ash
    echo "/sbin/reload_config vpn" >> /tmp/vpn_backup.ash
    chmod a+x /tmp/vpn_backup.ash
fi
exit 0
endef

define Package/update/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "Loading vpn.active back in"
    /tmp/vpn_backup.ash
fi
exit 0
endef

define Package/update/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/* $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/* $(1)/bin/
	$(INSTALL_DIR) $(1)/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
endef

$(eval $(call BuildPackage,update))
