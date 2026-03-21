{
  config,
  ...
}:
{
  services.prometheus = {
    enable = true;
    listenAddress = "0.0.0.0";

    # Accept metrics pushed via remote_write from Alloy agents
    extraFlags = [ "--web.enable-remote-write-receiver" ];

    enableReload = true;
    retentionTime = "365d";

    alertmanagers = [
      {
        scheme = "https";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.alertmanager.port}"
            ];
          }
        ];
      }
    ];

    scrapeConfigs = [
      {
        # Pull-based scrape for hosts not managed by this flake
        job_name = "node_exporter";
        static_configs = [
          {
            targets = [ "gw.int.doofnet.uk:9100" ];
          }
        ];
      }
      {
        job_name = "jrouter";
        static_configs = [
          {
            targets = [
              "127.0.0.1:9459"
            ];
          }
        ];
      }
      {
        job_name = "bind";
        static_configs = [
          {
            targets = [
              "ns-01.int.doofnet.uk:9119"
              "ns-02.int.doofnet.uk:9119"
            ];
          }
        ];
      }
      {
        job_name = "postgres";
        static_configs = [
          {
            targets = [
              "svc-01.int.doofnet.uk:9187"
              "svc-02.int.doofnet.uk:9187"
            ];
          }
        ];
      }
      {
        job_name = "unifi";
        static_configs = [
          {
            targets = [
              "127.0.0.1:9130"
            ];
          }
        ];
      }
      {
        job_name = "graphite";
        static_configs = [
          {
            targets = [
              "127.0.0.1:9108"
            ];
          }
        ];
      }
      {
        job_name = "homeassistant";
        metrics_path = "/api/prometheus";
        scheme = "https";
        static_configs = [
          {
            targets = [ "homeassistant.int.doofnet.uk:443" ];
          }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.port}" ];
          }
        ];
      }
      {
        job_name = "grafana";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.grafana.settings.server.http_port}" ];
          }
        ];
      }
      {
        job_name = "loki";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}" ];
          }
        ];
      }
      {
        job_name = "hcloud";
        static_configs = [
          {
            targets = [ "127.0.0.1:9501" ];
          }
        ];
      }
      {
        job_name = "traefik";
        static_configs = [
          {
            targets = [
              "svc-01.int.doofnet.uk:9871"
              "svc-02.int.doofnet.uk:9871"
            ];
          }
        ];
      }
      {
        job_name = "headscale";
        static_configs = [
          {
            targets = [
              "hs.doofnet.uk:9090"
            ];
          }
        ];
      }
    ];
  };

  services.traefik = {
    dynamicConfigOptions = {
      http = {
        routers.prometheus = {
          rule = "Host(`prometheus.svc.doofnet.uk`)";
          service = "prometheus";
        };

        services.prometheus.loadBalancer.servers = [
          {
            url = "http://localhost:${toString config.services.prometheus.port}";
          }
        ];
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ config.services.prometheus.port ];

  # Bind Prometheus data directory to the NVMe.
  fileSystems."/var/lib/prometheus2" = {
    device = "/srv/data/prometheus/data";
    options = [ "bind" ];
  };
}
