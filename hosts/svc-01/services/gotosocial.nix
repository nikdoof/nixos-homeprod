{ config, lib, ... }:
{
  age.secrets = {
    goToSocialEnvironment = {
      file = ../../../secrets/goToSocialEnvironment.age;
    };
  };

  # GoToSocial + Simple Webfinger
  virtualisation.oci-containers.containers = {
    simple-webfinger = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.webfinger.rule" =
          "Host(`id.doofnet.uk`) && PathPrefix(`/.well-known/webfinger`)";
        "traefik.http.services.webfinger.loadbalancer.server.port" = "8000";
        "traefik.http.routers.webfinger.entrypoints" = "websecure,extwebsecure";
      };
      image = "ghcr.io/nikdoof/simple-webfinger";
      volumes = [
        "/srv/data/simple-webfinger/config:/app/config:U"
      ];
      environment = {
        SIMPLE_WEBFINGER_CONFIG_FILE = "/app/config/config.yaml";
      };
    };

    gotosocial = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.gotosocial.rule" = "Host(`social.doofnet.uk`)";
        "traefik.http.services.gotosocial.loadbalancer.server.port" = "8080";
        "traefik.http.routers.gotosocial.entrypoints" = "websecure,extwebsecure";
      };
      image = "superseriousbusiness/gotosocial:0.21.0";
      environment = {
        GTS_ADVANCED_RATE_LIMIT_REQUESTS = "0";
        GTS_ALLOW_IPS = "10.101.10.6/32";
        GTS_DB_TYPE = "postgres";
        GTS_HOST = "social.doofnet.uk";
        GTS_INSTANCE_LANGUAGES = "en-gb";
        GTS_INSTANCE_STATS_MODE = "serve";
        GTS_LETSENCRYPT_ENABLED = "false";
        GTS_METRICS_ENABLED = "true";
        GTS_OIDC_ADMIN_GROUPS = "admin";
        GTS_OIDC_ENABLED = "true";
        GTS_OIDC_IDP_NAME = "Doofnet";
        GTS_OIDC_ISSUER = "https://id.doofnet.uk";
        GTS_SMTP_FROM = "no-reply@doofnet.uk";
        GTS_SMTP_HOST = "mx-01.doofnet.uk";
        GTS_SMTP_PORT = "25";
        GTS_STORAGE_BACKEND = "s3";
        GTS_TRUSTED_PROXIES = "10.0.0.0/8,::1";
        GTS_WAZERO_COMPILATION_CACHE = "/gotosocial/.cache";
        OTEL_EXPORTER_PROMETHEUS_HOST = "0.0.0.0";
        OTEL_METRICS_EXPORTER = "prometheus";
        OTEL_METRICS_PRODUCERS = "prometheus";
        TZ = "Europe/London";
      };
      environmentFiles = [ config.age.secrets.goToSocialEnvironment.path ];
    };
  };

  services.postgresql = {
    ensureDatabases = [
      "gotosocial"
    ];
    ensureUsers = lib.mkAfter [
      {
        name = "gotosocial";
        ensureDBOwnership = true;
        ensureClauses = {
          createrole = true;
          createdb = true;
          login = true;
          #password = "SCRAM-SHA-256$4096:ccdHuoEyjh5gKX550FCOdQ==$jAm1/d9IRySXwdsb2uby5F71ZY9gFkOK/Sc77W9klBI=:6tN57xZCQIwPtZk9DwmRkjpPa8jVTBTFQj+T7V3HlLc=";
        };
      }
    ];
  };

}
