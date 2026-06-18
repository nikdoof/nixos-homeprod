# grf-01: Grafana Dashboard

grf-01 is a NixOS microVM (CID 15) on hyp-01, running on VLAN 101. It hosts a dedicated
Grafana instance primarily used for visualising GlobalTalk scraper data, with Prometheus
as its datasource.

## Network

| Property     | Value                          |
|--------------|--------------------------------|
| Platform     | microVM, CID 15, VLAN 101      |
| IPv4         | 10.101.3.31/16                 |
| IPv6         | 2001:8b0:bd9:101::3:31/64     |
| ULA          | fddd:d00f:dab0:101::3:31/64   |
| DNS suffix   | globaltalk.doofnet.uk          |

## Grafana

| Setting           | Value                                |
|-------------------|--------------------------------------|
| Domain            | `globaltalk.doofnet.uk`              |
| Port              | 3000                                 |
| Auth              | Anonymous view-only (login disabled) |
| SMTP              | Outbound via mx-01                   |
| Alerting          | Disabled                             |

### Datasource

- **Prometheus** at `http://svc-02.int.doofnet.uk:9090` (the central prometheus)

### Dashboards

Dashboards are provisioned from `hosts/grf-01/files/dashboards/`. The default home
dashboard is `globaltalk.json`, visualising GlobalTalk scraper trends.

### Plugins

The `marcusolsson-treemap-panel` plugin is installed for treemap visualisations.

## Persistence

Grafana data is bind-mounted from `/persist/grafana` to `/var/lib/grafana`.

## Service summary

| Service   | Package       | Purpose                                    |
|-----------|---------------|--------------------------------------------|
| grafana   | grafana       | Dashboarding UI                            |
| alloy     | grafana-alloy | Metrics shipping (self-scrape)             |
