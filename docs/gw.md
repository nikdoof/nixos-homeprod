# gw: Gateway / Router

`gw` is the network gateway for the homelab, running NixOS on an HP Prodesk 400 G4 SFF. It
provides routing, firewalling, DHCP, DNS, NTP, and VPN services for all VLANs.

## Hardware

HP Prodesk 400 G4 SFF (Intel Kaby Lake). Three network interfaces are relevant:

| Interface  | Role                                   |
|------------|----------------------------------------|
| `enp2s0`   | Management (out-of-band access to gw)  |
| `enp3s0f0` | Internal trunk (carries all VLANs)     |
| `enp3s0f1` | WAN (uplink to CityFibre ONT)          |

## Network

### VLANs

All internal traffic is carried as 802.1Q tagged frames on `enp3s0f0`. Five VLANs are
defined:

| VLAN | Interface       | IPv4 prefix      | IPv6 prefix                     | DNS zone        | Purpose                              |
|------|-----------------|------------------|---------------------------------|-----------------|--------------------------------------|
| 101  | `vlan-private`  | 10.101.0.0/16    | 2001:8b0:bd9:101::/64           | `int.doofnet.uk`| Internal infrastructure              |
| 102  | `vlan-public`   | 10.102.0.0/16    | 2001:8b0:bd9:102::/64           | `pub.doofnet.uk`| Public-facing services (NATed)       |
| 104  | `vlan-lab`      | 10.104.0.0/16    | 2001:8b0:bd9:104::/64           | `lab.doofnet.uk`| Lab / experimental                   |
| 105  | `vlan-ha`       | 10.105.0.0/16    | —                               | `ha.doofnet.uk` | Home automation / IoT                |
| 106  | `vlan-hosted`   | 217.169.25.8/29  | 2001:8b0:bd9:106::/64           | —               | Internet-facing, publicly routed     |

The hosted VLAN (106) is **not NATed** — traffic to/from 217.169.25.8/29 is routed directly
by the ISP. All other VLANs use IPv4 masquerade NAT via the PPPoE interface.

Private (101) and Lab (104) also receive a ULA prefix for stable internal IPv6 addressing
independent of the ISP:

| VLAN | ULA prefix                 |
|------|----------------------------|
| 101  | `fddd:d00f:dab0:101::/64`  |
| 104  | `fddd:d00f:dab0:104::/64`  |

### Management interface

`enp2s0` carries a static address (`10.101.3.23/16`) as a fallback management path if the
VLAN trunk goes down. Routes for the private subnet are installed with a high metric (2048)
so the trunk VLAN is preferred under normal operation.

### WAN — PPPoE

The WAN connection is PPPoE over CityFibre fibre. `enp3s0f1` carries a single VLAN 911
(`vlan-wan`), and `pppd` runs the `aaisp` peer on top of it, producing a `ppp0` interface.

IPv6 on WAN is obtained via DHCPv6 prefix delegation and RA from the ISP; the router accepts
the delegated prefix and distributes /64s to internal VLANs via Kea DHCPv6. DNS from the ISP
is not used (`UseDNS = no`).

PPPoE credentials are stored in an age-encrypted secret deployed to `/etc/ppp/pap-secrets`.

## Services

### DHCP — Kea DHCPv4 (`services/dhcp4.nix`)

Kea serves DHCPv4 on VLANs 101, 102, 104, and 105. Lease lifetime is 24 hours. All subnets
send DNS update requests to the local `kea-dhcp-ddns` server (port 53001).

| VLAN | Pool                         | Router       | DNS servers                  | DNS suffix       |
|------|------------------------------|--------------|------------------------------|------------------|
| 101  | 10.101.2.1 – 10.101.2.254    | 10.101.1.1   | 10.101.1.2, 10.101.1.3       | int.doofnet.uk   |
| 102  | 10.102.2.1 – 10.102.2.254    | 10.102.1.1   | 10.101.1.2, 10.101.1.3       | pub.doofnet.uk   |
| 104  | 10.104.2.1 – 10.104.2.254    | 10.104.1.1   | 10.101.1.2, 10.101.1.3       | lab.doofnet.uk   |
| 105  | 10.105.2.1 – 10.105.2.254    | 10.105.1.1   | 10.101.1.2, 10.101.1.3       | ha.doofnet.uk    |

Static reservations on VLAN 101:

| Hostname | IP            | MAC               |
|----------|---------------|-------------------|
| svc-01   | 10.101.3.20   | 10:62:e5:14:61:84 |
| svc-02   | 10.101.3.21   | f4:39:09:3a:4d:a4 |
| hyp-01   | 10.101.3.22   | 10:e7:c6:03:97:18 |

**PXE boot** is supported on VLANs 101 and 104. Client architecture option 93 selects the
boot file:

- `0x0000` (BIOS) → `undionly.kpxe`
- `0x0007` / `0x0009` (UEFI) → `ipxe.efi`

The `next-server` for VLAN 101 is `10.101.3.21` (svc-02/JRouter); for VLAN 104 it is
`10.101.3.102`.

### DHCP — Kea DHCPv6 (`services/dhcp6.nix`)

Kea serves DHCPv6 on VLANs 101, 102, and 104 (VLAN 105 and 106 are IPv4-only or SLAAC
respectively). Leases are coordinated with DDNS.

| VLAN | Pool                                                    | DNS servers                              |
|------|---------------------------------------------------------|------------------------------------------|
| 101  | 2001:8b0:bd9:101::2000 – ::2fff                         | 2001:8b0:bd9:101::2 / ::3               |
| 102  | 2001:8b0:bd9:102::2000 – ::2fff                         | 2001:8b0:bd9:101::2 / ::3               |
| 104  | 2001:8b0:bd9:104::2000 – ::2fff                         | 2001:8b0:bd9:101::2 / ::3               |

VLAN 101 also offers **prefix delegation** from `2001:8b0:bd9:200::/56`, handing out /64s
for clients that need their own subnet.

### Dynamic DNS — Kea DHCP-DDNS (`services/ddns.nix`)

`kea-dhcp-ddns` listens on `127.0.0.1:53001` and receives name-change requests from both Kea
servers. It authenticates to the primary DNS server (`10.101.1.2`) using TSIG
(`HMAC-SHA256`, key name `doofnet-dhcp-updates`).

Forward zones updated: `int.doofnet.uk`, `pub.doofnet.uk`, `lab.doofnet.uk`, `ha.doofnet.uk`

Reverse zones updated: `101.10.in-addr.arpa`, `102.10.in-addr.arpa`, `104.10.in-addr.arpa`,
`105.10.in-addr.arpa`, and the corresponding IPv6 reverse zones for VLANs 101, 102, 104,
and 106.

The TSIG secret is age-encrypted and injected at service start by an `ExecStartPre` script
that rewrites the config into `/run/kea/dhcp-ddns.conf`, keeping the secret out of the Nix
store.

### DNS — Unbound (`services/dns.nix`)

Unbound runs as a **resolver for the hosted VLAN only** (`vlan-hosted`), listening on
`217.169.25.9` and `2001:8b0:bd9:106::1`. Access is refused for all addresses except the
hosted /29 and /64. All queries are forwarded to the internal recursive resolvers
(`10.101.1.2`, `10.101.1.3`).

Hosts on other VLANs use the internal resolvers directly (ns-01, ns-02) and do not go via
this Unbound instance.

### IPv6 Router Advertisements — radvd (`services/radvd.nix`)

`radvd` sends Router Advertisements on VLANs 101, 102, 104, and 106. `AdvManagedFlag on`
directs clients to use DHCPv6 (stateful) on VLANs 101, 102, and 104. VLAN 106 uses SLAAC
only (`AdvManagedFlag off`, `AdvAutonomous on`).

The ULA prefixes for VLANs 101 and 104 are advertised with `AdvAutonomous on` so clients
self-configure stable ULA addresses without needing DHCPv6 for them.

RDNSS records point clients to the internal resolvers on all VLANs.

### NTP — Chrony (`services/ntp.nix`)

Chrony synchronises to UK-based stratum-1/2 servers and serves time to:

- `10.0.0.0/8`
- `2001:8b0:bd9::/48`
- `fc00::/7` (ULA)

### mDNS reflection — Avahi (`services/avahi.nix`)

Avahi reflects mDNS/Bonjour announcements between `vlan-private`, `vlan-lab`, and `vlan-ha`,
allowing service discovery (e.g. AirPlay, HomeKit) to work across those three VLANs.

### UPnP / NAT-PMP — miniupnpd (`services/upnp.nix`)

`miniupnpd` (nftables build) manages dynamic port mappings on behalf of clients on
`vlan-private` and `vlan-public`. The external interface is `ppp0`.

Port ranges are restricted: only ports 1024–65535 may be mapped, and only for hosts in
`10.101.0.0/16` or `10.102.0.0/16`. All other mapping requests are denied.

miniupnpd manages its own `miniupnpd` nftables table at runtime and does not modify the
main `inet filter` or `ip nat` tables.

### Tailscale VPN (`services/tailscale.nix`)

Tailscale connects to the self-hosted Headscale server at `https://hs.doofnet.uk`. The node
advertises:

- All internal routes: `10.0.0.0/8`, `2001:8b0:bd9::/48`, `fddd:d00f:dab0::/48`
- Exit node capability

`useRoutingFeatures = "server"` enables kernel IP forwarding for Tailscale traffic.
Telemetry is disabled (`--no-logs-no-support`). The firewall is not opened automatically
(`openFirewall = false`); inbound Tailscale traffic is handled by the nftables ruleset.

## Firewall (`services/firewall.nix`)

NixOS's legacy `iptables` firewall is disabled; nftables is used exclusively. The ruleset
lives in a single `table inet filter` plus a `table ip nat`.

### Named sets

| Set              | Contents                                                  |
|------------------|-----------------------------------------------------------|
| `local4`         | `10.0.0.0/8`, `217.169.25.8/29`                          |
| `local6`         | `2001:8b0:bd9::/48`, `fc00::/7`                          |
| `pub_ns4`        | Public secondary nameservers — ns-03 (`52.19.64.4`) and ns-04 (`16.60.149.205`) |
| `ns4/6`          | Internal resolvers (`10.101.1.2/3`, their IPv6 counterparts) |
| `hosted_out_tcp` | TCP ports hosted VLAN may use outbound: 22, 23, 25, 53, 70, 79, 80, 123, 443, 1965 |
| `hosted_out_udp` | UDP ports hosted VLAN may use outbound: 53, 123           |

### Input chain (policy: drop)

- Loopback always accepted
- Anti-spoofing: RFC1918 and ULA source addresses dropped on `ppp0`
- Established/related accepted; invalid dropped
- TCP flag validation (drops malformed/scan packets)
- ICMPv4: echo-request, unreachable, time-exceeded at 10/s
- ICMPv6: NDP, MLD, transit types at 10/s
- DHCPv4 (port 67) from all internal VLANs
- DHCPv6 (port 547) from private, public, lab, hosted VLANs
- DHCPv6 client replies from ISP on ppp0 (link-local source, port 547→546)
- DNS (port 53) from public secondary nameservers (`pub_ns4`: ns-03/04) for zone transfers / NOTIFY
- DNS (port 53) from hosted VLAN (forwarded to Unbound)
- NTP (port 123) from `local4`/`local6`
- SSH (port 22) from private VLAN, management interface, and Tailscale only
- mDNS (port 5353) from private, lab, HA VLANs
- UPnP SSDP (port 1900) and NAT-PMP/PCP (port 5351) from private and public VLANs
- Everything else from `ppp0` counted and dropped

### Forward chain (policy: drop)

- Established/related accepted; invalid dropped
- TCP flag validation
- ICMPv6 transit types forwarded at 10/s (NDP and MLD are link-local and not forwarded)
- DNATed connections accepted (`ct status dnat accept`)
- DNS forwarded from public, hosted, HA VLANs to internal resolvers
- mDNS forwarded between private, lab, HA VLANs
- **Private VLAN**: unrestricted outbound (full access including to hosted)
- **Lab VLAN**: blocked from reaching private and HA VLANs; otherwise unrestricted
- **Tailscale** (`tailscale0`): unrestricted outbound
- **Public VLAN**: outbound to WAN; HTTP/HTTPS to hosted; specific access to `10.101.3.20:443`
- **Hosted VLAN**: restricted outbound to WAN (only `hosted_out_tcp/udp`); access to svc-01 (`10.101.3.20:443`) and svc-02 (`10.101.3.21:443,9090`); Tailscale port 41641
- **WAN → hosted**: fully accepted (publicly routed, no NAT)
- **WAN → private**: QBittorrent (TCP/UDP 51413) inbound for IPv6
- WAN inbound drops counted silently; all other drops logged with `nft-forward-drop:` prefix

### Named counters (exported to Prometheus)

| Counter               | Meaning                                      |
|-----------------------|----------------------------------------------|
| `fw_wan_input_drop`   | Packets dropped in input chain from ppp0     |
| `fw_wan_forward_drop` | Inbound WAN packets dropped in forward chain |
| `fw_hosted_blocked`   | Hosted VLAN outbound blocked packets         |
| `fw_forward_drop`     | All other forward drops (internal traffic)   |

### NAT (`table ip nat`)

**Prerouting DNATs** (applied to `ppp0` ingress, skipped for the hosted /29):

| Destination port | Protocol | DNAT target          | Service                          |
|------------------|----------|----------------------|----------------------------------|
| 443              | TCP+UDP  | 10.101.3.20:8443     | HTTPS → svc-01                   |
| 53 (ns-03/04 src)| TCP+UDP  | 10.101.1.2:53        | DNS → ns-01 (zone transfers)     |
| 51413            | TCP+UDP  | 10.101.3.16          | BitTorrent → QBittorrent         |
| 387 (UDP)        | UDP      | 10.101.3.21          | AARP/AppleTalk → JRouter         |

**Postrouting**: all `10.0.0.0/8` traffic leaving `ppp0` is masqueraded (the hosted /29 is
excluded by the prerouting `return`).

## Kernel hardening

The following sysctl settings are applied, mostly following CIS benchmarks:

| Setting                          | Value | Rationale                                          |
|----------------------------------|-------|----------------------------------------------------|
| `net.ipv4/6.conf.all.forwarding` | 1     | Required for router operation                      |
| `rp_filter` (all/default)        | 1     | Strict reverse-path filtering (anti-spoofing)      |
| `rp_filter` (ppp0)               | 2     | Loose mode for PPPoE asymmetric routing            |
| `accept_source_route`            | 0     | Disable IP source routing (CIS 3.2.1)              |
| `accept_redirects`               | 0     | Reject ICMP redirects (CIS 3.2.2)                 |
| `send_redirects`                 | 0     | Do not send ICMP redirects (CIS 3.1.2)             |
| `log_martians`                   | 1     | Log spoofed/impossible source addresses (CIS 3.2.4)|
| `icmp_echo_ignore_broadcasts`    | 1     | Smurf amplification protection (CIS 3.2.5)         |
| `tcp_syncookies`                 | 1     | SYN flood protection (CIS 3.2.8)                  |
| `tcp_rfc1337`                    | 1     | TIME_WAIT assassination protection (RFC 1337)      |
| `kernel.dmesg_restrict`          | 1     | Restrict dmesg access                              |
| `kernel.kptr_restrict`           | 2     | Hide kernel pointers                               |
| `kernel.randomize_va_space`      | 2     | Full ASLR (CIS 1.5.3)                             |
| `kernel.yama.ptrace_scope`       | 1     | Restrict ptrace to parent processes                |
| `fs.protected_hardlinks/symlinks`| 1     | Prevent privilege escalation via links             |
| `fs.suid_dumpable`               | 0     | No core dumps for SUID programs (CIS 1.5.1)        |
| `kernel.unprivileged_bpf_disabled`| 1    | Disable unprivileged BPF                           |
| `net.core.bpf_jit_harden`       | 2     | Harden BPF JIT against info leaks                 |

## Observability

As a `doofnet.server` host, gw ships metrics to Prometheus via Grafana Alloy and logs to
Loki. Additional exporters configured in `services/alloy.nix`:

- **kea-exporter** (port 9547) — Kea DHCP lease and server statistics
- **chrony-exporter** (port 9123) — NTP sync status and offset

Firewall counters (`fw_wan_input_drop`, etc.) are collected via the nftables textfile
collector and exposed through the node exporter.

## Service summary

| Service       | Package       | Purpose                                    |
|---------------|---------------|--------------------------------------------|
| pppd          | ppp           | PPPoE WAN connection to AAISP              |
| kea-dhcp4     | kea           | DHCPv4 for VLANs 101, 102, 104, 105        |
| kea-dhcp6     | kea           | DHCPv6 for VLANs 101, 102, 104             |
| kea-dhcp-ddns | kea           | Dynamic DNS updates via TSIG               |
| unbound       | unbound       | DNS resolver for hosted VLAN only          |
| radvd         | radvd         | IPv6 router advertisements                 |
| chrony        | chrony        | NTP server                                 |
| avahi         | avahi         | mDNS reflection across private/lab/HA      |
| miniupnpd     | miniupnpd     | UPnP / NAT-PMP port mapping                |
| tailscale     | tailscale     | Mesh VPN via self-hosted Headscale         |
| lldpd         | lldpd         | LLDP (trunk interface only)                |
| alloy         | grafana-alloy | Metrics and log shipping                   |
