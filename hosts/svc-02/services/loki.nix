{ config, ... }:
{
  services.loki = {
    enable = true;

    configuration = {
      server.http_listen_port = 3030;
      auth_enabled = false;

      common = {
        ring = {
          instance_addr = "127.0.0.1";
          kvstore = {
            store = "inmemory";
          };
        };
        replication_factor = 1;
        path_prefix = "/srv/data/loki";
      };

      schema_config = {
        configs = [
          {
            from = "2020-05-15";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };

      storage_config = {
        filesystem = {
          directory = "/srv/data/loki/chunks";
        };
      };

      pattern_ingester = {
        enabled = true;
      };
      limits_config = {
        allow_structured_metadata = true;
        volume_enabled = true;
      };
    };
  };

  services.traefik = {
    dynamicConfigOptions = {
      http = {
        routers.loki = {
          rule = "Host(`loki.svc.doofnet.uk`)";
          service = "loki";
          observability.accessLogs = false;
        };

        services.loki.loadBalancer.servers = [
          { url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}"; }
        ];
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    config.services.loki.configuration.server.http_listen_port
  ];

  # Alloy config
  environment.etc."alloy/conf.d/02-loki.alloy".text = ''
    prometheus.scrape "loki" {
      targets    = [{"__address__" = "127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "loki"
    }
  '';
}
