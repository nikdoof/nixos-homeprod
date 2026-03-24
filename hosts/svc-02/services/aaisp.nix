{ config, ... }:
{

  age.secrets.aaispLogin = {
    file = ../../../secrets/aaispLogin.age;
  };

  services.aaisp-exporter = {
    enable = true;
    listenAddress = "127.0.0.1:9118";
    environmentFile = config.age.secrets.aaispLogin.path;
  };

  # Alloy config
  environment.etc."alloy/conf.d/02-aaisp.alloy".text = ''
    prometheus.scrape "aaisp" {
      targets    = [{"__address__" = "127.0.0.1:9118"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "aaisp"
    }
  '';
}
