{
  config,
  ...
}:

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
    group = "podman";

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

        extweb = {
          address = ":8080";
          asDefault = false;
          http.redirections.entrypoint = {
            to = "extwebsecure";
            scheme = "https";
          };
        };

        extwebsecure = {
          address = ":8443";
          asDefault = false;
          http.tls.certResolver = "letsencrypt";
        };
      };

      log = {
        level = "INFO";
        filePath = "${config.services.traefik.dataDir}/traefik.log";
        format = "json";
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
      providers = {
        docker = {
          exposedByDefault = false;
          endpoint = "unix:///run/podman/podman.sock";
        };
      };
    };

    dynamicConfigOptions = {

      http.routers = {
        api = {
          rule = "Host(`traefik.svc.doofnet.uk`)";
          service = "api@internal";
        };
      };

      http.middlewares = {
        auth-headers = {
          headers = {
            sslRedirect = true;
            stsSeconds = 315360000;
            browserXssFilter = true;
            contentTypeNosniff = true;
            forceSTSHeader = true;
            sslHost = "doofnet.uk";
            stsIncludeSubdomains = true;
            stsPreload = true;
            frameDeny = true;
          };
        };

        # Redirects if not authenticated
        oauth-auth-redirect = {
          forwardAuth = {
            address = "https://127.0.0.1:4180/oauth2/";
            trustForwardHeader = true;
            authResponseHeaders = [
              "X-Auth-Request-Access-Token"
              "Authorization"
            ];
          };
        };

        # Throws 401 without redirecting
        oauth-auth-wo-redirect = {
          forwardAuth = {
            address = "https://127.0.0.1:4180/oauth2/auth";
            trustForwardHeader = true;
            authResponseHeaders = [
              "X-Auth-Request-Access-Token"
              "Authorization"
            ];
          };
        };
      };
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    80
    443
    8080
    8443
  ];
}
