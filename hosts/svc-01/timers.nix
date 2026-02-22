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
      ${pkgs.podman}/bin/podman run --env-file ${config.age.secrets.gitSecrets.path} --rm jaedle/mirror-to-gitea:latest
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

}
