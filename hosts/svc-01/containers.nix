{ lib, config, ... }:

let
  # Follows the same structure as virtualisation.oci-containers.containers
  containers = {

    # Pocket ID
    pocket-id = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.pocket-id.rule" = "Host(`id.doofnet.uk`)";
        "traefik.http.services.pocket-id.loadbalancer.server.port" = "8081";
        "traefik.http.routers.pocket-id.entrypoints" = "websecure,extwebsecure";
      };
      image = "ghcr.io/pocket-id/pocket-id:v2.3.0";
      volumes = [
        "/srv/data/pocket-id/data:/app/data:U"
        "${config.age.secrets.pocketIdEncryptionKey.path}:/secrets/pocketIdEncryptionKey"
        "${config.age.secrets.maxmindLicenseKey.path}:/secrets/maxmindLicenseKey"
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

    simple-webfinger = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.webfinger.rule" =
          "Host(`id.doofnet.uk`) && PathPrefix(`/.well-known/webfinger`)";
        "traefik.http.services.webfinger.loadbalancer.server.port" = "8000";
        "traefik.http.routers.webfinger.entrypoints" = "websecure,extwebsecure";
      };
      image = "ghcr.io/nikdoof/simple-webfinger";
      volumes = [
        "/srv/data/simple-webfinger/config:/app/config:U"
      ];
      environment = {
        SIMPLE_WEBFINGER_CONFIG_FILE = "/app/config/config.yaml";
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

    # Rustical
    rustical = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.rustical.rule" = "Host(`cal.doofnet.uk`)";
        "traefik.http.services.rustical.loadbalancer.server.port" = "4000";
        "traefik.http.routers.rustical.entrypoints" = "websecure,extwebsecure";
      };
      image = "ghcr.io/lennart-k/rustical:0.12.9";
      environmentFiles = [ config.age.secrets.rusticalClientSecret.path ];
      volumes = [
        "/srv/data/rustical/config/config.toml:/etc/rustical/config.toml:U"
        "/srv/data/rustical/data:/var/lib/rustical:U"
      ];
    };

    # GoToSocial
    gotosocial = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.gotosocial.rule" = "Host(`social.doofnet.uk`)";
        "traefik.http.services.gotosocial.loadbalancer.server.port" = "8080";
        "traefik.http.routers.gotosocial.entrypoints" = "websecure,extwebsecure";
      };
      image = "superseriousbusiness/gotosocial:0.21.0";
      environment = {
        GTS_ADVANCED_RATE_LIMIT_REQUESTS = "0";
        GTS_ALLOW_IPS = "10.101.10.6/32";
        GTS_DB_TYPE = "postgres";
        GTS_HOST = "social.doofnet.uk";
        GTS_INSTANCE_LANGUAGES = "en-gb";
        GTS_INSTANCE_STATS_MODE = "serve";
        GTS_LETSENCRYPT_ENABLED = "false";
        GTS_METRICS_ENABLED = "true";
        GTS_OIDC_ADMIN_GROUPS = "admin";
        GTS_OIDC_ENABLED = "true";
        GTS_OIDC_IDP_NAME = "Doofnet";
        GTS_OIDC_ISSUER = "https://id.doofnet.uk";
        GTS_SMTP_FROM = "no-reply@doofnet.uk";
        GTS_SMTP_HOST = "mx-01.doofnet.uk";
        GTS_SMTP_PORT = "25";
        GTS_STORAGE_BACKEND = "s3";
        GTS_TRUSTED_PROXIES = "10.0.0.0/8,::1";
        GTS_WAZERO_COMPILATION_CACHE = "/gotosocial/.cache";
        OTEL_EXPORTER_PROMETHEUS_HOST = "0.0.0.0";
        OTEL_METRICS_EXPORTER = "prometheus";
        OTEL_METRICS_PRODUCERS = "prometheus";
        TZ = "Europe/London";
      };
      environmentFiles = [ config.age.secrets.goToSocialEnvironment.path ];
    };

    miniflux = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.miniflux.rule" = "Host(`rss.doofnet.uk`)";
        "traefik.http.services.miniflux.loadbalancer.server.port" = "8080";
        "traefik.http.routers.miniflux.entrypoints" = "websecure,extwebsecure";
      };
      image = "miniflux/miniflux:2.2.17";
      environment = {
        TZ = "UTC";
        BASE_URL = "https://rss.doofnet.uk/";
        RUN_MIGRATIONS = "1";
        METRICS_COLLECTOR = "1";
        METRICS_ALLOWED_NETWORKS = "10.0.0.0/8";
        OAUTH2_PROVIDER = "oidc";
        OAUTH2_REDIRECT_URL = "https://rss.doofnet.uk/oauth2/oidc/callback";
        OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://id.doofnet.uk";
        OAUTH2_USER_CREATION = "1";
        DISABLE_LOCAL_AUTH = "1";
      };
      environmentFiles = [ config.age.secrets.minifluxEnvironment.path ];
    };

    linkding = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.linkding.rule" = "Host(`link.doofnet.uk`)";
        "traefik.http.services.linkding.loadbalancer.server.port" = "9090";
        "traefik.http.routers.linkding.entrypoints" = "websecure,extwebsecure";
      };
      image = "sissbruecker/linkding:1.45.0";
      environment = {
        LD_DB_ENGINE = "postgres";
        LD_DB_HOST = "10.88.0.1";
        LD_DB_PORT = "5432";
        LD_DB_USER = "linkding";
        LD_DB_DATABASE = "linkding";
        LD_ENABLE_OIDC = "True";
        OIDC_OP_AUTHORIZATION_ENDPOINT = "https://id.doofnet.uk/authorize";
        OIDC_OP_TOKEN_ENDPOINT = "https://id.doofnet.uk/api/oidc/token";
        OIDC_OP_USER_ENDPOINT = "https://id.doofnet.uk/api/oidc/userinfo";
        OIDC_OP_JWKS_ENDPOINT = "https://id.doofnet.uk/.well-known/jwks.json";
        OIDC_USERNAME_CLAIM = "username";
      };
      environmentFiles = [ config.age.secrets.linkdingEnvironment.path ];
    };

    copyparty = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.copyparty.rule" = "Host(`files.doofnet.uk`)";
        "traefik.http.services.copyparty.loadbalancer.server.port" = "3923";
        "traefik.http.routers.copyparty.entrypoints" = "websecure,extwebsecure";
      };
      image = "ghcr.io/9001/copyparty-ac:1.20.10";
      volumes = [
        "/srv/data/copyparty/data:/w"
        "/srv/data/copyparty/config/doofnet.conf:/cfg/doofnet.conf:U"
      ];
    };

    paperless = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.paperless.rule" = "Host(`paperless.svc.doofnet.uk`)";
        "traefik.http.services.paperless.loadbalancer.server.port" = "8000";
      };
      image = "ghcr.io/paperless-ngx/paperless-ngx:2.20.8";
      volumes = [
        "/mnt/nas-03/paperless/:/data"
        "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt"
      ];
      environment = {
        COMPOSE_PROJECT_NAME = "paperless";
        PAPERLESS_DBHOST = "10.88.0.1";
        PAPERLESS_DBNAME = "paperless";
        PAPERLESS_DBUSER = "paperless";
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_REDIS = "redis://valkey:6379";
        PAPERLESS_CONSUMPTION_DIR = "/data/inbox/";
        PAPERLESS_DATA_DIR = "/data/data/";
        PAPERLESS_MEDIA_ROOT = "/data/media/";
        PAPERLESS_CONSUMER_POLLING = "60";
        PAPERLESS_CONSUMER_RECURSIVE = "true";
        PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = "true";
        PAPERLESS_TIKA_ENABLED = "1";
        PAPERLESS_TIKA_GOTENBERG_ENDPOINT = "http://gotenberg:3000";
        PAPERLESS_TIKA_ENDPOINT = "http://tika:9998";
        PAPERLESS_PORT = "8000";
        PAPERLESS_URL = "https://paperless.svc.doofnet.uk";
        PAPERLESS_DEBUG = "true";
        PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
        PAPERLESS_DISABLE_REGULAR_LOGIN = "true";
        PAPERLESS_EMAIL_CERTIFICATE_LOCATION = "/etc/ssl/certs/ca-certificates.crt";
      };
      environmentFiles = [
        config.age.secrets.paperlessClientSecret.path
      ];
    };

    tika = {
      image = "apache/tika";
    };

    gotenberg = {
      image = "thecodingmachine/gotenberg:8.27.0";
      environment = {
        DISABLE_GOOGLE_CHROME = "1";
      };
    };

    valkey = {
      image = "valkey/valkey:9.0.3";
    };

    scanservjs = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.scanservjs.rule" = "Host(`scan.svc.doofnet.uk`)";
        "traefik.http.services.scanservjs.loadbalancer.server.port" = "8080";
      };
      image = "sbs20/scanservjs:latest";
      volumes = [
        "/var/run/dbus:/var/run/dbus"
        "/mnt/nas-03/paperless/inbox:/var/lib/scanservjs/output"
        "/etc/scanservjs/config.local.js:/etc/scanservjs/config.local.js"
      ];
      extraOptions = [ "--privileged" ];
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
      owner = "1000";
    };
    maxmindLicenseKey = {
      file = ../../secrets/maxmindLicenseKey.age;
      owner = "1000";
    };
    rusticalClientSecret = {
      file = ../../secrets/rusticalClientSecret.age;
    };
    goToSocialEnvironment = {
      file = ../../secrets/goToSocialEnvironment.age;
    };
    minifluxEnvironment = {
      file = ../../secrets/minifluxEnvironment.age;
    };
    linkdingEnvironment = {
      file = ../../secrets/linkdingEnvironment.age;
    };
    paperlessClientSecret = {
      file = ../../secrets/paperlessClientSecret.age;
    };
  };

  environment.etc = {
    "scanservjs/config.local.js".source = ./scanservjs/config.local.js;
  };

  virtualisation.oci-containers.containers = containers;

  # Automatically create /srv/data directories from container definitions
  system.activationScripts.createContainerDirs = lib.stringAfter [ "var" ] ''
    ${lib.concatMapStringsSep "\n" (dir: ''
      if ! [ -f ${dir} ]; then mkdir -p "${dir}"; fi
      chmod u+rwX,g+rX,o+rX "${dir}"
    '') srvDataDirs}
  '';
}
