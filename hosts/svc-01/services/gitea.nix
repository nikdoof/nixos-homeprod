{
  config,
  pkgs,
  lib,
  ...
}:
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
      metrics = {
        ENABLED = true;
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

  # Gitea Mirror — three separate runs to avoid cross-contamination between
  # starred repos, personal repos, and org repos.
  systemd.timers."gitea-mirror" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "30m";
    };
  };

  systemd.services."gitea-mirror" =
    let
      image = "jaedle/mirror-to-gitea:latest";
      common = lib.concatStringsSep " " [
        "--env-file ${config.age.secrets.gitSecrets.path}"
        "-e GITHUB_USERNAME=nikdoof"
        "-e GITEA_URL=https://git.doofnet.uk"
        "-e SINGLE_RUN=true"
      ];
      podman = "${pkgs.podman}/bin/podman run";
    in
    {
      script = ''
        # Mirror starred repos → nikdoof-stars org
        ${podman} ${common} \
          -e MIRROR_STARRED=true \
          -e GITEA_STARRED_ORGANIZATION=nikdoof-stars \
          -e MIRROR_PRIVATE_REPOSITORIES=false \
          -e MIRROR_ORGANIZATIONS=false \
          -e SKIP_STARRED_ISSUES=true \
          --rm ${image}

        # Mirror personal repos (including private) → nikdoof user
        ${podman} ${common} \
          -e MIRROR_STARRED=false \
          -e MIRROR_PRIVATE_REPOSITORIES=true \
          -e MIRROR_ORGANIZATIONS=false \
          --rm ${image}

        # Mirror org repos → matching org names
        ${podman} ${common} \
          -e MIRROR_STARRED=false \
          -e MIRROR_PRIVATE_REPOSITORIES=false \
          -e MIRROR_ORGANIZATIONS=true \
          -e PRESERVE_ORG_STRUCTURE=true \
          -e GITEA_ORG_VISIBILITY=private \
          --rm ${image}
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };

  services.borgmatic.settings.source_directories = [ "/srv/data/gitea/data" ];
}
