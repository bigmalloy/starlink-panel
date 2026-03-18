#!/bin/sh
# install-grpcurl.sh — install starlink-dish (primary) and grpcurl (fallback)
#
# Run on the router after copying the APK:
#   /usr/bin/install-grpcurl      (called automatically by APK postinst)
#
# Or manually:
#   ssh root@192.168.1.1 '/usr/bin/install-grpcurl'

set -e

ARCH=$(uname -m)

# ── starlink-dish (primary gRPC client) ───────────────────────────────────────

DISH_PATH="/usr/bin/starlink-dish"
DISH_RELEASE="https://github.com/bigmalloy/starlink-panel/releases/latest/download/starlink-dish"

install_starlink_dish() {
    case "$ARCH" in
        aarch64) ;;
        *)
            echo "starlink-dish: pre-built binary only available for aarch64; skipping."
            return 1
            ;;
    esac

    echo "Downloading starlink-dish..."
    if wget -q -O "${DISH_PATH}.tmp" "$DISH_RELEASE" 2>/dev/null; then
        mv "${DISH_PATH}.tmp" "$DISH_PATH"
        chmod +x "$DISH_PATH"
        echo "Installed: $DISH_PATH"
        return 0
    else
        rm -f "${DISH_PATH}.tmp"
        echo "Warning: starlink-dish download failed; falling back to grpcurl."
        return 1
    fi
}

if [ -x "$DISH_PATH" ]; then
    echo "starlink-dish already installed."
else
    install_starlink_dish || true
fi

# ── grpcurl (fallback) ────────────────────────────────────────────────────────

GRPCURL_VERSION="1.9.3"
GRPCURL_PATH="/usr/bin/grpcurl"
BASE_URL="https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}"

# Skip grpcurl if starlink-dish is available
if [ -x "$DISH_PATH" ]; then
    echo "starlink-dish present — skipping grpcurl install."
    exit 0
fi

if [ -x "$GRPCURL_PATH" ]; then
    CURRENT=$("$GRPCURL_PATH" --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    if [ "$CURRENT" = "$GRPCURL_VERSION" ]; then
        echo "grpcurl v${GRPCURL_VERSION} already installed."
        exit 0
    fi
fi

case "$ARCH" in
    aarch64)   GRPCURL_ARCH="linux_arm64"  ;;
    x86_64)    GRPCURL_ARCH="linux_x86_64" ;;
    armv7l)    GRPCURL_ARCH="linux_armv7"  ;;
    armv6l)    GRPCURL_ARCH="linux_armv6"  ;;
    i386|i686) GRPCURL_ARCH="linux_386"    ;;
    *)
        echo "ERROR: Unsupported arch $ARCH; install grpcurl manually from $BASE_URL"
        exit 1
        ;;
esac

TARBALL="grpcurl_${GRPCURL_VERSION}_${GRPCURL_ARCH}.tar.gz"
echo "Downloading grpcurl..."
cd /tmp
wget -q -O "$TARBALL" "${BASE_URL}/${TARBALL}"
tar xzf "$TARBALL" grpcurl
mv grpcurl "$GRPCURL_PATH"
chmod +x "$GRPCURL_PATH"
rm -f "$TARBALL"
echo "Installed: $("$GRPCURL_PATH" --version 2>&1)"
