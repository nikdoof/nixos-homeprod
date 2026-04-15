# DNS Servers

The homelab runs four BIND9 DNS servers configured via a shared `doofnet.bind` NixOS module:
two internal servers (ns-01, ns-02) that serve all zones and act as recursive resolvers, and
two public AWS secondaries (ns-03, ns-04) that serve only externally-delegated zones.

| Host  | Role             | Platform                        | Address (IPv4)   | Address (IPv6)           |
|-------|------------------|---------------------------------|------------------|--------------------------|
| ns-01 | Primary          | Raspberry Pi 3, aarch64         | 10.101.1.2       | 2001:8b0:bd9:101::2      |
| ns-02 | Secondary        | microVM on hyp-01 (VLAN 101)    | 10.101.1.3       | 2001:8b0:bd9:101::3      |
| ns-03 | Public secondary | AWS EC2, eu-west-1 (x86_64)     | 52.19.64.4       | —                        |
| ns-04 | Public secondary | AWS EC2, eu-west-2 (x86_64)     | 16.60.149.205    | —                        |

ns-01 and ns-02 also carry a ULA address on the private VLAN:

- ns-01: `fddd:d00f:dab0:101::2`
- ns-02: `fddd:d00f:dab0:101::3`

## Architecture

All four servers run the same BIND configuration, toggled between **primary** and **secondary**
mode by a single option. The primary holds the authoritative copy of every zone; secondaries
receive zone transfers from the primary.

**ns-01** is deployed as a Raspberry Pi 3 SD card image. Because it is aarch64, the
`nix-community.cachix.org` binary cache is configured to pull pre-built binaries during
cross-compiled deployments from an x86_64 builder.

**ns-02** is a NixOS microVM (CID 13) running on hyp-01. It serves all zones and acts as a
hot standby internal resolver. See `docs/hyp-01.md` for details on the microVM platform.

**ns-03 and ns-04** are AWS EC2 instances (eu-west-1 and eu-west-2 respectively) running in
secondary mode with `publicOnly = true`. They only serve zones whose NS records include
`ns-03.doofnet.uk.` or `ns-04.doofnet.uk.`, providing public authoritative DNS with geographic
redundancy. They do not act as recursive resolvers. Because they cannot reach the internal
primary directly, zone transfers use the gateway's public NAT IP (`81.187.48.147 → 10.101.1.2`).

## Module: `doofnet.bind` (`modules/doofnet/bind/`)

Enabling the module on a host:

```nix
doofnet.bind = {
  enable = true;
  mode = "primary";   # or "secondary"
};
```

For public-facing secondaries that cannot reach the primary on its internal address:

```nix
doofnet.bind = {
  enable = true;
  mode = "secondary";
  publicOnly = true;   # serve only externally-delegated zones
  masters = [ "81.187.48.147" ];  # gateway's public NAT IP → 10.101.1.2
};
```

`publicOnly` filters the active zone list to only those zones whose NS records contain
`ns-03.doofnet.uk.` or `ns-04.doofnet.uk.`. `masters` overrides the default internal
primary addresses for hosts that reach ns-01 via NAT.

### Zone rendering

Zones are written as Nix expressions using the [`dns`](https://github.com/nix-community/dns)
flake library. Every `.nix` file in `modules/doofnet/bind/zones/` (except `default.nix`) is
automatically loaded as a zone, with the filename (minus `.nix`) used as the zone name.

Zones are divided into two categories:

- **Static zones** — no `allow-update` or `update-policy` stanza. The zone file is written
  to the Nix store at build time and BIND reads it directly. Zone content changes require a
  NixOS rebuild.
- **Dynamic zones** — contain `allow-update` or `update-policy`. The zone file is copied to
  `/var/lib/bind/zones/<name>.zone` so BIND can maintain a journal for live updates. A
  `bind-update-zones` systemd service detects serial number changes between Nix rebuilds and
  safely replaces the zone file (backing up the old one, removing the `.jnl` journal) so
  that static record changes propagate without breaking dynamic DDNS entries.

### Zone transfer

Primary sends transfers to:
- `10.101.1.3` / `2001:8b0:bd9:101::3` (ns-02) — all zones
- `52.19.64.4` (ns-03) and `16.60.149.205` (ns-04) — public zones only (those with ns-03/04 in NS records)

Zone transfers are denied by default (`allow-transfer { none; }`); each zone's
`slaves` list (derived by the module) provides the per-zone exception.

### DDNS updates

Dynamic DNS updates arrive from `kea-dhcp-ddns` on the gateway using TSIG key
`doofnet-dhcp-updates` (HMAC-SHA256). The key is stored in an age-encrypted secret and
included at runtime via BIND's `include` directive — it is never written to the Nix store.

An `acl "doofnet-dhcp-updates"` block matches requests that present a valid TSIG signature.
Dynamic zones use either:

- `allow-update { doofnet-dhcp-updates; }` — unrestricted updates for the zone (simpler
  zones where all records are DHCP-managed)
- `update-policy` — fine-grained rules used for `int.doofnet.uk`, which **denies** updates
  to statically-defined infrastructure records (gw, ns-01, ns-02, svc-01, etc.) while
  **granting** updates for all other names, protecting static records from being overwritten
  by DHCP clients.

### DNS-over-TLS

BIND listens on port 853 (TCP) with TLS on all interfaces. The certificate is obtained
via ACME DNS-01 challenge using the DigitalOcean API (the domain's public NS is managed
there). ACME renewal triggers a BIND service reload. The TLS configuration is defined in
BIND's `tls local-tls` block referencing the certificate at:

```
/var/lib/acme/<hostname>.int.doofnet.uk/{fullchain,key}.pem
```

### Recursion and caching

ns-01 and ns-02 act as recursive resolvers for internal clients (ns-03/04 do not). Recursion is permitted for:

- `127.0.0.0/8` and `::1` (loopback)
- All internal networks (defined in `modules/doofnet/const.nix` as `allNetworks`)

External clients receive `REFUSED`. Notable resolver settings:

| Setting                    | Value    | Effect                                                    |
|----------------------------|----------|-----------------------------------------------------------|
| `dnssec-validation`        | `auto`   | Validates DNSSEC; uses built-in trust anchors             |
| `qname-minimisation`       | `strict` | Sends only the minimum labels needed per delegation step  |
| `minimal-responses`        | `yes`    | Omits unnecessary additional section records              |
| `max-cache-size`           | 256 MiB  | Caps memory used by the answer cache                      |
| `max-cache-ttl`            | 86400 s  | Caps positive cache entries at 24 h                       |
| `max-ncache-ttl`           | 3600 s   | Caps negative cache entries at 1 h                       |
| `prefetch`                 | 2 9      | Prefetches cache entries with ≤2 s left if queried ≥9×   |
| `stale-answer-enable`      | yes      | Serves stale answers during upstream outages              |
| `stale-answer-ttl`         | 30 s     | Stale entries served for up to 30 s while refreshing      |

Forwarders are explicitly empty — servers resolve iteratively from the root.

### Rate limiting

Responses are rate-limited to 10 per second per client, with a 5-second window. All
internal networks are exempt, so rate limiting only applies to external clients (and is
primarily a defence against amplification attacks).

### Response Policy Zone (RPZ)

A local `rpz` zone provides DNS-level overrides enforced with `break-dnssec yes`. Current
overrides:

| Name                                       | Resolves to   | Purpose                                    |
|--------------------------------------------|---------------|--------------------------------------------|
| `svc-prod-ingress-external.doofnet.uk`     | 10.101.3.20   | Redirect internal clients to local ingress |
| `tester.mfg.cobaltmicro.com`               | 10.101.3.104  | Local override for third-party hostname    |

The RPZ zone is served by both primary and secondary. To block a domain, add it with
`CNAME = [ "." ]`; to pass it through the policy, use `CNAME = [ "rpz-passthru." ]`.

### Logging

BIND logs to two files under `/var/log/named/`:

| File            | Categories                                                        | Retention         |
|-----------------|-------------------------------------------------------------------|-------------------|
| `security.log`  | default, security, dnssec, query-errors, xfer-in/out, notify     | 3 files × 20 MiB  |
| `queries.log`   | queries                                                           | 5 files × 100 MiB |

Noisy low-signal categories (`lame-servers`, `edns-disabled`, `rpz`) are sent to a null
channel.

Both log files are tailed by Grafana Alloy and shipped to Loki. The Alloy pipeline parses
each format:

- **Query log**: extracts `client_ip`, `client_port`, `qname`, `qtype`, `qclass`, `flags`
  and stores them as structured metadata. `qtype` and `qclass` become Loki stream labels.
- **Security log**: extracts `category` and `severity` as stream labels.

Alloy's supplementary group membership (`named`) grants read access to the log directory
without widening file permissions.

### Monitoring

A `prometheus-bind-exporter` instance runs on `127.0.0.1:9119`, scraping BIND's statistics
channel at `127.0.0.1:8053`. The exporter is not exposed externally; Alloy scrapes it
locally and ships metrics to Prometheus.

## Deployment

Use `scripts/update-ns.sh` to deploy DNS servers in the correct order (primary first, then
public secondaries). The script SSHes to `svc-02` and runs `nixos-rebuild switch` there
against the published GitHub flake, so **changes must be pushed before running**.

```bash
# Deploy all servers (ns-01, ns-03, ns-04) in order
./scripts/update-ns.sh

# Deploy specific servers only
./scripts/update-ns.sh ns-01
./scripts/update-ns.sh ns-03 ns-04
```

Environment variables to override defaults:

| Variable     | Default                          | Purpose                              |
|--------------|----------------------------------|--------------------------------------|
| `BUILD_HOST` | `svc-02.int.doofnet.uk`          | Host that runs `nixos-rebuild`       |
| `FLAKE`      | `github:nikdoof/nixos-homeprod`  | Flake reference to deploy from       |

The script resolves each host to its FQDN for `--target-host` (ns-01/02 use
`.int.doofnet.uk`; ns-03/04 use `.doofnet.uk`) while using the short name as the flake
config key.

## Zones

### Forward zones

| Zone              | NS                        | Dynamic | DDNS | Notes                                            |
|-------------------|---------------------------|---------|------|--------------------------------------------------|
| `int.doofnet.uk`  | ns-01, ns-02              | yes     | policy | Protected static records + open DDNS for clients |
| `pub.doofnet.uk`  | ns-01, ns-02              | yes     | yes  | Public VLAN clients                              |
| `lab.doofnet.uk`  | ns-01, ns-02              | yes     | yes  | Lab VLAN clients                                 |
| `ha.doofnet.uk`   | ns-01, ns-02              | yes     | yes  | Home automation VLAN clients                     |
| `svc.doofnet.uk`  | ns-01, ns-02              | no      | —    | Service endpoints; wildcard `*.svc.doofnet.uk → 10.101.3.20` |
| `service.arpa`    | ns-01, ns-02              | no      | —    | Special-use (RFC 6761) local resolution          |
| `rpz`             | ns-01, ns-02              | no      | —    | Response Policy Zone                             |

`svc.doofnet.uk` has a 300-second TTL (shorter than the default 3600 s) and includes
specific overrides for `grafana`, `unifi`, `loki`, and `prometheus` pointing to `10.101.3.21`.

### Reverse zones (IPv4)

| Zone                             | Covers               | Also on ns-03/04 | DDNS |
|----------------------------------|----------------------|------------------|------|
| `101.10.in-addr.arpa`            | VLAN 101 (private)   | no               | yes  |
| `102.10.in-addr.arpa`            | VLAN 102 (public)    | no               | yes  |
| `104.10.in-addr.arpa`            | VLAN 104 (lab)       | no               | yes  |
| `105.10.in-addr.arpa`            | VLAN 105 (HA)        | no               | yes  |
| `8-15.25.169.217.in-addr.arpa`   | Hosted /29           | yes              | no   |
| `147.48.187.81.in-addr.arpa`     | PPPoE WAN address    | yes              | no   |

### Reverse zones (IPv6)

| Zone                                         | Covers                       | Also on ns-03/04 | DDNS |
|----------------------------------------------|------------------------------|------------------|------|
| `1.0.1.0.9.d.b…ip6.arpa`                    | VLAN 101 `2001:8b0:bd9:101:` | yes              | yes  |
| `2.0.1.0.9.d.b…ip6.arpa`                    | VLAN 102 `2001:8b0:bd9:102:` | yes              | yes  |
| `4.0.1.0.9.d.b…ip6.arpa`                    | VLAN 104 `2001:8b0:bd9:104:` | yes              | yes  |
| `6.0.1.0.9.d.b…ip6.arpa`                    | VLAN 106 `2001:8b0:bd9:106:` | yes              | yes  |
| `0.b.a.d.f.0.0.d.d.d.d.f.ip6.arpa`          | ULA `fddd:d00f:dab0::/48`    | no               | no   |

### Static records in `int.doofnet.uk`

Key infrastructure records that are protected from DDNS overwrites:

| Name        | IPv4          | IPv6 (ULA)                  |
|-------------|---------------|-----------------------------|
| gw          | 10.101.1.1    | 2001:8b0:bd9:101::1         |
| ns-01       | 10.101.1.2    | 2001:8b0:bd9:101::2         |
| ns-02       | 10.101.1.3    | 2001:8b0:bd9:101::3         |
| nas-01      | 10.101.3.16   | fddd:d00f:dab0:101::16      |
| svc-01      | 10.101.3.20   | fddd:d00f:dab0:101::20      |
| svc-02      | 10.101.3.21   | fddd:d00f:dab0:101::21      |
| hyp-01      | 10.101.3.22   | fddd:d00f:dab0:101::22      |
| gw-mgmt     | 10.101.3.23   | fddd:d00f:dab0:101::3:23    |
| afp-01      | 10.101.3.30   | fddd:d00f:dab0:101::3:30    |
| grf-01      | 10.101.3.31   | fddd:d00f:dab0:101::3:31    |

## Adding a new zone

1. Create `modules/doofnet/bind/zones/<zone-name>.nix` using the `dns` library. Include
   `extraConfig = ""` for static zones, or `allow-update { doofnet-dhcp-updates; };` /
   `update-policy { ... };` for dynamic zones.
2. Set the SOA `serial` to today's date in `YYYYMMDDnn` format.
3. If the zone should be served by Hurricane Electric, add their NS records — the module
   detects `*.he.net.` in the NS list and automatically includes them in the transfer list
   and NOTIFY targets.
4. Rebuild and deploy ns-01; ns-02 will pick up the new zone via AXFR automatically.

## Adding a static record to `int.doofnet.uk`

1. Add the subdomain to `int.doofnet.uk.nix` under `subdomains`.
2. Add a matching `deny` rule to the `update-policy` block to protect it from DDNS.
3. Increment the SOA serial.
4. Rebuild ns-01; the `bind-update-zones` service will detect the serial change, replace
   the zone file, and trigger BIND to reload.

## Service summary

| Service                    | Package                      | Purpose                                    |
|----------------------------|------------------------------|--------------------------------------------|
| named (BIND9)              | bind                         | Authoritative DNS + recursive resolver     |
| bind-update-zones          | (custom systemd oneshot)     | Merges Nix zone changes with live DDNS journals |
| prometheus-bind-exporter   | prometheus-bind-exporter     | BIND statistics → Prometheus               |
| alloy                      | grafana-alloy                | Metrics and log shipping                   |
