{ config, pkgs, ... }:
{
  age.secrets.gitSecrets.file = ../../../secrets/gitSecrets.age;

  services.gitea = {
    enable = true;
    stateDir = "/srv/data/gitea/data";

    database = {
      type = "postgres";
      createDatabase = true;
    };

    settings = {
      mailer = {
        ENABLED = true;
        PROTOCOL = "smtp+starttls";
        SMTP_ADDR = "mx-01.doofnet.uk";
        FROM = "Doofnet Gitea <gitea@doofnet.uk>";
        USER = "gitea@doofnet.uk";
      };
      server = {
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 9990;
        DOMAIN = "git.doofnet.uk";
        ROOT_URL = "https://git.doofnet.uk";
        DISABLE_SSH = true;
      };
      service = {
        DISABLE_REGISTRATION = true;
      };
    };
  };

  services.traefik = {
    dynamicConfigOptions = {
      http = {
        routers.gitea = {
          rule = "Host(`git.doofnet.uk`)";
          service = "gitea";
        };

        services.gitea.loadBalancer.servers = [
          { url = "http://127.0.0.1:${toString config.services.gitea.settings.server.HTTP_PORT}"; }
        ];
      };
    };
  };

  # Gitea Mirror
  systemd.timers."gitea-mirror" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "30m";
      Unit = "gitea-mirror.service";
    };
  };

  systemd.services."gitea-mirror" = {
    script = ''
      ${pkgs.podman}/bin/podman run --env-file ${config.age.secrets.gitSecrets.path} --rm jaedle/mirror-to-gitea:latest
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };
}
