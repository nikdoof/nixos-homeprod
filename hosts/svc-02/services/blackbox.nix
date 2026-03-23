{ pkgs, ... }:
{
  services.prometheus.exporters.blackbox = {
    enable = true;
    port = 9115;
    listenAddress = "127.0.0.1";
    configFile = pkgs.writeText "blackbox.yml" (
      builtins.toJSON {
        modules = {
          https_2xx = {
            prober = "http";
            timeout = "10s";
            http = {
              valid_status_codes = [ ];
              fail_if_not_ssl = true;
              preferred_ip_protocol = "ip4";
            };
          };
        };
      }
    );
  };

  # Alloy config
  environment.etc."alloy/conf.d/02-blackbox.alloy".text = ''
    prometheus.scrape "blackbox_https" {
      targets = [
        {"__address__" = "localhost:9115", "__param_target" = "https://social.doofnet.uk",          "instance" = "social.doofnet.uk"},
        {"__address__" = "localhost:9115", "__param_target" = "https://id.doofnet.uk",              "instance" = "id.doofnet.uk"},
        {"__address__" = "localhost:9115", "__param_target" = "https://rss.doofnet.uk",             "instance" = "rss.doofnet.uk"},
        {"__address__" = "localhost:9115", "__param_target" = "https://link.doofnet.uk",            "instance" = "link.doofnet.uk"},
        {"__address__" = "localhost:9115", "__param_target" = "https://doofnet.uk",                 "instance" = "doofnet.uk"},
        {"__address__" = "localhost:9115", "__param_target" = "https://nikdoof.com",                "instance" = "nikdoof.com"},
      ]
      forward_to   = [prometheus.remote_write.default.receiver]
      job_name     = "blackbox"
      metrics_path = "/probe"
      params       = {"module" = ["https_2xx"]}
    }
  '';
}
