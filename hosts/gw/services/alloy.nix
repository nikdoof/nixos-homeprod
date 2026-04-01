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
}
