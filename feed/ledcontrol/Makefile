# Copyright (C) 2016 Invizbox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=ledcontrol
PKG_VERSION:=0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/ledcontrol

include $(INCLUDE_DIR)/package.mk

define Package/ledcontrol
	SECTION:=invizbox
	CATEGORY:=Invizbox
	TITLE:=LED Control
endef

define Package/ledcontrol/description
	This package provides the led controls to set the states of Red/Orange/Green, it also included examples of this control in etc/hotplud.d/iface/99-tun*
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/root
	mkdir -p $(PKG_BUILD_DIR)/src
	$(CP) ./root/* $(PKG_BUILD_DIR)/root/
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
endef

define Build/Compile
endef

define Package/ledcontrol/install
	$(INSTALL_DIR) $(1)/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/*  $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,ledcontrol))
