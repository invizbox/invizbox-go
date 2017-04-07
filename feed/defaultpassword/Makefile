# Copyright (C) 2016 Invizbox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=defaultpassword
PKG_VERSION:=0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/defaultpassword

include $(INCLUDE_DIR)/package.mk

define Package/defaultpassword
	SECTION:=invizbox
	CATEGORY:=Invizbox
	DEPENDS:=+luasocket
	TITLE:=Default Password Setter
endef

define Package/defaultpassword/description
	Provides the a script to set the default password from hardware after new flash
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/uci-defaults
	$(CP) ./uci-defaults/* $(PKG_BUILD_DIR)/uci-defaults/
endef

define Build/Compile
endef

define Package/defaultpassword/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/uci-defaults/* $(1)/etc/uci-defaults/
endef

$(eval $(call BuildPackage,defaultpassword))
