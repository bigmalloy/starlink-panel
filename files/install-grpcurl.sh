#!/bin/sh
# install-grpcurl.sh — download and install grpcurl on OpenWrt
#
# Run this on the router:
#   sh /tmp/install-grpcurl.sh
#
# Or from your dev machine:
#   scp -O install-grpcurl.sh root@192.168.1.1:/tmp/
#   ssh root@192.168.1.1 'sh /tmp/install-grpcurl.sh'

set -e

GRPCURL_VERSION="1.9.3"
INSTALL_PATH="/usr/bin/grpcurl"
BASE_URL="https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}"

# ── Check if already installed ────────────────────────────────────────────────

if [ -x "$INSTALL_PATH" ]; then
    CURRENT=$("$INSTALL_PATH" --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    if [ "$CURRENT" = "$GRPCURL_VERSION" ]; then
        echo "grpcurl v${GRPCURL_VERSION} is already installed."
        exit 0
    else
        echo "grpcurl v${CURRENT} found, upgrading to v${GRPCURL_VERSION}..."
    fi
fi

# ── Detect architecture ───────────────────────────────────────────────────────

ARCH=$(uname -m)
case "$ARCH" in
    aarch64)           GRPCURL_ARCH="linux_arm64" ;;
    x86_64)            GRPCURL_ARCH="linux_x86_64" ;;
    armv7l)            GRPCURL_ARCH="linux_armv7" ;;
    armv6l)            GRPCURL_ARCH="linux_armv6" ;;
    i386|i686)         GRPCURL_ARCH="linux_386" ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        echo "Download manually from: ${BASE_URL}"
        exit 1
        ;;
esac

TARBALL="grpcurl_${GRPCURL_VERSION}_${GRPCURL_ARCH}.tar.gz"
URL="${BASE_URL}/${TARBALL}"

# ── Download and install ──────────────────────────────────────────────────────

echo "Architecture : $ARCH -> $GRPCURL_ARCH"
echo "Downloading  : $URL"

cd /tmp
wget -O "$TARBALL" "$URL"
tar xzf "$TARBALL" grpcurl
mv grpcurl "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
rm -f "$TARBALL"

# ── Verify ────────────────────────────────────────────────────────────────────

echo ""
echo "Installed: $("$INSTALL_PATH" --version 2>&1)"
echo ""
echo "Testing dish connection..."
if grpcurl -plaintext -connect-timeout 5 \
    -d '{"getStatus":{}}' 192.168.100.1:9200 \
    SpaceX.API.Device.Device/Handle > /dev/null 2>&1; then
    echo "Dish reachable — grpcurl working correctly."
else
    echo "Dish not reachable (is the Starlink connected to WAN?)."
    echo "grpcurl is installed correctly — dish connection test failed."
fi
