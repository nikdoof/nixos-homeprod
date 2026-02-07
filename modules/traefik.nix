{
  config,
  lib,
  pkgs,
  ...
}:

{
  age.secrets = {
    digitaloceanApiToken.file = ../secrets/digitalOceanApiToken.age;
  };

  services.traefik = {
    enable = true;

    staticConfigOptions = {
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
              provider = "digitalocean";
              env = {
                DO_AUTH_TOKEN_FILE = config.age.secrets.digitaloceanApiToken.path;
              };
            };
          };
        };
      };
    };

    dynamicConfigOptions = {
      http.routers = { };
      http.services = { };
    };
  };
}
