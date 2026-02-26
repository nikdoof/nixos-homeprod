{ ... }:
{
  imports = [
    ./alertmanager.nix
    ./grafana.nix
    ./graphite_exporter.nix
    ./hcloud_exporter.nix
    ./loki.nix
    ./prometheus.nix
    ./tftp.nix
    ./unifi.nix
    ./unpoller.nix
  ];
}
