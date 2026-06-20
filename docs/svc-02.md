# svc-02: Monitoring Host

svc-02 is the monitoring and network services host. It runs the observability stack
(Prometheus, Loki, Grafana), network boot services, and JRouter (AppleTalk routing).

## Hardware

HP ProDesk 600 G3 DM — see `docs/base_host.md`.

## Services

### Observability

| Service           | Port(s) | Purpose                                                          |
| ----------------- | ------- | ---------------------------------------------------------------- |
| Prometheus        | 9090    | Metrics aggregation from all hosts                               |
| Loki              | 3100    | Log aggregation from all hosts                                   |
| Promtail          | —       | Agent for log shipping (legacy, replaced by Alloy on most hosts) |
| Grafana           | 3000    | Dashboarding (local, grf-01 is the primary UI)                   |
| Blackbox exporter | 9115    | External endpoint monitoring                                     |
| Graphite exporter | 9109    | Graphite metrics compatibility                                   |
| HCloud exporter   | 9234    | Hetzner Cloud API metrics                                        |
| Unpoller          | —       | UniFi AP metrics                                                 |

### Network infrastructure

| Service          | Purpose                                        |
| ---------------- | ---------------------------------------------- |
| JRouter          | AppleTalk/DDP routing for afp-01               |
| TFTP             | PXE boot files (iPXE, undionly) for DHCP on gw |
| Unifi Controller | UniFi network management                       |
| AAISP exporter   | AAISP usage metrics (via aaisp-chaos flake)    |

### Prometheus federation

svc-02 is the central Prometheus server for the entire homelab. All hosts ship metrics
via Grafana Alloy's `remote_write` to `https://metrics.doofnet.uk/prometheus/api/v1/write`,
which is reverse-proxied to the local Prometheus instance.

### JRouter (AppleTalk routing)

JRouter is a custom Go service (built from `packages/jrouter.nix`) that enables
AppleTalk/DDP routing between VLANs, supporting the AppleTalk Phase 2 network on afp-01.

### TFTP (PXE boot)

The TFTP server serves PXE boot images (`ipxe.efi` for UEFI, `undionly.kpxe` for BIOS)
for network booting on VLANs 101 and 104. svc-02 acts as the `next-server` for VLAN 101's
DHCP PXE configuration.

## Networking

| Property   | Value                     |
| ---------- | ------------------------- |
| IPv4       | 10.101.3.21/16            |
| IPv6       | 2001:8b0:bd9:101::21/64   |
| ULA        | fddd:d00f:dab0:101::21/64 |
| DNS suffix | svc.doofnet.uk            |

## Cross-compilation

svc-02 has `doofnet.cross_compile = true`, enabling aarch64-linux emulation via binfmt.
This allows building aarch64 NixOS images (e.g. ns-01 SD card images) directly on this
host. It also holds the Nix signing key (`secrets/svc02NixSigningKey.age`) for signing
substitute cache entries.

## Aliases

- `nrs-ns01` — shortcut to rebuild ns-01 from this host (`nixos-rebuild switch --flake
github:nikdoof/nixos-homeprod#ns-01 --target-host ns-01`)

## Service summary

| Service        | Package             | Purpose                       |
| -------------- | ------------------- | ----------------------------- |
| prometheus     | prometheus          | Metrics aggregation           |
| loki           | loki                | Log aggregation               |
| grafana        | grafana             | Dashboards (backup UI)        |
| unifi          | unifi               | UniFi controller              |
| unpoller       | unpoller            | UniFi metrics → Prometheus    |
| alloy          | grafana-alloy       | Local agent scraping          |
| jrouter        | (custom Go service) | AppleTalk routing             |
| tftp-hpa       | tftp-hpa            | PXE boot file server          |
| aaisp-exporter | aaisp-chaos flake   | AAISP broadband usage metrics |
