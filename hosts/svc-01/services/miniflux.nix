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
      "traefik.http.routers.miniflux.entrypoints" = "websecure,extwebsecure";
      "traefik.http.routers.miniflux.priority" = "1000";
      "traefik.http.routers.miniflux.rule" = "Host(`rss.doofnet.uk`)";
      "traefik.http.services.miniflux.loadbalancer.server.port" = "8080";
    };
    image = "miniflux/miniflux:2.2.18";
    environment = {
      BASE_URL = "https://rss.doofnet.uk/";
      DISABLE_LOCAL_AUTH = "1";
      METRICS_ALLOWED_NETWORKS = "10.0.0.0/8,127.0.0.1/32";
      METRICS_COLLECTOR = "1";
      OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://id.doofnet.uk";
      OAUTH2_PROVIDER = "oidc";
      OAUTH2_REDIRECT_URL = "https://rss.doofnet.uk/oauth2/oidc/callback";
      OAUTH2_USER_CREATION = "1";
      RUN_MIGRATIONS = "1";
      TZ = "UTC";
    };
    environmentFiles = [ config.age.secrets.minifluxEnvironment.path ];
    ports = [ "127.0.0.1:8091:8080" ];
  };

  environment.etc."alloy/conf.d/02-miniflux.alloy".text = ''
    prometheus.scrape "miniflux" {
      targets    = [{"__address__" = "localhost:8091"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "miniflux"
      metrics_path = "/metrics"
    }
  '';

}
