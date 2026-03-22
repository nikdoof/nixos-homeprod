_: {
  # Gitea log tailing
  environment.etc."alloy/conf.d/02-gitea.alloy".text = ''
    local.file_match "gitea" {
      path_targets = [{"__path__" = "/srv/data/gitea/data/log/*.log", "job" = "gitea", "host" = "svc-01"}]
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

  # cAdvisor exporter for Podman containers
  environment.etc."alloy/conf.d/02-cadvisor.alloy".text = ''
    prometheus.exporter.cadvisor "default" {
      docker_only = true
    }
    prometheus.scrape "cadvisor" {
      targets    = prometheus.exporter.cadvisor.default.targets
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "cadvisor"
    }
  '';

  # Allow Alloy to read gitea logs and podman files
  systemd.services.alloy.serviceConfig.SupplementaryGroups = [
    "gitea"
    "podman"
  ];
  systemd.services.alloy.serviceConfig.ReadOnlyPaths = [
    "/srv/data/gitea/data/log"
    "/var/run/podman"
    "/sys/fs/cgroup"
  ];
}
