include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-starlink-panel
PKG_VERSION:=1.0.0
PKG_RELEASE:=15

PKG_MAINTAINER:=bigmalloy
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-starlink-panel
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI Starlink Status Dashboard
  URL:=https://github.com/bigmalloy/starlink-openwrt
  DEPENDS:=+luci-base +rpcd +jsonfilter
  PKGARCH:=all
endef

define Package/luci-app-starlink-panel/description
  LuCI dashboard for Starlink dish telemetry, IPv6 connectivity,
  traffic, alignment, alerts, and router configuration. Requires
  grpcurl at /usr/bin/grpcurl for dish gRPC data.
endef

define Build/Compile
endef

define Package/luci-app-starlink-panel/install
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./files/luci.starlink-panel \
		$(1)/usr/libexec/rpcd/luci.starlink-panel

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./files/luci-app-starlink-panel-menu.json \
		$(1)/usr/share/luci/menu.d/luci-app-starlink-panel.json

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/luci-app-starlink-panel-acl.json \
		$(1)/usr/share/rpcd/acl.d/luci-app-starlink-panel.json

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/starlink-panel
	$(INSTALL_DATA) ./files/status.js \
		$(1)/www/luci-static/resources/view/starlink-panel/status.js

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/install-grpcurl.sh \
		$(1)/usr/bin/install-grpcurl
endef

define Package/luci-app-starlink-panel/preinst
#!/bin/sh
mkdir -p /www/luci-static/resources/view/starlink-panel
exit 0
endef

define Package/luci-app-starlink-panel/postinst
#!/bin/sh
# setsid creates a new process group, fully detaching from apk so the
# LuCI XHR response completes before uhttpd restarts.
setsid sh -c '{
    /usr/bin/install-grpcurl || echo "Warning: grpcurl install failed. Run /usr/bin/install-grpcurl manually."
    [ -f /etc/init.d/rpcd ]   && /etc/init.d/rpcd restart
    [ -f /etc/init.d/uhttpd ] && rm -rf /tmp/luci-modulecache /tmp/luci-indexcache
    [ -f /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart
}' </dev/null >/dev/null 2>&1 &
exit 0
endef

define Package/luci-app-starlink-panel/prerm
#!/bin/sh
exit 0
endef

$(eval $(call BuildPackage,luci-app-starlink-panel))
