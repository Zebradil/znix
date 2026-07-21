# Home LAN network

Machine-readable topology: [`topology.netjson.json`](./topology.netjson.json)
([NetJSON NetworkGraph](https://netjson.org)). Edit that file to update the map;
`link.properties.expected_mbit` is the source of truth for the "link ran slow"
alert.

## Topology

```
trv4250 MacBook (192.168.1.52/16)
  └─ USB-C/TB ─ Dell dock (en11, d8:d0:90:48:db:f7)
       └─ copper ─ TL-SG108E switch (192.168.0.2)  ── copper ── RT-AX53U router (192.168.0.1, OpenWrt) ── WAN 300/150
                     ├─ port 4 ── toddler Pi (192.168.0.20)
                     └─ ─────── ── WAX214 AP (192.168.0.5)
```

Switch web-UI port numbers **do** map to physical ports (verified 2026-07-07).
Fill the remaining `switch_port: "TODO"` entries by unplugging one cable at a
time and watching which port drops in the UI.

## Known facts

- **WAN**: 300 Mbit down / 150 Mbit up (measured, matches plan).
- **LAN links**: all gigabit-capable; expected 1000 Mbit.
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

## Open oddity: slow inter-host throughput

`iperf3` MacBook↔Pi measured only ~279 Mbit despite both ends at gigabit.
Suspected cause: the MacBook sits on `192.168.1.52/16` while the rest of the LAN
is `192.168.0.x/24`, so Pi replies leave via the router (`.0.1`) and the test is
actually **routed through the consumer router's CPU** (few-hundred-Mbit
ceiling) instead of switched. Fix the MacBook subnet, then re-test with
`iperf3 -P 8`. Not yet resolved.

## Monitoring

See [`monitoring-handover.md`](./monitoring-handover.md) — deploy a switch
exporter (web-scrape, since no SNMP) + an OpenWrt exporter into the k3s stack,
scrape from VictoriaMetrics, alert when observed link speed < `expected_mbit`.

## Quick diagnostics

```bash
# macOS: own link speed (the number that matters, independent of switch UI)
networksetup -getMedia "USB 10/100/1000 LAN"      # Active: 1000baseT / 100baseTX

# Linux host: own link speed
ethtool eth0 | grep Speed

# LAN throughput (server on Mac, avoids Pi firewall; -R = Mac sends)
iperf3 -s                          # on Mac
iperf3 -c 192.168.1.52 -R -P 8     # on Pi

# Probe SNMP (expect timeout on the switch)
snmpwalk -v2c -c public 192.168.0.2 .1.3.6.1.2.1.1.1
```
