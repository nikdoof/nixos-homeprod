{ config, ... }:
{
  age.secrets.scrumboyEnvironment = {
    file = ../../../secrets/scrumboyEnvironment.age;
  };

  virtualisation.oci-containers.containers.scrumboy = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.scrumboy.rule" = "Host(`scrum.doofnet.uk`)";
      "traefik.http.routers.scrumboy.entrypoints" = "websecure,extwebsecure";
      "traefik.http.services.scrumboy.loadbalancer.server.port" = "8080";
    };
    image = "ghcr.io/markrai/scrumboy:sha-8867779";
    volumes = [
      "/srv/data/scrumboy/data:/data:U"
    ];
    environment = {
      BIND_ADDR = ":8080";
      DATA_DIR = "/data";
      SQLITE_PATH = "/data/app.db";
      SQLITE_BUSY_TIMEOUT_MS = "5000";
      SQLITE_JOURNAL_MODE = "WAL";
      SQLITE_SYNCHRONOUS = "FULL";
      SCRUMBOY_OIDC_ISSUER = "https://id.doofnet.uk";
      SCRUMBOY_OIDC_REDIRECT_URL = "https://scrum.doofnet.uk/api/auth/oidc/callback";
      SCRUMBOY_OIDC_LOCAL_AUTH_DISABLED = "true";
      SCRUMBOY_VAPID_SUBSCRIBER = "mailto:andy@tensixtyone.com";
    };
    environmentFiles = [ config.age.secrets.scrumboyEnvironment.path ];
    ports = [ "127.0.0.1:8092:8080" ];
  };

  services.borgmatic.settings.source_directories = [ "/srv/data/scrumboy/data" ];
}
