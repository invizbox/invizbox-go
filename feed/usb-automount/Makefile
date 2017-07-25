# Copyright (C) 2016 Invizbox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=usb-automount
PKG_VERSION:=0.0
PKG_RELEASE:=2

PKG_BUILD_DIR:=$(BUILD_DIR)/usb-automount

include $(INCLUDE_DIR)/package.mk

define Package/usb-automount
	SECTION:=invizbox
	CATEGORY:=Invizbox
	TITLE:=Automount USB
endef

define Package/usb-automount/description
	Provides a hotplug.d script that mounts a usb drive on insertion
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/src
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
endef

define Build/Compile
endef

define Package/usb-automount/install
	$(INSTALL_DIR) $(1)/etc/hotplug.d/block
	$(CP) $(PKG_BUILD_DIR)/src/99-usb-automount.sh  $(1)/etc/hotplug.d/block/
endef

$(eval $(call BuildPackage,usb-automount))
