{ config, ... }:
{
  age.secrets.metricsBasicAuthHtpasswd = {
    file = ../../../secrets/metricsBasicAuthHtpasswd.age;
    owner = "traefik";
  };

  services.traefik.dynamicConfigOptions = {
    http = {
      routers = {
        metrics-prometheus = {
          rule = "Host(`metrics.doofnet.uk`) && PathPrefix(`/prometheus`)";
          entryPoints = [ "websecure" ];
          middlewares = [
            "metrics-auth"
            "metrics-strip-prometheus"
          ];
          service = "metrics-prometheus";
        };
        metrics-loki = {
          rule = "Host(`metrics.doofnet.uk`) && PathPrefix(`/loki`)";
          entryPoints = [ "websecure" ];
          middlewares = [
            "metrics-auth"
            "metrics-strip-loki"
          ];
          service = "metrics-loki";
        };
      };

      middlewares = {
        metrics-auth.basicAuth = {
          usersFile = config.age.secrets.metricsBasicAuthHtpasswd.path;
        };
        metrics-strip-prometheus.stripPrefix.prefixes = [ "/prometheus" ];
        metrics-strip-loki.stripPrefix.prefixes = [ "/loki" ];
      };

      services = {
        metrics-prometheus.loadBalancer.servers = [
          { url = "https://prometheus.svc.doofnet.uk"; }
        ];
        metrics-loki.loadBalancer.servers = [
          { url = "https://loki.svc.doofnet.uk"; }
        ];
      };
    };
  };
}
