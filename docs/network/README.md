# Home LAN network

Machine-readable topology ([NetJSON NetworkGraph](https://netjson.org)) lives
in the personal knowledge base, not this repo (contains device/network
inventory). `link.properties.expected_mbit` there is the source of truth for
the "link ran slow" alert.

## Topology

```
RT-AX53U router (192.168.0.1/16, OpenWrt, MT7621) ── WAN 300/150
  │
  ├─ copper ─ switch 192.168.0.2 ── switch 192.168.0.3
  │              ├─ WAX214 AP (192.168.0.5) ─ 5 GHz Wi-Fi 6 ─ tuxedo (DHCP, 192.168.1.x)
  │              ├─ toddler Pi (192.168.0.20)
  │              └─ Dell dock ── USB-C/TB ── trv4250 MacBook (DHCP, 192.168.1.x)
  │
  └─ junior (192.168.0.100, k3s server / ingress / kasha)
     d1/d2/d3 (192.168.0.111-113, k3s agents, USB 3.0 NICs)
     Synology NAS (192.168.0.30, iSCSI target for the k3s PVCs)
```

The two TP-Link switches are `192.168.0.2` (`9c:a2:f4:91:08:67`) and
`192.168.0.3` (`3c:78:95:8e:6a:d5`). **Which one is the SG108E and which the
SG105PE is unverified** — this doc and the operator's notes disagree, and the
router cannot tell them apart (both are transparent bridges on `br-lan`). Log
into each web UI and settle it. The port-level placement of junior, d1-d3 and
the NAS is likewise unrecorded.

Switch web-UI port numbers **do** map to physical ports (verified 2026-07-07).
Fill the remaining `switch_port: "TODO"` entries by unplugging one cable at a
time and watching which port drops in the UI.

## Addressing: the LAN is a /16

The router's LAN is `192.168.0.1`, netmask `255.255.0.0` (**a /16**), with a DHCP pool at offset 256
(`dhcp.lan.start=256`, `limit=200`), so **DHCP clients get `192.168.1.0-199`**
while static hosts sit on `192.168.0.x`. Both halves are one subnet only if
every host carries a `/16`.

**Every static host must use `/16`.** A `/24` still reaches the DHCP half
(the client's own `/16` covers it), but the *reply* is off-subnet for the
`/24` host and hairpins in and out of `br-lan` on the router's MT7621 CPU.
Measured on that path, one direction switched and the other routed:

| direction | throughput | retransmits |
|---|---|---|
| DHCP client → `/24` host (switched) | 662 Mbit | 0 |
| `/24` host → DHCP client (routed), 1 stream | 472 Mbit | 83 |
| `/24` host → DHCP client (routed), 8 streams | 277 Mbit | 151 |

More streams made it *worse* — the CPU, not the wire, is the limit. Router
`br-lan` counters moved +486 MB in / +501 MB out for a 453 MB transfer,
confirming the payload crossed the router twice.

The Tailscale subnet router on junior deliberately advertises the narrower
`192.168.0.0/24` — that is about roaming clients on foreign `192.168.x.x`
LANs, not about the local prefix. See the comment in
`modules/hosts/junior/configuration.nix`.

## Known facts

- **WAN**: 300 Mbit down / 150 Mbit up (measured, matches plan).
- **LAN links**: all gigabit-capable; expected 1000 Mbit.
- **Wi-Fi**: tuxedo↔WAX214 negotiates `1200.9 MBit/s 80MHz HE-MCS 11 HE-NSS 2`
  at −34 dBm; ~700-790 Mbit of real TCP goodput. Not a bottleneck for anything
  the LAN serves.
- **d3's USB NIC is USB 3.0** (`5000 Mbps` on the bus, link `1000/full`). A
  host relaying traffic does *not* halve its link — Ethernet is full duplex, so
  receiving from the NAS and sending to junior use independent directions.
- **Switch SG108E has no SNMP.** Only the web UI and TP-Link's proprietary
  Easy Smart protocol (UDP 29808). SNMP polls to `.0.2` time out. Router `.0.1`
  (OpenWrt) has no SNMP installed yet either.

## Root cause of the 2026-07-07 "capped at 100 Mbit" incident

Two switch ports (the MacBook/dock uplink and the WAX214) had silently
negotiated **100BASE-TX** instead of gigabit. A gigabit link needs all 4 pairs;
100M needs only 2. Losing contact on a pair → silent fallback to 100 Mbit,
no error anywhere.

Cause was **marginal contact at the switch-side RJ45 connectors**, not a dead
cable or a hardware ceiling. **Reseating the switch-side plug restored gigabit
on both ports.** Reseat is a symptom fix — likely a snapped retention clip or a
poorly-crimped plug lets the connector back out. Check/replace those two cables
to make it permanent. This is exactly what the monitoring below is meant to
catch next time.

## Root cause of the "~279 Mbit inter-host" oddity (resolved 2026-09-06)

The netmask mismatch described in [Addressing](#addressing-the-lan-is-a-16):
the DHCP-assigned client (`/16`, from the router's pool) talked to a static
host pinned to `/24`, so the return half of every transfer was software-routed
by the router. Nothing was wrong with the cables, the switches or the NICs.

`d1`-`d3` moved to `/16` in `modules/hosts/dell-xps-9380/instances.nix`;
**this takes effect on the next deploy**, not before. junior was already `/16`.
Verify afterwards with the `ip route get` and two-direction `iperf3` recipes
below — the routed path is only visible in one direction.

## "nix build downloads are slow" is usually not the network

A slow-looking `nix build` on a gigabit LAN is most often the **NAR
decompressor**, not a link. See [`../cache.md`](../cache.md#compression) —
the client decompresses each NAR single-threaded, which caps one path at a few
hundred Mbit regardless of how fast the cache serves it. Measure the cache
first; only then suspect the wire.

## Monitoring

See [`monitoring-handover.md`](./monitoring-handover.md) — deploy a switch
exporter (web-scrape, since no SNMP) + an OpenWrt exporter into the k3s stack,
scrape from VictoriaMetrics, alert when observed link speed < `expected_mbit`.

## Quick diagnostics

```bash
# macOS: own link speed (the number that matters, independent of switch UI)
networksetup -getMedia "USB 10/100/1000 LAN"      # Active: 1000baseT / 100baseTX

# Linux host: own link speed, and the USB bus speed behind a USB NIC
cat /sys/class/net/eth0/speed
grep -H . /sys/bus/usb/devices/*/speed

# Wi-Fi PHY rate actually negotiated
iw dev wlan0 link | grep -E 'bitrate|signal'

# Is a peer switched or routed? A "via <gateway>" means routed.
ip route get 192.168.1.15

# LAN throughput. Test BOTH directions: the netmask bug is asymmetric.
iperf3 -s                          # on one host (d1-d3 run it as a service)
iperf3 -c 192.168.0.113 -P 8       # this host sends
iperf3 -c 192.168.0.113 -P 8 -R    # this host receives

# Confirm a transfer is hairpinning through the router: run the test between
# these two snapshots and compare br-lan's byte counters against the payload.
ssh router 'grep br-lan /proc/net/dev'

# Probe SNMP (expect timeout on the switch)
snmpwalk -v2c -c public 192.168.0.2 .1.3.6.1.2.1.1.1
```
