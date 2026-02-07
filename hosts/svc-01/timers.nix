# systemd timers for maintenance tasks
{
  config,
  lib,
  pkgs,
  ...
}:

{
  age.secrets = {
    swarmMirrorConfig.file = ../../secrets/swarmMirrorConfig.age;
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
}
