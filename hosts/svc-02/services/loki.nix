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
        };

        services.loki.loadBalancer.servers = [
          { url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}"; }
        ];
      };
    };
  };
}
