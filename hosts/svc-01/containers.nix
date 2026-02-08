{ lib, ... }:

let
  # Extract all /srv/data paths from container volumes
  containers = {

    jellyfin = {
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

    prowlarr = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.prowlarr.rule" = "Host(`prowlarr.svc.doofnet.uk`)";
        "traefik.http.services.prowlarr.loadbalancer.server.port" = "9696";
      };
      image = "ghcr.io/home-operations/prowlarr:2.3.2.5245";
      volumes = [ "/srv/data/prowlarr/config:/config:U" ];
    };

    radarr = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.radarr.rule" = "Host(`radarr.svc.doofnet.uk`)";
        "traefik.http.services.radarr.loadbalancer.server.port" = "7878";
      };
      image = "ghcr.io/home-operations/radarr:6.1.1.10317";
      volumes = [ "/srv/data/radarr/config:/config:U" ];
    };

    sonarr = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.sonarr.rule" = "Host(`sonarr.svc.doofnet.uk`)";
        "traefik.http.services.sonarr.loadbalancer.server.port" = "8989";
      };
      image = "ghcr.io/home-operations/sonarr:4.0.16.2946";
      volumes = [ "/srv/data/sonarr/config:/config:U" ];
    };

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
        "/srv/data/calibre-web/config:/config"
        "/srv/data/calibre-web/cache:/app/cps/cache"
        "/mnt/nas-03/media/:/data"
      ];
    };
  };

  # Extract local /srv/data paths from all volumes
  srvDataDirs = lib.unique (
    lib.flatten (
      lib.mapAttrsToList (
        _name: container:
        lib.filter (path: path != null) (
          map (
            volume:
            let
              localPath = lib.head (lib.splitString ":" volume);
            in
            if lib.hasPrefix "/srv/data/" localPath then localPath else null
          ) (container.volumes or [ ])
        )
      ) containers
    )
  );

in
{
  virtualisation.oci-containers.containers = containers;

  # Automatically create /srv/data directories from container definitions
  system.activationScripts.createContainerDirs = lib.stringAfter [ "var" ] ''
    ${lib.concatMapStringsSep "\n" (dir: ''
      mkdir -p "${dir}"
      chmod 755 "${dir}"
    '') srvDataDirs}
  '';
}
