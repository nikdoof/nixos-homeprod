{ lib, config, ... }:

let
  # Follows the same structure as virtualisation.oci-containers.containers
  containers = {

    # Pocket ID
    pocket-id = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.pocket-id.rule" = "Host(`id.doofnet.uk`)";
        "traefik.http.services.pocket-id.loadbalancer.server.port" = "3000";
      };
      image = "ghcr.io/pocket-id/pocket-id:v2.2.0";
      volumes = [
        "/srv/data/pocket-id/config:/config:U"
        "${config.age.secrets.pocketIdEncryptionKey.path}:/secrets/pocketIdEncryptionKey:U"
        "${config.age.secrets.maxmindLicenseKey.path}:/secrets/maxmindLicenseKey:U"
      ];
      environment = {
        APP_URL = "https://id.doofnet.uk";
        ENCRYPTION_KEY_FILE = "/secrets/pocketIdEncryptionKey";
        MAXMIND_LICENSE_KEY_FILE = "/secrets/maxmindLicenseKey";
        METRICS_ENABLED = "true";
        OTEL_EXPORTER_PROMETHEUS_HOST = "0.0.0.0";
        OTEL_METRICS_EXPORTER = "prometheus";
        PORT = "8081";
        TRUST_PROXY = "true";
      };
    };

    # OAuth2-Proxy
    oauth2-proxy = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.oauth2-proxy.rule" =
          "Host(`oauth2-proxy.svc.doofnet.uk`) || PathPrefix(`/oauth2/`)";
        "traefik.http.routers.oauth2-proxy.middlewares" = "auth-headers@file";
        "traefik.http.services.oauth2-proxy.loadbalancer.server.port" = "4180";
      };
      image = "quay.io/oauth2-proxy/oauth2-proxy:v7.14.2";
      environmentFiles = [ config.age.secrets.oauth2ClientSecret.path ];
      cmd = [
        "--provider=oidc"
        "--oidc-issuer-url=https://id.doofnet.uk"
        "--provider-display-name=Doofnet Auth"
        "--code-challenge-method=S256"
        "--email-domain=*"
        "--upstream=static://202"
        "--http-address=0.0.0.0:4180"
        "--pass-user-headers=true"
        "--pass-authorization-header=true"
        "--set-authorization-header=true"
        "--pass-access-token=true"
        "--set-xauthrequest=true"
        "--reverse-proxy=true"
        "--skip-provider-button"
        "--allowed-group=home"
        "--real-client-ip-header=X-Forwarded-For"
        "--cookie-csrf-per-request=true"
        "--cookie-csrf-expire=5m"
        "--cookie-domain=doofnet.uk"
      ];
      ports = [ "127.0.0.1:4180:4180" ];
    };

    # Jellyfin
    jellyfin = {
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

  # Extract local /srv/data paths from all volumes defined in any containers
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
  age.secrets = {
    oauth2ClientSecret = {
      file = ../../secrets/oauth2ClientSecret.age;
    };
    pocketIdEncryptionKey = {
      file = ../../secrets/pocketIdEncryptionKey.age;
    };
    maxmindLicenseKey = {
      file = ../../secrets/maxmindLicenseKey.age;
    };
  };

  virtualisation.oci-containers.containers = containers;

  # Automatically create /srv/data directories from container definitions
  system.activationScripts.createContainerDirs = lib.stringAfter [ "var" ] ''
    ${lib.concatMapStringsSep "\n" (dir: ''
      mkdir -p "${dir}"
      chmod 755 "${dir}"
    '') srvDataDirs}
  '';
}
