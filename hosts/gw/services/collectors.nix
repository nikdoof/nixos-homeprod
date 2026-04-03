{ pkgs, ... }:
let
  textfileDir = "/var/lib/prometheus/node-exporter";

  # Exports named nftables counter values (packets + bytes) to the Prometheus
  # textfile directory.  Requires root to call `nft list counters`.
  nftablesCollector = pkgs.writeShellScript "prom-collect-nftables" ''
    set -euo pipefail
    out=${textfileDir}/nftables.prom
    tmp=$out.tmp

    {
      printf '# HELP nftables_counter_packets_total Total packets matched by a named nftables counter\n'
      printf '# TYPE nftables_counter_packets_total counter\n'
      printf '# HELP nftables_counter_bytes_total Total bytes matched by a named nftables counter\n'
      printf '# TYPE nftables_counter_bytes_total counter\n'
      ${pkgs.nftables}/bin/nft -j list counters | \
        ${pkgs.jq}/bin/jq -r '
          .nftables[] |
          select(.counter) |
          .counter |
          "nftables_counter_packets_total{table=\"\(.table)\",name=\"\(.name)\"} \(.packets)",
          "nftables_counter_bytes_total{table=\"\(.table)\",name=\"\(.name)\"} \(.bytes)"
        '
    } > "$tmp" && mv "$tmp" "$out"
  '';
in
{
  # nftables counter exporter — runs every 60 s, writes nftables.prom
  systemd.services.prom-collect-nftables = {
    description = "Prometheus textfile collector: nftables counters";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = nftablesCollector;
    };
  };
  systemd.timers.prom-collect-nftables = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "60s";
    };
  };
}
