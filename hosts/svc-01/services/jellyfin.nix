{ ... }:
{
  virtualisation.oci-containers.containers.jellyfin = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.jellyfin.rule" = "Host(`jellyfin.svc.doofnet.uk`)";
      "traefik.http.services.jellyfin.loadbalancer.server.port" = "8096";
    };
    image = "jellyfin/jellyfin:10.11.6";
    volumes = [
      "/mnt/nas-03/media/:/mnt/media"
      "/srv/data/jellyfin/config:/config:U"
      "/srv/data/jellyfin/cache:/cache:U"
    ];
    devices = [
      "/dev/dri/renderD128:/dev/dri/renderD128"
      "/dev/dri/card0:/dev/dri/card1"
    ];
    extraOptions = [ "--network=host" ];
  };
}
