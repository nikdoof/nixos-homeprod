_: {
  # Kea DHCP exporter
  services.prometheus.exporters.kea = {
    enable = true;
    port = 9547;
    listenAddress = "127.0.0.1";
    controlSocketPaths = [
      "/run/kea/kea4-ctrl-socket"
      "/run/kea/kea6-ctrl-socket"
    ];
  };

  # Chrony exporter
  services.prometheus.exporters.chrony = {
    enable = true;
    port = 9123;
    listenAddress = "127.0.0.1";
  };

  # Unbound exporter — uses the local unix control socket configured in dns.nix.
  # ca/certificate/key are nulled because TLS auth is only needed for the TCP control interface.
  services.prometheus.exporters.unbound = {
    enable = true;
    port = 9167;
    listenAddress = "127.0.0.1";
    unbound = {
      host = "unix:///run/unbound/unbound.socket";
      ca = null;
      certificate = null;
      key = null;
    };
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

    // Unbound recursive resolver (hosted VLAN): cache hit/miss, query types, response codes
    prometheus.scrape "unbound" {
      targets    = [{"__address__" = "localhost:9167"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "unbound"
    }
  '';
}
