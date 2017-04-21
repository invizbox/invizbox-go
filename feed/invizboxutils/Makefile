# Copyright (C) 2016 Invizbox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=invizboxutils
PKG_VERSION:=2.0
PKG_RELEASE:=3

PKG_BUILD_DIR:=$(BUILD_DIR)/invizboxutils

include $(INCLUDE_DIR)/package.mk

define Package/invizboxutils
	SECTION:=invizbox
	CATEGORY:=Invizbox
	DEPENDS:=+luasocket +luasec
	TITLE:=Utils needed for other packages
endef

define Package/invizboxutils/description
	Provides the a set of functions that other package need in a central place
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/src
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
endef

define Build/Compile
endef

define Package/invizboxutils/install
    $(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/*  $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,invizboxutils))
