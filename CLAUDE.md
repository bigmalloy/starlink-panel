# starlink-panel — CLAUDE.md

## Project overview

OpenWrt LuCI package (`luci-app-starlink-panel`) providing a Starlink dish dashboard.
Packaged as a signed APK for OpenWrt 25.x (`apk` package manager).
**Current release: v1.0.0-r22**

Companion Rust binary (`starlink-dish`) handles gRPC communication with the dish at
`192.168.100.1:9200`. It replaces grpcurl entirely. Supports `dish` (full telemetry)
and `reboot` commands.

## Repository layout

```
Makefile                        # OpenWrt Makefile — builds the APK
files/
  luci.starlink-panel           # rpcd shell backend (installed to /usr/libexec/rpcd/)
  status.js                     # LuCI JS view
  luci-app-starlink-panel-*.json # menu + ACL
  install-grpcurl.sh            # postinst helper: installs starlink-dish, removes grpcurl
rust-src/
  src/main.rs                   # starlink-dish Rust binary
  Cargo.toml / Cargo.lock
keys/
  starlink-panel-signing.pub    # APK signing public key (committed for raw GitHub URL)
build-apk-docker.sh             # builds the APK using openwrt/sdk Docker image
build-rust-cross.sh             # cross-compiles starlink-dish for aarch64-musl via Docker
output/                         # built APKs and starlink-dish binary land here
docs/
  screenshot.png                # dashboard screenshot (used in README)
  openwrt-forum-post.txt        # draft OpenWrt forum post
openwrt-feed/                   # official OpenWrt feed submission structure
  net/starlink-dish/Makefile    # → openwrt/packages PR #28890
  luci/applications/luci-app-starlink-panel/  # → openwrt/luci PR #8441
```

## Build commands

### Build the APK
```sh
./build-apk-docker.sh
# Output: output/luci-app-starlink-panel-1.0.0-rN.apk
```
Uses `openwrt/sdk:aarch64_cortex-a53-25.12.0-rc5` Docker image.
Signing key is at `/home/mike/claude/luci-fan/luci-app-fancontrol/keys/`.

### Cross-compile starlink-dish binary
```sh
./build-rust-cross.sh
# Output: output/starlink-dish  (aarch64 musl, ~1.4 MB stripped)
```
Uses `messense/rust-musl-cross:aarch64-musl` Docker image with protoc 21.12.

### Deploy directly to router
```sh
scp -O output/luci-app-starlink-panel-*.apk root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'apk add --allow-untrusted /tmp/luci-app-starlink-panel-*.apk'

# Force-update starlink-dish binary (postinst always re-downloads):
ssh root@192.168.1.1 '/usr/bin/install-grpcurl'

# Or push the locally built binary directly:
scp -O output/starlink-dish root@192.168.1.1:/usr/bin/starlink-dish
```

### Release process
1. Bump `PKG_RELEASE` in `Makefile`
2. `./build-apk-docker.sh`
3. If Rust changed: `./build-rust-cross.sh`
4. `git commit && git push`
5. `gh release delete vX.Y.Z-rN --repo bigmalloy/starlink-panel --yes`
6. `gh release create vX.Y.Z-rN ... output/luci-app-starlink-panel-*.apk output/starlink-dish output/starlink-panel-signing.pub`

Always include `output/starlink-panel-signing.pub` (copy of `keys/starlink-panel-signing.pub`) in the release assets.
Signing key lives at `/home/mike/claude/luci-fan/luci-app-fancontrol/keys/luci-fancontrol-signing.pub` (shared with luci-app-fancontrol) and is committed to this repo as `keys/starlink-panel-signing.pub`.

## Key design decisions

### starlink-dish replaces grpcurl
- grpcurl is ~15 MB; starlink-dish is 1.4 MB statically linked
- Uses `starlink-grpc-client` crate (tonic 0.9 / prost 0.11) — proto defs included
- Default address is `http://192.168.100.1:9200` — no argument needed for standard setups
- Usage: `starlink-dish dish` and `starlink-dish reboot`; override address with `-d <url>`
- rpcd backend calls `starlink-dish dish -d "http://${DISH_IP}:${DISH_PORT}"`
- install-grpcurl.sh removes `/usr/bin/grpcurl` if present on every install

### Gen3 dish quirks
- `disablement_code = 1` (UNKNOWN_REASON) is reported even when fully connected
- Fix: treat code 1 as OKAY when `rs_rf = true` (see `rust-src/src/main.rs`)
- State field is omitted on wire when CONNECTED (proto3 zero-value omission)
- State is inferred from `disablement_code + rf_ready`

### IPv6 LFT rows hidden when not set
- `max_preferred_lifetime` and `max_valid_lifetime` are optional odhcpd UCI caps
- Most setups don't configure them; showing red "not set" badges was misleading
- Rows are now omitted from the IPv6 card when the values are absent (r20)

### Postinst XHR abort fix
- rpcd restarts synchronously in postinst (~1 s, doesn't interrupt HTTP)
- LuCI cache cleared inline (`rm -rf /tmp/luci-modulecache /tmp/luci-indexcache`)
- starlink-dish download runs fully detached via `setsid ... &`
- uhttpd is NOT restarted in postinst (LuCI serves JS from filesystem; cache clear is enough)

### install-grpcurl.sh always re-downloads
- No skip-if-exists check — always fetches latest binary from `releases/latest/download/starlink-dish`
- This ensures new binary versions are picked up on APK upgrade

## Official feed submissions (in review)

| Feed | PR | Branch |
|------|----|--------|
| openwrt/packages | #28890 | `bigmalloy:add-starlink-dish` |
| openwrt/luci | #8441 | `bigmalloy:add-luci-app-starlink-panel` |

`PKG_SOURCE_URL` in `openwrt-feed/net/starlink-dish/Makefile` points to
`https://github.com/bigmalloy/starlink-panel/releases/download/v$(PKG_VERSION)/`
(was previously pointing to the wrong repo `starlink-openwrt`; fixed in latest commit).

Feed source tarball: `starlink-dish-0.1.0.tar.gz` (vendored Cargo deps, 31 MB)
SHA256: `7fce8982bb53e65ed6c1cf9de46d5edadd24911db731bf5bb5ee37dcef4e846c`

To re-generate vendor tarball after Cargo.toml changes:
```sh
cd rust-src
~/.cargo/bin/cargo vendor vendor/
mkdir starlink-dish-0.1.0
cp -r src/ Cargo.toml Cargo.lock vendor/ starlink-dish-0.1.0/
tar czf ../starlink-dish-0.1.0.tar.gz starlink-dish-0.1.0/
sha256sum ../starlink-dish-0.1.0.tar.gz  # update PKG_HASH in openwrt-feed/net/starlink-dish/Makefile
rm -rf starlink-dish-0.1.0
```

## Router details (test device)

| Field | Value |
|-------|-------|
| Device | GL-iNet Beryl AX (MT3000) |
| SSH | `root@192.168.1.1` (key auth) |
| OpenWrt | 25.12.0 |
| Starlink | Gen3 rev4_panda_prod2 (AU) |
| Dish IP | 192.168.100.1:9200 |
