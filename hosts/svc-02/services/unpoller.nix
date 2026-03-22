{ config, ... }:
{
  environment.etc."alloy/conf.d/02-unpoller.alloy".text = ''
    prometheus.scrape "unifi" {
      targets    = [{"__address__" = "127.0.0.1:9130"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "unifi"
    }
  '';

  age.secrets = {
    unpollerPassword = {
      file = ../../../secrets/unpollerPassword.age;
      owner = "unifi-poller";
    };
  };

  services.unpoller = {
    enable = true;
    prometheus.http_listen = "127.0.0.1:9130";
    influxdb.disable = true;
    unifi.controllers = [
      {
        url = "https://127.0.0.1:8443";
        user = "unpoller";
        pass = config.age.secrets.unpollerPassword.path;
        verify_ssl = false;
      }
    ];
  };
}
