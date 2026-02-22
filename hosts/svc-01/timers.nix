# systemd timers for maintenance tasks
{
  config,
  pkgs,
  ...
}:

{
  age.secrets = {
    swarmMirrorConfig.file = ../../secrets/swarmMirrorConfig.age;
    gitSecrets.file = ../../secrets/gitSecrets.age;
  };

  systemd.timers."swarm-mirror" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "swarm-mirror.service";
    };
  };

  systemd.services."swarm-mirror" = {
    script = ''
      ${pkgs.podman}/bin/podman run --rm -v ${config.age.secrets.swarmMirrorConfig.path}:/app/config/config.ini:U ghcr.io/nikdoof/foursquare-feeds:latest -k caldav
    '';
    serviceConfig = {
      Type = "oneshot";
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
      ${pkgs.podman}/bin/podman run --env-host --rm jaedle/mirror-to-gitea:latest
    '';
    serviceConfig = {
      Type = "oneshot";
    };
    environment = {
      GITHUB_USERNAME = "nikdoof";
      GITEA_URL = "https://git.doofnet.uk";
      MIRROR_PRIVATE_REPOSITORIES = "true";
      SINGLE_RUN = "true";
      MIRROR_STARRED = "true";
      SKIP_STARRED_ISSUES = "true";
      GITEA_STARRED_ORGANIZATION = "nikdoof-stars";
      MIRROR_ORGANIZATIONS = "true";
      PRESERVE_ORG_STRUCTURE = "true";
      GITEA_ORG_VISIBILITY = "private";
    };
    serviceConfig.environmentFile = [
      config.age.secrets.gitSecrets.path
    ];
  };

}
