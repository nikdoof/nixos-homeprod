# Base Host Standards

Common standards that apply to all physical NixOS hosts in the homelab.

## Hardware

Hardware is being repurposed from old Kubernetes worker nodes.

| Device               | RAM   | OS disk     | OS          |
|----------------------|-------|-------------|-------------|
| HP Prodesk 600 G3 DM | 16 GB | 128 GB SATA | NixOS 25.11 |

## Storage

### Local storage

All local storage is provided under `/srv`:

- `/srv/data` — local SSD/NVMe, mapped to the data disk
    - `/srv/data/<application>` — per-application directory
    - `/srv/data/<application>/<mount>` — per-mount-point subdirectory (e.g. `/srv/data/sonarr/config`)
- `/srv/cluster` — clustered storage (CephFS, GlusterFS, etc.), not mounted directly

### Remote storage

Mounts for remote storage are placed under `/mnt`:

- `/mnt/<hostname>/<share>` — network or cluster-native mounts (e.g. `/mnt/nas-03/media`)

## Backups

Backups are managed by `borgmatic` and stored on a remote Hetzner Storage Box. Only
directories under `/srv/data` are backed up.

## Monitoring

All hosts run Grafana Alloy as a `doofnet.server` node, which:

- Collects host metrics via `prometheus.exporter.unix` and forwards them to Prometheus
- Ships systemd journal logs to Loki
- Writes a `nixos_flake_revision` textfile metric on every activation so the deployed
  flake revision is visible in Grafana
