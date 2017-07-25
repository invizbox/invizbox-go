# Copyright (C) 2016 Invizbox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=wizard
PKG_VERSION:=0.0
PKG_RELEASE:=3

PKG_BUILD_DIR:=$(BUILD_DIR)/wizard

include $(INCLUDE_DIR)/package.mk

define Package/wizard
	SECTION:=invizbox
	CATEGORY:=Invizbox
	DEPENDS:=+luci-theme-material +torcheck +luci-app-adblock +ca-bundle +ca-certificates +libustream-openssl
	TITLE:=Configuration Wizard
endef

define Package/wizard/conffiles
	/etc/config/wizard
endef

define Package/wizard/description
	The initial launch and configuration wizard for a new InvizBox Go	
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/src
	mkdir -p $(PKG_BUILD_DIR)/resources
	mkdir -p $(PKG_BUILD_DIR)/root
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
	$(CP) ./resources/* $(PKG_BUILD_DIR)/resources
	$(CP) ./root/* $(PKG_BUILD_DIR)/root/
endef

define Build/Compile
endef

define Package/wizard/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(CP) $(PKG_BUILD_DIR)/src/luci/*  $(1)/usr/lib/lua/luci/
	$(INSTALL_DIR) $(1)/www
	$(CP) $(PKG_BUILD_DIR)/src/www/*  $(1)/www/
	$(INSTALL_DIR) $(1)/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(INSTALL_DIR) $(1)/www/luci-static/img
	$(INSTALL_DIR) $(1)/www/luci-static/js
	$(INSTALL_DIR) $(1)/www/luci-static/material
	$(CP) $(PKG_BUILD_DIR)/resources/img/* $(1)/www/luci-static/img
	$(CP) $(PKG_BUILD_DIR)/resources/3rdparty/img/* $(1)/www/luci-static/img
	$(CP) $(PKG_BUILD_DIR)/resources/3rdparty/js/* $(1)/www/luci-static/js
	$(CP) $(PKG_BUILD_DIR)/resources/3rdparty/font-awesome/* $(1)/www/luci-static/material
	$(CP) $(PKG_BUILD_DIR)/resources/media/* $(1)/www/luci-static/material
endef

define Package/wizard/preinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "Saving wizard state"
    cp /etc/config/wizard /tmp/wizard
fi
exit 0
endef

define Package/wizard/postinst
#!/bin/sh
echo "touch known_networks if needed"
touch $${IPKG_INSTROOT}/etc/config/known_networks
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "Restoring wizard state"
    cp /tmp/wizard /etc/config/wizard
fi
exit 0
endef

$(eval $(call BuildPackage,wizard))
