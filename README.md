# starlink-panel

LuCI dashboard for Starlink dish telemetry, alignment, alerts, IPv6 connectivity, traffic, and router configuration on OpenWrt 25.x.
Works with Starlink Gen3 and higher dish.

<img width="1180" height="1179" alt="image" src="https://github.com/user-attachments/assets/562686b3-83c6-411f-85a1-1a1c90b18eae" />


---

## Features

- **Dish Telemetry** — state, uptime, latency, packet drop, obstruction %, throughput, SNR, GPS satellites, Ethernet speed, hardware/software version
- **Alignment** — tilt and rotation guidance (↑↓ / ↻↶) with "well aligned" confirmation when within 0.1°
- **Alerts** — 11 health indicators matching the Starlink app (heating, thermal throttle, shutdown, PSU throttle, motors, mast, slow Ethernet, software update, roaming, obstruction, disabled)
- **IPv6 Connectivity** — WAN address, LAN address, delegated /56 prefix, default route
- **Traffic** — WAN and LAN byte/packet counters
- **Quality** — latency to 8.8.8.8 / 1.0.0.1, conntrack usage, router uptime
- **Configuration** — TCP congestion control, qdisc, flow offloading, MTU fix, DHCPv6-PD lifetime settings
- **Reboot Dish** button with confirmation dialog

Auto-refreshes every 10 seconds.

> **Note:** The alignment data is sourced directly from the dish API and is more accurate than the Starlink phone app, which can incorrectly report misalignment of over 6° on a well-aligned dish. Trust the dashboard.

---

## Related

This package is designed to work alongside [starlink-openwrt-ipv6-optimized](https://github.com/bigmalloy/starlink-openwrt-ipv6-optimized) — a companion guide for setting up OpenWrt as a Starlink bypass router, covering IPv6, odhcpd prefix lifetime fixes, firewall, congestion control, and more.

---

## Requirements

| Requirement | Notes |
|-------------|-------|
| OpenWrt 25.x | Uses `apk` package manager; tested on 25.12.0 |
| Architecture | `aarch64_cortex-a53` (GL-iNet Beryl AX / MT3000) — `PKGARCH=all` so installs on any architecture |
| `luci-base` | LuCI web interface |
| `rpcd` | RPC daemon (usually pre-installed) |
| `jsonfilter` | JSON parser for shell scripts |
| `grpcurl` | Required for dish telemetry — **installed automatically during `apk add`** |

---

## Installation

### Prerequisites (run once per router)

Install the signing key so packages verify without `--allow-untrusted`:

```sh
scp -O luci-fancontrol-signing.pub root@192.168.1.1:/etc/apk/keys/
```

Download the public key from the [latest release](../../releases/latest).

### Install via SSH

```sh
scp -O luci-app-starlink-*.apk root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'apk add /tmp/luci-app-starlink-*.apk'
```

### Install without key verification

```sh
ssh root@192.168.1.1 'apk add --allow-untrusted /tmp/luci-app-starlink-*.apk'
```

The post-install script automatically downloads and installs `grpcurl`, then restarts `rpcd` and `uhttpd`. Navigate to **Network → Starlink** in LuCI.

> If grpcurl download fails (no internet at install time), run `/usr/bin/install-grpcurl` manually once connected.

### Drop caches if reinstalling after removal

```sh
echo 3 > /proc/sys/vm/drop_caches
apk add --allow-untrusted /tmp/luci-app-starlink-*.apk
```

Required if the `starlink/` directory was previously deleted (overlayfs negative dcache).

---

## Build from Source

Requires Docker.

```sh
git clone https://github.com/bigmalloy/starlink-panel
cd starlink-panel
./build-apk-docker.sh
# Output: output/luci-app-starlink-*.apk
```

Uses the official `openwrt/sdk:aarch64_cortex-a53-25.12.0-rc5` Docker image.

---

## Hardware Tested

| Device | GL-iNet Beryl AX (MT3000) |
|--------|---------------------------|
| SoC | MediaTek MT7981B |
| OpenWrt | 25.12.0 |
| Starlink | Gen3 dish (rev4_panda_prod2) |
| ISP | Starlink Residential (AU) |

---

## Buy me a beer

If this project saved you some time, feel free to shout me a beer!

[![PayPal](https://img.shields.io/badge/PayPal-Buy%20me%20a%20beer-blue?logo=paypal)](https://paypal.me/bergfirmware)

---

## License

MIT
