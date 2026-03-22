{
  config,
  ...
}:
let
  fqdn = with config.networking; "${hostName}.${domain}";
in
{
  age.secrets = {
    digitaloceanApiToken = {
      file = ../secrets/digitalOceanApiToken.age;
      owner = "traefik";
    };
  };

  systemd.services.traefik = {
    environment = {
      DO_AUTH_TOKEN_FILE = config.age.secrets.digitaloceanApiToken.path;
    };
  };

  services.traefik = {
    enable = true;

    staticConfigOptions = {
      api = true;

      entryPoints = {
        web = {
          address = ":80";
          asDefault = true;
          http.redirections.entrypoint = {
            to = "websecure";
            scheme = "https";
          };
        };

        websecure = {
          address = ":443";
          asDefault = true;
          http.tls.certResolver = "letsencrypt";
        };

        metrics = {
          address = ":9871";
        };
      };

      metrics = {
        prometheus = {
          entryPoint = "metrics";
        };
      };

      log = {
        level = "INFO";
        filePath = "${config.services.traefik.dataDir}/traefik.log";
        format = "json";
      };

      accessLog = {
        format = "common";
        filePath = "${config.services.traefik.dataDir}/access.log";
      };

      certificatesResolvers = {
        letsencrypt = {
          acme = {
            email = "postmaster@${config.networking.domain}";
            storage = "${config.services.traefik.dataDir}/acme.json";
            dnsChallenge = {
              resolvers = [
                "1.1.1.1"
                "8.8.8.8"
              ];
              provider = "digitalocean";
            };
          };
        };
      };
    };

    dynamicConfigOptions = {
      http = {
        routers = {
          api = {
            rule = "Host(`${fqdn}`)";
            service = "api@internal";
          };
        };

        serversTransports = {
          insecureTransport = {
            insecureSkipVerify = true;
          };
        };
      };
    };
  };

  environment.etc."alloy/conf.d/01-traefik.alloy".text = ''
    local.file_match "traefik" {
      path_targets = [
        {"__path__" = "${config.services.traefik.dataDir}/traefik.log", "job" = "traefik", "host" = "${config.networking.hostName}", "log_type" = "server"},
        {"__path__" = "${config.services.traefik.dataDir}/access.log", "job" = "traefik", "host" = "${config.networking.hostName}", "log_type" = "access"},
      ]
      sync_period = "5s"
    }

    loki.source.file "traefik" {
      targets    = local.file_match.traefik.targets
      forward_to = [loki.write.default.receiver]
    }

    prometheus.scrape "traefik" {
      targets    = [{"__address__" = "localhost:9871"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "traefik"
    }
  '';

  # traefik group grants Alloy read access to the data dir (logs, NOT acme.json secrets —
  # those are 0600 within the dir). Lists merge with any other module adding to these.
  systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "traefik" ];
  systemd.services.alloy.serviceConfig.ReadOnlyPaths = [ config.services.traefik.dataDir ];

  # Open ports in the firewall.
  networking.firewall = {
    allowedTCPPorts = [
      80
      443
    ];
  };
}
