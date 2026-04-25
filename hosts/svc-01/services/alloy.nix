{ config, ... }:
{
  # Gitea log tailing
  environment.etc."alloy/conf.d/02-gitea.alloy".text = ''
    local.file_match "gitea" {
      path_targets = [{"__path__" = "/srv/data/gitea/data/log/*.log", "job" = "gitea", "host" = "${config.networking.hostName}"}]
      sync_period  = "5s"
    }
    loki.source.file "gitea" {
      targets    = local.file_match.gitea.targets
      forward_to = [loki.write.default.receiver]
    }
  '';

  # Redis/Valkey exporter
  environment.etc."alloy/conf.d/02-redis.alloy".text = ''
    prometheus.exporter.redis "default" {
      redis_addr = "localhost:6379"
    }
    prometheus.scrape "redis" {
      targets    = prometheus.exporter.redis.default.targets
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "redis"
    }
  '';

  # cAdvisor - runs as a privileged container so it can access container storage
  # internals that require root. Alloy scrapes its HTTP endpoint on localhost:8080.
  virtualisation.oci-containers.containers.cadvisor = {
    image = "gcr.io/cadvisor/cadvisor:latest";
    extraOptions = [
      "--privileged"
      "--device=/dev/kmsg"
    ];
    volumes = [
      "/:/rootfs:ro"
      "/var/run:/var/run:ro"
      "/sys:/sys:ro"
      "/var/lib/containers:/var/lib/containers:ro"
    ];
    ports = [ "127.0.0.1:9110:8080" ];
  };

  environment.etc."alloy/conf.d/02-cadvisor.alloy".text = ''
    prometheus.scrape "cadvisor" {
      targets    = [{"__address__" = "localhost:9110"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "cadvisor"
    }
  '';

  # Gitea built-in metrics endpoint (enabled via [metrics] in gitea config)
  environment.etc."alloy/conf.d/02-gitea-metrics.alloy".text = ''
    prometheus.scrape "gitea" {
      targets    = [{"__address__" = "127.0.0.1:${toString config.services.gitea.settings.server.HTTP_PORT}"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "gitea"
      metrics_path = "/metrics"
    }
  '';

  # Allow Alloy to read gitea logs
  systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "gitea" ];
  systemd.services.alloy.serviceConfig.ReadOnlyPaths = [ "/srv/data/gitea/data/log" ];
}
