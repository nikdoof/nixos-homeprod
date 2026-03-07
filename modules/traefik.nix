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
        level = "DEBUG";
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

  # Open ports in the firewall.
  networking.firewall = {
    allowedTCPPorts = [
      80
      443
    ];
    extraCommands = ''
      # Allow Traefik metrics port from Prometheus system
      iptables -A nixos-fw -p tcp -m tcp --dport 9871 -s 10.101.0.0/16 -j nixos-fw-accept -m comment --comment "traefik"
      ip6tables -A nixos-fw -p tcp -m tcp --dport 9871 -s fddd:d00f:dab0:101::/64 -j nixos-fw-accept -m comment --comment "traefik"
      ip6tables -A nixos-fw -p tcp -m tcp --dport 9871 -s 2001:8b0:bd9:101::21/64 -j nixos-fw-accept -m comment --comment "traefik"
    '';
  };
}
