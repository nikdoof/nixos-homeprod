{
  ...
}:

{
  virtualisation.oci-containers.containers = {

    # Jellyfin
    "jellyfin" = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.jellyfin.rule" = "Host(`jellyfin.svc.doofnet.uk`)";
        "traefik.http.services.jellyfin.loadbalancer.server.port" = "8096";
      };
      image = "jellyfin/jellyfin:10.11.6";
      volumes = [
        "/mnt/nas-03/media/:/mnt/media"
        "/srv/data/jellyfin/config:/config"
        "/srv/data/jellyfin/cache:/cache"
      ];
      devices = [
        "/dev/dri/renderD128:/dev/dri/renderD128"
        "/dev/dri/card1:/dev/dri/card1"
      ];
      extraOptions = [ "--network=host" ];
    };

    # Openbooks
    "openbooks" = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.openbooks.rule" = "Host(`openbooks.svc.doofnet.uk`)";
        "traefik.http.services.openbooks.loadbalancer.server.port" = "8080";
      };
      image = "ghcr.io/evan-buss/openbooks:edge";
      volumes = [
        "/mnt/nas-03/media/Books/openbooks:/books"
      ];
      cmd = [
        "server"
        "--port"
        "8080"
        "--name"
        "x32init"
        "--searchbot"
        "search"
        "--persist"
      ];
    };

    #calibre-web
    "calibre-web" = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.calibre-web.rule" = "Host(`calibre-web.svc.doofnet.uk`)";
        "traefik.http.services.calibre-web.loadbalancer.server.port" = "8083";
      };
      image = "ghcr.io/cdloh/calibre-web:0.6.26";
      volumes = [
        "/srv/data/calibre-web/config:/config"
        "/srv/data/calibre-web/cache:/app/cps/cache"
        "/mnt/nas-03/media/:/data"
      ];
    };
  };
}
