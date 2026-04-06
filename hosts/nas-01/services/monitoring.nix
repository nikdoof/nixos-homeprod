{ config, ... }:
{
  # ZFS pool metrics via a dedicated unix exporter component.
  # Uses set_collectors so only the zfs collector runs (avoids duplicating
  # the default collectors already scraped by 00-base.alloy).
  environment.etc."alloy/conf.d/02-zfs.alloy".text = ''
    prometheus.exporter.unix "zfs" {
      set_collectors = ["zfs"]
    }

    prometheus.scrape "unix_zfs" {
      targets    = prometheus.exporter.unix.zfs.targets
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "node_exporter"
    }
  '';

  # Samba session and share metrics.
  services.prometheus.exporters.samba = {
    enable = true;
    listenAddress = "127.0.0.1";
  };

  environment.etc."alloy/conf.d/02-samba.alloy".text = ''
    prometheus.scrape "samba" {
      targets    = [{"__address__" = "localhost:${toString config.services.prometheus.exporters.samba.port}"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "samba"
    }
  '';
}
