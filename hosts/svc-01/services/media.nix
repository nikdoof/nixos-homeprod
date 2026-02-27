{ ... }:
{
  virtualisation.oci-containers.containers = {

    # Prowlarr, Radarr, Sonarr
    prowlarr = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.prowlarr.rule" = "Host(`prowlarr.svc.doofnet.uk`)";
        "traefik.http.services.prowlarr.loadbalancer.server.port" = "9696";
        "traefik.http.routers.prowlarr.middlewares" = "oauth-auth-redirect@file";
      };
      image = "ghcr.io/home-operations/prowlarr:2.3.2.5245";
      volumes = [ "/srv/data/prowlarr/config:/config:U" ];
    };

    radarr = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.radarr.rule" = "Host(`radarr.svc.doofnet.uk`)";
        "traefik.http.services.radarr.loadbalancer.server.port" = "7878";
        "traefik.http.routers.radarr.middlewares" = "oauth-auth-redirect@file";
      };
      image = "ghcr.io/home-operations/radarr:6.1.1.10317";
      volumes = [
        "/srv/data/radarr/config:/config:U"
        "/mnt/nas-03/media/:/data"
      ];
    };

    sonarr = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.sonarr.rule" = "Host(`sonarr.svc.doofnet.uk`)";
        "traefik.http.services.sonarr.loadbalancer.server.port" = "8989";
        "traefik.http.routers.sonarr.middlewares" = "oauth-auth-redirect@file";
      };
      image = "ghcr.io/home-operations/sonarr:4.0.16.2946";
      volumes = [
        "/srv/data/sonarr/config:/config:U"
        "/mnt/nas-03/media/:/data"
      ];
    };

    # Openbooks and Calibre-Web
    openbooks = {
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
        "--debug"
      ];
    };

    calibre-web = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.calibre-web.rule" = "Host(`calibre-web.svc.doofnet.uk`)";
        "traefik.http.services.calibre-web.loadbalancer.server.port" = "8083";
      };
      image = "ghcr.io/cdloh/calibre-web:0.6.26";
      volumes = [
        "/srv/data/calibre-web/config:/config:U"
        "/srv/data/calibre-web/cache:/app/cps/cache:U"
        "/mnt/nas-03/media/:/data"
      ];
    };
  };
}
