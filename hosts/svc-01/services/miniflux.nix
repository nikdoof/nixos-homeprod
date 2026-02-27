{ config, ... }:
{
  age.secrets = {
    minifluxEnvironment = {
      file = ../../../secrets/minifluxEnvironment.age;
    };
  };

  virtualisation.oci-containers.containers.miniflux = {
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

}
