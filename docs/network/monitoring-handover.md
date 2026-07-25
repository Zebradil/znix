# Link-speed monitoring — implementation handover

Goal: alert when a link that should be 1000 Mbit negotiates 100 Mbit (the
2026-07-07 failure mode, see [README](./README.md)). Scrape into the existing
VictoriaMetrics stack in k3s; alert via the receiver already wired there.

`expected_mbit` per link lives in
[`topology.netjson.json`](./topology.netjson.json) — keep that as the source of
truth and encode it in the alert rules (or generate rules from it).

## Coverage plan

| Segment | Vantage | Mechanism |
|---|---|---|
| All 8 switch ports (Mac/dock, Pi, WAX214, switch↔router, incl. dumb devices) | **SG108E switch** | web-scrape exporter (no SNMP) |
| Router ports + WAN | **RT-AX53U (OpenWrt)** | node-exporter-lua or snmpd |

Per-host self-report (ethtool/networksetup) was considered and **dropped**: it
can't see switch↔switch or dumb-device links, and the switch exporter already
covers the host ports.

## 1. Switch exporter (the important one)

SG108E has **no SNMP** — must scrape the web UI. Candidate exporters (all
target the same web-managed TL-SG10x*E/PE family):

- `mad-ady/tl-sg-prometheus-exporter` — YAML config, multi-arch Docker image
  `ghcr.io/mad-ady/tl-sg-prometheus-exporter:main`, listens on `:8000`, exposes
  port speed/status/packet counters. **Confirmed on SG108E/SG1218MPE.**
- Alternatives if that one won't read the SG108E: `jzucker2/tp-link-switch-exporter`,
  `psmode/essstat` (SG108PE-tested, Easy Smart UDP protocol),
  `thelastguardian/tplinkexporter`.

Deploy (sketch):

```yaml
# k3s Deployment, image ghcr.io/mad-ady/tl-sg-prometheus-exporter:main, port 8000
# mount tl-sg-prometheus-exporter.yaml:
switches:
  - host: 192.168.0.2
    username: admin
    password: <from-secret>     # k8s Secret / sops, NOT in git
    cache_login: true
```

Then a VMServiceScrape/scrape-config pointing VictoriaMetrics at the pod `:8000`.

TODO on deploy: confirm the exact metric name + label for link speed (README
doesn't document it — hit `/metrics` once and read it), so the alert can match
`speed == 100`. Wire the expected value per port from the NetJSON file.

## 2. Router exporter (OpenWrt)

On the RT-AX53U (OpenWrt):

```sh
opkg update
opkg install prometheus-node-exporter-lua prometheus-node-exporter-lua-netdev
# exposes per-interface stats on :9100 (netdev collector)
```

Scrape `192.168.0.1:9100` from VictoriaMetrics. (Alternative: `opkg install snmpd`
and poll SNMP — but node-exporter is the lighter path and gives OpenMetrics
directly.)

## 3. Alert rule (vmalert)

Fire when an observed link speed drops below its expected value. Shape:

```yaml
# pseudo — adapt to the exporter's actual metric/labels
- alert: LinkSpeedDegraded
  expr: tplink_port_link_speed_mbit{port="4"} < 1000    # per port, from NetJSON expected_mbit
  for: 2m
  annotations:
    summary: "Switch port {{ $labels.port }} negotiated {{ $value }}Mbit, expected 1000"
```

Generate one rule per link that has `expected_mbit` set in the NetJSON file, or
hand-write the handful. Route to the existing receiver.

## Verify end-to-end

1. Exporter pod up, `/metrics` shows a per-port speed metric.
2. VictoriaMetrics scraping it (target UP).
3. Reproduce: unplug+marginally-seat a cable so a port drops to 100 (or just
   temporarily edit the rule threshold) → alert fires → receiver gets it.
