#!/bin/bash
# build-apk-docker.sh
# Builds luci-app-starlink-panel as a proper OpenWrt 25+ APK using the OpenWrt SDK in Docker.

set -e

PKG="luci-app-starlink-panel"
OPENWRT_VER="25.12.0-rc5"
ARCH="aarch64_cortex-a53"
SDK_IMAGE="openwrt/sdk:${ARCH}-${OPENWRT_VER}"

echo "================================================"
echo " Building ${PKG} APK for OpenWrt ${OPENWRT_VER}"
echo " Target: ${ARCH} (GL-iNet Beryl AX / MT3000)"
echo "================================================"
echo ""

if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "${SCRIPT_DIR}/output"

# Reuse signing keys from luci-fan project
KEY_DIR="/home/mike/claude/luci-fan/luci-app-fancontrol/keys"
PRIVATE_KEY_P8="${KEY_DIR}/luci-fancontrol-signing-p8.pem"
PUBLIC_KEY="${KEY_DIR}/luci-fancontrol-signing.pub"

if [ ! -f "${PRIVATE_KEY_P8}" ]; then
  echo "ERROR: Signing key not found at ${PRIVATE_KEY_P8}"
  exit 1
fi

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

docker run --rm \
  -v "${SCRIPT_DIR}:/pkg-src:ro" \
  -v "${SCRIPT_DIR}/output:/output" \
  -v "${PRIVATE_KEY_P8}:/signing-key/key-build-p8:ro" \
  -v "${PUBLIC_KEY}:/signing-key/luci-fancontrol-signing.pub:ro" \
  --user root \
  -e HOST_UID="${HOST_UID}" \
  -e HOST_GID="${HOST_GID}" \
  "${SDK_IMAGE}" \
  /bin/bash -c '
    set -e

    SDK_DIR="/builder"
    cd "$SDK_DIR"

    echo "--- Setting up package feed ---"
    mkdir -p package/luci-app-starlink-panel/files
    cp /pkg-src/Makefile package/luci-app-starlink-panel/Makefile
    cp /pkg-src/files/*  package/luci-app-starlink-panel/files/

    echo "--- Updating feeds ---"
    ./scripts/feeds update -a 2>&1 | tail -5
    ./scripts/feeds install -a 2>&1 | tail -5

    echo "--- Configuring ---"
    make defconfig 2>&1 | tail -3
    echo "CONFIG_PACKAGE_luci-app-starlink-panel=m" >> .config
    make defconfig 2>&1 | tail -3

    echo "--- Compiling ---"
    make package/luci-app-starlink-panel/compile V=s 2>&1 | tail -20

    echo "--- Copying output ---"
    APK=$(find bin/ -name "luci-app-starlink-panel*.apk" -type f | head -1)
    cp "$APK" /output/
    echo "Copied: $APK"

    echo "--- Signing APK ---"
    /builder/staging_dir/host/bin/apk --allow-untrusted adbsign \
      --sign-key /signing-key/key-build-p8 \
      /output/$(basename "$APK")

    echo "--- Verifying ---"
    /builder/staging_dir/host/bin/apk verify \
      --keys-dir /signing-key \
      /output/$(basename "$APK")

    chown "${HOST_UID}:${HOST_GID}" /output/$(basename "$APK")
    ls -lh /output/$(basename "$APK")
  '

echo ""
echo "================================================"
ls -lh "${SCRIPT_DIR}/output/"luci-app-starlink-panel* 2>/dev/null && \
  echo "Success!" || echo "No output — check errors above"
echo "================================================"
echo ""
echo "Install on router (signed — needs key in /etc/apk/keys/):"
echo "  scp -O output/luci-app-starlink-panel-*.apk root@192.168.1.1:/tmp/"
echo "  ssh root@192.168.1.1 'apk add /tmp/luci-app-starlink-panel-*.apk'"
echo ""
echo "Or without key verification:"
echo "  ssh root@192.168.1.1 'apk add --allow-untrusted /tmp/luci-app-starlink-panel-*.apk'"
