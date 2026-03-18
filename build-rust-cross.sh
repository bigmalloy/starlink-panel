#!/bin/bash
# build-rust-cross.sh
# Cross-compiles starlink-dish for aarch64-unknown-linux-musl (OpenWrt).
# Requires Docker (uses messense/rust-musl-cross image — no local Rust needed).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="aarch64-unknown-linux-musl"
IMAGE="messense/rust-musl-cross:aarch64-musl"
OUT="${SCRIPT_DIR}/rust-src/target/${TARGET}/release/starlink-dish"

echo "================================================"
echo " Cross-compiling starlink-dish"
echo " Target: ${TARGET}"
echo " Image:  ${IMAGE}"
echo "================================================"

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running."
    exit 1
fi

docker run --rm \
    -v "${SCRIPT_DIR}/rust-src":/app \
    -w /app \
    "${IMAGE}" \
    bash -c '
        set -e
        # Install protoc 21.12 — oldest version with native proto3 optional support.
        # System protoc (3.12 on Ubuntu 22.04) does not support proto3 optional fields.
        apt-get update -qq && apt-get install -y unzip wget
        PROTOC_VER="21.12"
        wget -q "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VER}/protoc-${PROTOC_VER}-linux-x86_64.zip" \
            -O /tmp/protoc.zip
        unzip -q /tmp/protoc.zip -d /usr/local bin/protoc
        rm /tmp/protoc.zip
        export PROTOC=/usr/local/bin/protoc
        cargo build --release
    '

echo ""
if [ -f "${OUT}" ]; then
    SIZE=$(ls -lh "${OUT}" | awk '{print $5}')
    echo "Binary: ${OUT} (${SIZE})"
    echo "SHA256: $(sha256sum "${OUT}" | awk '{print $1}')"
    echo ""
    echo "Copy to output/:"
    cp "${OUT}" "${SCRIPT_DIR}/output/starlink-dish"
    echo "  output/starlink-dish"
else
    echo "ERROR: Binary not found at ${OUT}"
    exit 1
fi

echo ""
echo "================================================"
echo " Done. Install on router:"
echo "  scp -O output/starlink-dish root@192.168.1.1:/usr/bin/"
echo "  ssh root@192.168.1.1 'chmod +x /usr/bin/starlink-dish'"
echo "================================================"
