{ config, ... }:
{
  services.prometheus.exporters.postfix = {
    enable = true;
    port = 9154;
    listenAddress = "127.0.0.1";
    systemd.enable = true;
  };

  environment.etc."alloy/conf.d/02-postfix.alloy".text = ''
    prometheus.scrape "postfix" {
      targets    = [{"__address__" = "localhost:${toString config.services.prometheus.exporters.postfix.port}"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "postfix"
    }
  '';

  environment.etc."alloy/conf.d/02-dovecot.alloy".text = ''
    prometheus.scrape "dovecot" {
      targets    = [{"__address__" = "localhost:9166"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "dovecot"
    }
  '';
}
