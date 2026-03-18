#!/bin/sh
# install-grpcurl.sh — install starlink-dish and remove grpcurl if present
#
# Called automatically by APK postinst, or run manually:
#   ssh root@192.168.1.1 '/usr/bin/install-grpcurl'

set -e

ARCH=$(uname -m)
DISH_PATH="/usr/bin/starlink-dish"
DISH_RELEASE="https://github.com/bigmalloy/starlink-panel/releases/latest/download/starlink-dish"

# ── remove grpcurl ────────────────────────────────────────────────────────────

if [ -x /usr/bin/grpcurl ]; then
    echo "Removing grpcurl..."
    rm -f /usr/bin/grpcurl
fi

# ── install starlink-dish ─────────────────────────────────────────────────────

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
        echo "Warning: starlink-dish download failed. Run /usr/bin/install-grpcurl manually."
        return 1
    fi
}

install_starlink_dish || true
