# SPDX-License-Identifier: MIT
include $(TOPDIR)/rules.mk

PKG_NAME:=starlink-dish
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/bigmalloy/starlink-panel/releases/download/v$(PKG_VERSION)/
PKG_HASH:=3a2af795a91f9a8af1e8e49c16e7b3e94d7f11bebb8964682d69e744e6659596

PKG_MAINTAINER:=Mike Eiberg <eiberg.michael@gmail.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=rust/host protobuf/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk

define Package/starlink-dish
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Starlink dish gRPC client
  URL:=https://github.com/bigmalloy/starlink-panel
  DEPENDS:=$(RUST_ARCH_DEPENDS)
endef

define Package/starlink-dish/description
  CLI tool that queries the Starlink dish gRPC API and outputs
  JSON telemetry. Supports 'dish' (full status) and 'reboot' commands.
  Used by luci-app-starlink-panel; can also be called from scripts.
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/.cargo
	printf '[source.crates-io]\nreplace-with = "vendored-sources"\n\n[source.vendored-sources]\ndirectory = "vendor/"\n' \
		> $(PKG_BUILD_DIR)/.cargo/config.toml
endef

define Build/Compile
	+$(CARGO_PKG_VARS) \
		PROTOC=$(STAGING_DIR_HOST)/bin/protoc \
		cargo build \
			--manifest-path $(PKG_BUILD_DIR)/Cargo.toml \
			--locked \
			--release \
			$(if $(filter -j%,$(PKG_JOBS)),$(PKG_JOBS),-j1)
endef

define Package/starlink-dish/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) \
		$(PKG_BUILD_DIR)/target/$(RUST_TARGET)/release/starlink-dish \
		$(1)/usr/bin/starlink-dish
endef

$(eval $(call BuildPackage,starlink-dish))
