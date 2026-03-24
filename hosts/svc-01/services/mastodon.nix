{ config, lib, ... }:
let

  mastodon_config = {
    ALLOWED_PRIVATE_ADDRESSES = "10.0.0.0/8";
    DB_HOST = "10.88.0.1";
    DEFAULT_LOCALE = "en";
    ES_ENABLED = "false";
    IP_RETENTION_PERIOD = "31556952";
    LOCAL_DOMAIN = "incognitus.net";
    REDIS_URL = "redis://valkey:6379";
    S3_ENABLED = "false";
    SESSION_RETENTION_PERIOD = "31556952";
    SMTP_FROM_ADDRESS = "Incognitus Mastodon <notifications@mastodon.incognitus.net>";
    SMTP_PORT = "25";
    SMTP_SERVER = "mx-01.doofnet.uk";
    TZ = "UTC";
    WEB_DOMAIN = "mastodon.incognitus.net";
  };

  mastodon_volumes = [
    "/srv/data/mastodon/system:/opt/mastodon/public/system"
  ];

in
{
  age.secrets = {
    mastodonEnvironment = {
      file = ../../../secrets/mastodonEnvironment.age;
    };
  };

  # Mastodon
  virtualisation.oci-containers.containers = {
    mastodon = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.mastodon.rule" = "Host(`mastodon.incognitus.net`)";
        "traefik.http.services.mastodon.loadbalancer.server.port" = "3000";
        "traefik.http.routers.mastodon.entrypoints" = "websecure,extwebsecure";
      };
      image = "ghcr.io/mastodon/mastodon:v4.5.7";
      cmd = [
        "bash"
        "-c"
        "rm -f /mastodon/tmp/pids/server.pid; bundle exec rails db:migrate; bundle exec rails s -p 3000"
      ];
      environment = mastodon_config;
      environmentFiles = [
        config.age.secrets.mastodonEnvironment.path
      ];
      volumes = mastodon_volumes;
    };

    mastodon-streaming = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.mastodon-streaming.rule" =
          "Host(`mastodon.incognitus.net`) && Path(`/api/v1/streaming/`)";
        "traefik.http.services.mastodon-streaming.loadbalancer.server.port" = "4000";
        "traefik.http.routers.mastodon-streaming.entrypoints" = "websecure,extwebsecure";
      };
      image = "ghcr.io/mastodon/mastodon-streaming:v4.5.8";
      cmd = [
        "node"
        "./streaming"
      ];
      environment = mastodon_config;
      environmentFiles = [
        config.age.secrets.mastodonEnvironment.path
      ];
    };

    mastodon-sidekiq = {
      image = "ghcr.io/mastodon/mastodon:v4.5.7";
      cmd = [
        "bundle"
        "exec"
        "sidekiq"
      ];
      environment = mastodon_config;
      environmentFiles = [
        config.age.secrets.mastodonEnvironment.path
      ];
      volumes = mastodon_volumes;
    };
  };

  services.postgresql = {
    ensureDatabases = [
      "mastodon"
    ];
    ensureUsers = lib.mkAfter [
      {
        name = "mastodon";
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
