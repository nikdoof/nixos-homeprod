# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

# Run pre-commit hooks manually, using prek
prek run --all-files
```

## Architecture

### Flake Structure

- **`flake.nix`** — Defines inputs, `nixosConfigurations` for all 14 hosts, custom packages, and `checks` (deadnix, statix, nixfmt)
- **`lib/mksystem.nix`** — Central system builder applied to all hosts; automatically includes agenix and the `doofnet` base module; accepts `extraModules`
- **`lib/mkmac.nix`** — Generates deterministic MACs from hostname SHA1 (for microvm networking)
- **`lib/firewall.nix`** — Shared firewall configuration helpers

### Host Configurations (`hosts/<hostname>/`)

Each host has:
- `configuration.nix` — Main config, imports hardware profile and services
- `hardware-configuration.nix` — Auto-generated NixOS hardware scan output
- `services/` (optional) — Per-service `.nix` files aggregated in `services/default.nix`

### Modules (`modules/doofnet/`)

The `doofnet` module is automatically applied to every host via `lib/mksystem.nix`:

- **`common.nix`** — Nix experimental features, CIS kernel hardening (blacklisted modules), firewall, timezone (`Europe/London`)
- **`server.nix`** — Server-wide defaults
- **`system.nix`** — System-level settings
- **`network.nix`** — VLAN definitions (101–106) via systemd-networkd
- **`bind/`** — BIND DNS configuration; zone files use `dns.nix` DSL
- **`users/`** — User account management (nikdoof)
- **`nfs/`** — NFS mount definitions
- **`fail2ban.nix`** — fail2ban configuration
- **`cross_compile.nix`** — Cross-compilation support (for aarch64 builds)
- **`microvm.nix`** — Common microvm guest configuration
- **`files/`** — Managed file definitions

Top-level modules (opt-in):
- **`jrouter.nix`** — Custom routing tool integration
- **`podman.nix`** — Container runtime
- **`postgresql.nix`** — PostgreSQL defaults
- **`traefik.nix`** — Reverse proxy

### Key Host Roles

| Host | Role | Arch |
|------|------|------|
| `gw` | Gateway/Router (PPPoE, DHCP4/6, radvd, Tailscale) | x86_64 |
| `hyp-01` | Hypervisor for microvms | x86_64 |
| `ns-01` | Primary DNS (Raspberry Pi 3) | aarch64 |
| `svc-01` | Services (Jellyfin, Gitea, Mastodon, Traefik, etc.) | x86_64 |
| `svc-02` | Monitoring (Grafana, Prometheus, Loki, Unifi) | x86_64 |
| `ns-03/04` | Cloud DNS (AWS) | x86_64 |
| Microvms (`ns-02`, `grf-01`, `hs-01`, `mx-01`, `web-01`, `afp-01`) | Secondary DNS, Grafana, Home Assistant, Mail, Web, Globaltalk | — |

### Networking

Networks defined in `modules/doofnet/const.nix`:
- Internal: `10.0.0.0/8` + `fddd:d00f:dab0::/48`
- Routable IPv4: `217.169.25.8/29`, `81.187.48.147/32`
- Routable IPv6: `2001:8b0:bd9::/48`
- Tailscale: `100.64.0.0/10` + `fd7a:115c:a1e0::/48`

VLANs: 101 (private), 102 (public), 104 (lab), 105 (HA/IoT), 106 (hosted)

Internal DNS domains: `int.doofnet.uk`, `svc.doofnet.uk`, `lab.doofnet.uk`, `pub.doofnet.uk`, `ha.doofnet.uk`

### Secrets

All secrets use `agenix` (age encryption). Secret files live in `secrets/` with corresponding `.nix` metadata files defining which host keys can decrypt each secret.

### Observability

Grafana Alloy agents run on all hosts, shipping metrics to Prometheus and logs to Loki on `svc-02`. Dashboards are in Grafana on `grf-01` (microvm on hyp-01).

### DNS Zone Files

Zone files in `modules/doofnet/bind/zones/` use the `dns.nix` DSL. Both forward zones and reverse zones (IPv4 and IPv6) are maintained here.

## Hardware Profiles (`hardware/`)

- `prodesk-400-g4-sff.nix` — HP ProDesk 400 G4 SFF (gw)
- `prodesk-600-g3-dm.nix` — HP ProDesk 600 G3 DM (svc-*)
- `raspberry-pi-3.nix` — RPi 3 (ns-01)
- `coral-tpu-pcie.nix` — Google Coral TPU (opt-in)
- `p8-laptop.nix` — Mini P8 laptop (talos)

## Infrastructure

Terraform in `terraform/` manages cloud DNS and AWS Cloud VMs (ns-03, ns-04).
