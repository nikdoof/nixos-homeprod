_: {
  # Kea DHCP exporter — connects directly to the Unix control sockets
  # configured in dhcp4.nix and dhcp6.nix; no ctrl-agent daemon required.
  # Exposes per-subnet lease counts, pool utilization, and packet statistics.
  services.prometheus.exporters.kea = {
    enable = true;
    port = 9547;
    listenAddress = "127.0.0.1";
    controlSocketPaths = [
      "/run/kea/kea4-ctrl-socket"
      "/run/kea/kea6-ctrl-socket"
    ];
  };

  # Chrony exporter — clock offset, jitter, stratum, and upstream peer status.
  services.prometheus.exporters.chrony = {
    enable = true;
    port = 9123;
    listenAddress = "127.0.0.1";
  };

  environment.etc."alloy/conf.d/02-gw.alloy".text = ''
    // Kea DHCPv4 + DHCPv6: lease counts, pool utilization, packet/ack/nak stats
    prometheus.scrape "kea" {
      targets    = [{"__address__" = "localhost:9547"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "kea"
    }

    // Chrony NTP: clock offset, RMS jitter, stratum, upstream reference status
    prometheus.scrape "chrony" {
      targets    = [{"__address__" = "localhost:9123"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "chrony"
    }
  '';

  # The base server.nix prometheus.exporter.unix (node_exporter) already captures:
  #   netdev   — per-interface RX/TX bytes, packets, errors, drops
  #              (covers vlan-private, vlan-public, vlan-lab, vlan-ha,
  #               vlan-hosted, ppp0, enp2s0, enp3s0f0, enp3s0f1, vlan-wan)
  #   conntrack — nf_conntrack_entries and nf_conntrack_entries_limit
  # Both are default-enabled collectors; no additional configuration needed.
}
