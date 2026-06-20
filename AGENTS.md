## Overview

NixOS flake-based homelab managing 14 hosts: 5 physical machines, 6 microvms, 2 AWS cloud instances, and 1 laptop. Uses `agenix` for secrets, `microvm.nix` for VMs, and `dns.nix` for BIND zone generation.

## Common Commands

```bash
# Check the flake (runs deadnix, statix, nixfmt checks)
nix flake check

# Build a host configuration
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel

# Deploy to a host (uses nixos-rebuild via SSH)
nixos-rebuild switch --flake .#<hostname> --target-host <hostname>

# Enter dev shell (provides agenix, deadnix, statix, nixfmt)
nix develop

# Format Nix files
nixfmt <file.nix>

# Lint Nix files
statix check .
deadnix .

# Edit a secret (requires correct SSH key)
agenix -e secrets/<secret>.age

# Run pre-commit hooks manually, using prek (installed via uv)
prek run --all-files

# Build a specific package
nix build .#packages.x86_64-linux.<package>
```

## Key Functions & APIs

### System Builders (`lib/`)

- **`lib/mksystem.nix`** — `mkSystem name { system?, extraModules? }` → NixOS configuration. Central builder applied to all hosts. Automatically includes `agenix` module + `modules/doofnet`. Extends nixpkgs `lib` with `lib.mkMAC`. Called from `flake.nix` for every host.
- **`lib/mkmac.nix`** — `lib.mkMAC hostName` → deterministic MAC (`02:00:00:xx:xx:xx`) derived from SHA1 of hostname. Used for microvm tap interfaces.
- **`lib/firewall.nix`** — `firewall.allowFromPrometheus port comment` → attrset with `extraCommands`/`extraStopCommands` that open Prometheus scrape access from monitoring subnets (`10.101.0.0/16`, `fddd:d00f:dab0:101::/64`, `2001:8b0:bd9:101::21/64`). Use with `lib.mkMerge` for multiple rules.

### Flake Functions (`flake.nix`)

- **`mkMicrovm name args`** (line 49–59) — Wraps `mkSystem`, automatically appends `microvm.nixosModules.microvm` + `modules/doofnet/microvm.nix` to `extraModules`.
- **`forAllSystems`** (line 39) — `lib.genAttrs lib.systems.flakeExposed` for iterating over platforms in `packages`, `checks`, `devShells`.
- **`mkSystem`** (line 41–47) — Curried: `mkSystem "hostname" { system?, extraModules? }` → NixOS config. Defined in `lib/mksystem.nix`.

### Host Classification (`modules/doofnet/system.nix`)

Import with `let inherit (import ./system.nix config) isPhysical;` — returns attrset of booleans:

| Helper        | Signal                                                       |
| ------------- | ------------------------------------------------------------ |
| `isMicroVM`   | `doofnet.microvm.enable`                                     |
| `isEC2`       | `services.amazon-ssm-agent.enable` (set by amazon-image.nix) |
| `isKVM`       | `services.qemuGuest.enable`                                  |
| `isContainer` | `boot.isContainer`                                           |
| `isVirtual`   | Any of the above                                             |
| `isPhysical`  | None of the above                                            |

### Network Constants (`modules/doofnet/const.nix`)

| Attr                | Contents                                                   |
| ------------------- | ---------------------------------------------------------- |
| `internalNetworks`  | `10.0.0.0/8`, `fddd:d00f:dab0::/48`                        |
| `routeableNetworks` | `2001:8b0:bd9::/48`, `217.169.25.8/29`, `81.187.48.147/32` |
| `tailscaleNetworks` | `100.64.0.0/10`, `fd7a:115c:a1e0::/48`                     |
| `allNetworks`       | All of the above combined                                  |

Import with `let inherit (import ../const.nix) allNetworks;`.

### BIND DNS Functions (`modules/doofnet/bind/default.nix`)

Key internal functions for zone processing:

| Function                  | Purpose                                                                                                                           |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `mkPrimaryZone zone`      | Builds BIND `master` zone config with file, slaves, extraConfig                                                                   |
| `mkSecondaryZone zone`    | Builds BIND `slave` zone config                                                                                                   |
| `mkDynamicConfig zone`    | Generates `allow-update` / `update-policy` for DDNS zones                                                                         |
| `hasDynamicUpdates zone`  | Checks `zone.value.dynamic.enable`                                                                                                |
| `isPublicZone zone`       | True if zone NS records include `ns-03.doofnet.uk.` or `ns-04.doofnet.uk.`                                                        |
| `getZoneSerial zone`      | Extracts serial from SOA                                                                                                          |
| `writeZoneFile zone`      | Renders zone data via `dns.lib.toString` to a store path                                                                          |
| `mkDynamicZoneFiles zone` | Creates tmpfiles entries for dynamic zone files + serial tracking                                                                 |
| `mkZoneUpdateScript zone` | Pre-bind activation script that merges Nix-managed records with DDNS additions, preserving dynamic entries across `nixos-rebuild` |

### DNS Zone DSL (`modules/doofnet/bind/zones/`)

Zone files use `dns.nix` DSL and are auto-discovered by `default.nix`.

**Zone library (`zones/lib.nix`):**

| Function            | Purpose                                                                                                                                |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `zlib.mkSOA serial` | Builds SOA record with defaults: `ns-01.int.doofnet.uk.`, `hostmaster@doofnet.uk`, refresh 3600, retry 900, expire 604800, minimum 300 |
| `zlib.internalNS`   | `["ns-01.int.doofnet.uk." "ns-02.int.doofnet.uk."]`                                                                                    |
| `zlib.publicNS`     | `["ns-03.doofnet.uk." "ns-04.doofnet.uk."]`                                                                                            |

**Zone DDNS pattern:** A zone declares `dynamic.enable = true` and `dynamic.protect = [...]` listing statically-managed names. Protected names are denied DDNS; all other names get `zonesub` grant. The pre-bind activation script preserves DDNS-created records across NixOS rebuilds.

**`modules/doofnet/bind/zones/default.nix`:** Auto-loader that reads all `.nix` files (excluding `default.nix` and `lib.nix`), imports each with `{ inherit dns zlib; }`, and returns an attrset keyed by zone name.

### MicroVM Guest Config (`modules/doofnet/microvm.nix`)

Options under `doofnet.microvm`:

| Option   | Type | Default              | Description                                                 |
| -------- | ---- | -------------------- | ----------------------------------------------------------- |
| `enable` | bool | —                    | Enable doofnet microvm guest configuration                  |
| `cid`    | int  | —                    | vsock context ID (unique per host)                          |
| `vlan`   | str  | —                    | VLAN number for tap interface name (`vm-{vlan}-{hostname}`) |
| `mac`    | str  | `lib.mkMAC hostName` | MAC address for tap interface                               |
| `vcpu`   | int  | 2                    | Virtual CPUs                                                |
| `mem`    | int  | 1024                 | Memory in MiB                                               |

**Configured defaults:** QEMU hypervisor, virtiofs for `/nix/store` (ro-store) and `/persist` (writable), SSH host keys + dhparams + ACME certs persisted to `/persist`.

### MicroVM Host Config (`hosts/hyp-01/microvms.nix`)

VMs declared with `microvm.vms = { <name> = { flake = inputs.self; restartIfChanged = false; }; }`. Contains an evaluation-time assertion that validates unique CIDs across all guest configurations by reading `inputs.self.nixosConfigurations.<name>.config.doofnet.microvm.cid`.

### NFS Mounts (`modules/doofnet/nfs/default.nix`)

Boolean options under `doofnet.nfs`: `media`, `photos`, `paperless`. Each mounts a specific path from `nas-03.int.doofnet.uk` to `/mnt/nas-03/<name>` with standard NFSv4 options.

### Network Module (`modules/doofnet/network.nix`)

- `doofnet.network.vlans` — boolean, enables systemd-networkd netdevs for VLAN IDs 101–106 (vlan-private, vlan-public, vlan-lab, vlan-ha, vlan-hosted).

### Modules (`modules/doofnet/`)

The `doofnet` module is automatically applied to every host via `lib/mksystem.nix`:

- **`common.nix`** — Nix experimental features, CIS kernel hardening (blacklisted modules), firewall, timezone (`Europe/London`)
- **`server.nix`** — Server-wide defaults: Grafana Alloy (metrics + logs), borgmatic backup, SMART monitoring (physical hosts), flake revision Prom metric
- **`system.nix`** — Host classification helpers (see above)
- **`network.nix`** — VLAN definitions (101–106) via systemd-networkd
- **`bind/`** — BIND DNS configuration; zone files use `dns.nix` DSL
- **`users/`** — User account management (nikdoof) — `users/nikdoof.nix`
- **`nfs/`** — NFS mount definitions
- **`fail2ban.nix`** — fail2ban configuration with Prometheus textfile collector
- **`cross_compile.nix`** — Cross-compilation support (for aarch64 builds)
- **`microvm.nix`** — Common microvm guest configuration
- **`files/`** — Managed file definitions (e.g. `files/motd`)
- **`opendmarc/`** — OpenDMARC milter module

Top-level modules (opt-in, import in host config):

- **`jrouter.nix`** — AURP to EtherTalk router (AppleTalk), needs `CAP_NET_RAW` + `CAP_NET_BIND_SERVICE`, DynamicUser
- **`podman.nix`** — Container runtime with Docker compat, automatic Traefik provider config, PostgreSQL auth from Podman subnet
- **`postgresql.nix`** — PostgreSQL with NVMe-tuned settings, `pg_stat_statements`, borgmatic backup, Prometheus exporter
- **`traefik.nix`** — Reverse proxy with Let's Encrypt (DigitalOcean DNS challenge), JSON logging, Prometheus metrics, log rotation, Alloy log shipping

### Packages

- **`packages/jrouter.nix`** — Custom Go build, fetched from internal Gitea. Available as `.#packages.x86_64-linux.jrouter`.
- **`packages/dropbox-notify/`** — Custom notification service

### Scripts

- **`scripts/`** — Utility scripts:
  - `airprint-generate.py` — Generate AirPrint config
  - `check-dns-delegation.sh` — Verify DNS delegation
  - `gitea-delete-user-mirrors.sh` — Clean Gitea mirror repos
  - `update-ns.sh` — Update nameserver records

### Secrets

All secrets use `agenix` (age encryption). Secret files live in `secrets/` with `secrets/secrets.nix` defining per-secret `publicKeys` (users ++ systems). Pattern: `"secretName.age".publicKeys = users ++ [ host1 host2 ];`.

Secrets are referenced in Nix configs via `age.secrets.<name> = { file = ../../secrets/<name>.age; };`.

### Observability

Grafana Alloy agents run on all hosts, shipping:

- **Metrics** to Prometheus on `svc-02` → `metrics.doofnet.uk/prometheus/api/v1/write` (basic-auth)
- **Logs** to Loki on `svc-02` → `metrics.doofnet.uk/loki/loki/api/v1/push` (basic-auth)

Alloy configs are generated as Nix store paths in `server.nix`, using the Alloy River syntax. Secrets are pulled from agenix (`age.secrets.metricsBasicAuthPassword`). Dashboards are in Grafana on `grf-01` (microvm on hyp-01).

Prometheus exporters enabled by default on servers: unix (system metrics), alloy, borgmatic, bind, smartctl (physical hosts), postgres, traefik. Custom textfile collectors: fail2ban jail stats, flake revision timestamp.

Firewall helper: `firewall.allowFromPrometheus port comment` in `lib/firewall.nix` opens raw iptables/ip6tables rules for the monitoring subnets.

### DNS Zone Files

Zone files in `modules/doofnet/bind/zones/` use the `dns.nix` DSL. Both forward zones and reverse zones (IPv4 and IPv6) are maintained here. Zones are auto-loaded by `zones/default.nix` which discovers all `.nix` files excluding `default.nix` and `lib.nix`.

## Host Configuration Patterns

### Standard Host Layout (`hosts/<hostname>/`)

Each host has:

- `configuration.nix` — Main config, imports hardware profile and services
- `hardware-configuration.nix` — Auto-generated NixOS hardware scan output
- `services/` — Per-service `.nix` files aggregated in `services/default.nix`

### Adding a New Host

1. Define in `flake.nix` using `mkSystem` (physical/cloud) or `mkMicrovm` (VM on hyp-01)
2. Create `hosts/<name>/configuration.nix` importing hardware profile + services
3. Create `hosts/<name>/services/default.nix` importing individual service modules
4. Add host SSH key to `secrets/secrets.nix` for relevant secrets
5. Add DNS records in zone files if needed

### Adding a New Service Module

- Per-service `.nix` file in `hosts/<hostname>/services/`
- Aggregated via `services/default.nix` with an `imports = [ ... ]` list
- Follow existing patterns: include Alloy scrape/relabel config inline, use agenix for secrets, add Prometheus exporter if applicable

### Adding a New Zone

1. Create `modules/doofnet/bind/zones/<zone-name>.nix` importing `{ dns, zlib }` — auto-loaded by `default.nix`
2. Use `dns.lib.combinators` (e.g. `host`, `CNAME`, `A`, `AAAA`, `MX`, `SRV`) for records
3. Set `SOA` via `zlib.mkSOA <serial>`
4. Optionally set `dynamic.enable = true` with `dynamic.protect = [...]` for DDNS

### Host Classification Pattern

```nix
{ config, lib, ... }:
let inherit (import ../../modules/doofnet/system.nix config) isPhysical isMicroVM;
in { ... }
```

Used to conditionally enable hardware-specific services, fstrim, SMART monitoring, etc.

### Network Configuration Pattern

- Gateway (`gw`) manages all VLAN interfaces and routing (nftables firewall, PPPoE, DHCP, RA)
- Hypervisor (`hyp-01`) creates a bridge (br0) with VLAN filtering for VMs
- Other hosts declare `doofnet.network.vlans = true` to get VLAN netdevs, then configure systemd-networkd
- VMs connect via tap interfaces named `vm-{vlan}-{hostname}` attached to the hyp-01 bridge with appropriate VLAN tagging

### Flake Checks

`nix flake check` runs:

- `deadnix` — detect dead Nix code
- `statix` — lint Nix code (config in `statix.toml`, disabled `repeated_keys` for zone files)
- `nixfmt` — check formatting (excludes hidden directories)

### Pre-commit Hooks

Defined in `.pre-commit-config.yaml`. Uses `prek` runner (installed via `uv`).

- `trailing-whitespace` / `end-of-file-fixer` (exclude `.age` files)
- `gitleaks` — detect secrets in git
- `nix flake check` — local hook

### CI

GitHub Actions workflows in `.github/workflows/`. Renovate auto-updates in `.github/renovate.json`.

### Documentation

MkDocs site in `docs/` using Material theme, published via GitHub Pages. Config in `mkdocs.yaml`.

## Key Host Roles

| Host                                                               | Role                                                                 | Arch    |
| ------------------------------------------------------------------ | -------------------------------------------------------------------- | ------- |
| `gw`                                                               | Gateway/Router (PPPoE, DHCP4/6, radvd, Tailscale, nftables firewall) | x86_64  |
| `hyp-01`                                                           | Hypervisor for microvms (KVM + microvm.nix)                          | x86_64  |
| `ns-01`                                                            | Primary DNS (Raspberry Pi 3), BIND master                            | aarch64 |
| `svc-01`                                                           | Services (Jellyfin, Gitea, Mastodon, Traefik, etc.)                  | x86_64  |
| `svc-02`                                                           | Monitoring (Grafana, Prometheus, Loki, Unifi)                        | x86_64  |
| `nas-01`                                                           | NAS (unused, replaced by nas-03)                                     | —       |
| `talos`                                                            | Mini P8 laptop                                                       | x86_64  |
| `ns-03/04`                                                         | Cloud DNS (AWS, BIND secondary)                                      | x86_64  |
| Microvms (`ns-02`, `grf-01`, `hs-01`, `mx-01`, `web-01`, `afp-01`) | See below                                                            | x86_64  |

### MicroVMs (on hyp-01)

| VM       | VLAN          | CID | Role                            |
| -------- | ------------- | --- | ------------------------------- |
| `ns-02`  | 101 (private) | 11  | Secondary DNS (BIND secondary)  |
| `grf-01` | 101 (private) | 12  | Grafana dashboards              |
| `hs-01`  | 105 (HA/IoT)  | 13  | Headscale VPN server            |
| `mx-01`  | 106 (hosted)  | 14  | Mail server                     |
| `web-01` | 106 (hosted)  | 15  | Web hosting                     |
| `afp-01` | 101 (private) | 16  | Apple File Sharing / GlobalTalk |

### Networking

Networks defined in `modules/doofnet/const.nix`:

- Internal: `10.0.0.0/8` + `fddd:d00f:dab0::/48`
- Routable IPv4: `217.169.25.8/29`, `81.187.48.147/32`
- Routable IPv6: `2001:8b0:bd9::/48`
- Tailscale: `100.64.0.0/10` + `fd7a:115c:a1e0::/48`

VLANs: 101 (private), 102 (public), 104 (lab), 105 (HA/IoT), 106 (hosted)

Internal DNS domains: `int.doofnet.uk`, `svc.doofnet.uk`, `lab.doofnet.uk`, `pub.doofnet.uk`, `ha.doofnet.uk`

## Hardware Profiles (`hardware/`)

- `prodesk-400-g4-sff.nix` — HP ProDesk 400 G4 SFF (gw)
- `prodesk-600-g3-dm.nix` — HP ProDesk 600 G3 DM (svc-01, svc-02, hyp-01)
- `raspberry-pi-3.nix` — RPi 3 (ns-01)
- `coral-tpu-pcie.nix` — Google Coral TPU (opt-in)
- `p8-laptop.nix` — Mini P8 laptop (talos)

## Infrastructure

Terraform in `terraform/` manages cloud DNS (DigitalOcean) and AWS Cloud VMs (ns-03, ns-04).
