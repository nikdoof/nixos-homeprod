{ config, lib, ... }:
{
  age.secrets = {
    paperlessClientSecret = {
      file = ../../../secrets/paperlessClientSecret.age;
    };
  };

  services.postgresql = {
    ensureDatabases = [
      "paperless"
    ];
    ensureUsers = lib.mkAfter [
      {
        name = "paperless";
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

  virtualisation.oci-containers.containers = {
    paperless = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.paperless.rule" = "Host(`paperless.svc.doofnet.uk`)";
        "traefik.http.services.paperless.loadbalancer.server.port" = "8000";
      };
      image = "ghcr.io/paperless-ngx/paperless-ngx:2.20.8";
      volumes = [
        "/mnt/nas-03/paperless/:/data"
        "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt"
      ];
      environment = {
        COMPOSE_PROJECT_NAME = "paperless";
        PAPERLESS_DBHOST = "10.88.0.1";
        PAPERLESS_DBNAME = "paperless";
        PAPERLESS_DBUSER = "paperless";
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_REDIS = "redis://valkey:6379";
        PAPERLESS_CONSUMPTION_DIR = "/data/inbox/";
        PAPERLESS_DATA_DIR = "/data/data/";
        PAPERLESS_MEDIA_ROOT = "/data/media/";
        PAPERLESS_CONSUMER_POLLING = "60";
        PAPERLESS_CONSUMER_RECURSIVE = "true";
        PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = "true";
        PAPERLESS_TIKA_ENABLED = "1";
        PAPERLESS_TIKA_GOTENBERG_ENDPOINT = "http://gotenberg:3000";
        PAPERLESS_TIKA_ENDPOINT = "http://tika:9998";
        PAPERLESS_PORT = "8000";
        PAPERLESS_URL = "https://paperless.svc.doofnet.uk";
        PAPERLESS_DEBUG = "true";
        PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
        PAPERLESS_DISABLE_REGULAR_LOGIN = "true";
        PAPERLESS_EMAIL_CERTIFICATE_LOCATION = "/etc/ssl/certs/ca-certificates.crt";
      };
      environmentFiles = [
        config.age.secrets.paperlessClientSecret.path
      ];
    };

    tika = {
      image = "apache/tika";
    };

    gotenberg = {
      image = "thecodingmachine/gotenberg:8.27.0";
      environment = {
        DISABLE_GOOGLE_CHROME = "1";
      };
    };

    valkey = {
      image = "valkey/valkey:9.0.3";
    };
  };
}
