# LAN DNS on d1, behind a dedicated service address

Status: accepted

`toddler` (Raspberry Pi 3B+) dropped off the network and did not come back after
a power cycle — the failure mode DEFER-9 in [`docs/hosts/toddler.md`](../hosts/toddler.md)
already describes: the 3B+ carries its Ethernet behind the same flaky `dwc2` USB
controller as everything else, and one earlier boot enumerated no USB at all.
Since it was the only host advertised by the router's `dhcp_option 6`, the whole
LAN lost DNS. `*.lan` and the `zebradil.dev` split-horizon went with it, not just
ad filtering.

DNS moves to **`d1`**, and the resolver gets a **service address of its own**,
`192.168.0.53`, carried on a dummy link.

## Why d1

`junior` is the obvious candidate — wired, static, always on — and is the wrong
one. It is the k3s control plane ([ADR 0003](0003-colmena-deploy.md)), so every
cluster reboot would drop DNS for the flat, and it already answers on :80 and
:443. A gateway-class service should be the most boring machine in the house.

The `d1`–`d3` Dell XPS machines are k3s *agents*, each with `dual-net` (wired
primary, WiFi hot standby) and — being laptops — **a battery, which is a UPS**.
That is a better availability story than any other host on the LAN. `d1` takes
the role; the counter-argument is real and accepted: the d-hosts are also the
machines most likely to be rebuilt.

Deliberately *not* chosen: the OpenWrt router itself. It is the most always-on
device here, but putting DNS there re-creates the config-drift-via-LuCI problem
that the planned NixOS gateway migration (tracked in the personal knowledge
base, not this repo — it contains network credentials context) exists to
escape. Also not chosen: waiting for that migration. It has no hardware bought
and a hard PPPoE cutover ahead of it, and this repo cannot run degraded until
then. The config is a fleet module, so relocating to the gateway later is an
import line.

## Why a service address on a dummy link

`dual-net` keeps the host reachable over WiFi when the wired link dies. An
address on the wired link would die *with* that link, taking DNS down on a host
that is otherwise perfectly up — which would defeat the entire reason `d1` beat
`junior`.

So `192.168.0.53/32` lives on a `dummy` netdev. A dummy link never flaps, and
Linux's default weak host model (`arp_ignore = 0`) answers ARP for the address
out of whichever link the request arrived on. Wired and WiFi both work, failover
is free, and no daemon or health check is involved.

Two further consequences fall out of it:

- **The router stops being load-bearing for placement.** Moving the resolver to
  another host is a change in this repo, never a LuCI visit. The router is the
  one device on the LAN that is not under version control.
- **AdGuard binds that address and nothing else.** `d1` holds a public IPv6 from
  the router's RA. Binding `0.0.0.0` and opening :53 would publish an **open
  resolver on a public address** — a DDoS-amplification vector. Binding the
  service address makes the firewall the second line of defence instead of the
  only one.

## Considered Options

- **AdGuard Home (chosen)** — already running, already declarative.
- **blocky** — better shaped for this repo in almost every respect: no admin UI
  and therefore no bcrypt hash inlined in a public repo, `DynamicUser` with
  `ProtectSystem = "strict"`, real DNSSEC validation rather than just setting DO,
  and Prometheus metrics that would land in the vmagent scrape already running.
  **Rejected on one gap:** `customDNS.mapping` covers all subdomains of a mapped
  name with no way to carve names back out, so the `@@` exemptions for
  `znix.zebradil.dev` (CNAME to R2, and the binary cache — breaking it breaks
  builds fleet-wide) and `*.ts.zebradil.dev` (a different tailnet address per
  host, so no single mapping value exists) cannot be expressed. Wildcard
  exceptions are 0xERR0R/blocky#74 and #1515, both open; the exact split-horizon
  case is #1631, **closed as not planned**. Revisit only if that changes.
- **Two resolvers now** — deferred, not rejected. When wanted: a second instance
  on another d-host with its own `serviceAddress`, both in `dhcp_option 6`.
  Clients pick per their own whim rather than in priority order, which is safe
  only because both instances run identical filtering out of this one module.
  **VRRP/keepalived was rejected** — a floating address buys one avoided
  `dhcp_option` edit at the price of a split-brain failure mode.
- **The router's dnsmasq as a secondary** — rejected outright. A secondary that
  does not filter is a bypass, not a fallback.

## Consequences

- The router must hand out `dhcp_option '6,192.168.0.53'`. This is a manual step
  and the last one outside version control.
- Query log and statistics retention goes back to 90 days: the 7-day window
  existed only to spare an SD card (DEFER-1), and 90 days is what answers "does
  our query volume fit NextDNS's 300k/month free tier" if off-LAN filtering for
  family devices is ever pursued.
- `toddler` keeps `blebridge`, which is physically bound to it (onboard hci0 plus
  the ANT+ stick, next to the treadmill). It is dropped from CI, since the box is
  going back to Raspbian.
- Short-form feed blocking (YouTube Shorts, Instagram Reels, TikTok's feed) is
  **out of scope for DNS at any layer** — those feeds share hostnames with the
  parent service, so no resolver can distinguish them. AdGuard's `blocked_services`
  can block a whole service; anything finer is an OS parental control or an
  app-level blocker.
